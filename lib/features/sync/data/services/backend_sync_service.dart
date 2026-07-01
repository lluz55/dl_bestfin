import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bestfin/features/sync/data/services/e2e_crypto_service.dart';
import 'package:bestfin/features/sync/domain/models/sync_user.dart';

class BackendConfig {
  final String baseUrl;

  const BackendConfig({required this.baseUrl});

  bool get isConfigured => baseUrl.isNotEmpty;
}

class BackendSyncRecord {
  final String entityType;
  final String entityId;
  final String payload;
  final int updatedAt;
  final bool isDeleted;

  const BackendSyncRecord({
    required this.entityType,
    required this.entityId,
    required this.payload,
    required this.updatedAt,
    required this.isDeleted,
  });

  Map<String, dynamic> toJson() => {
    'entity_type': entityType,
    'entity_id': entityId,
    'payload': payload,
    'updated_at': updatedAt,
    'is_deleted': isDeleted,
  };

  factory BackendSyncRecord.fromJson(Map<String, dynamic> json) {
    return BackendSyncRecord(
      entityType: json['entity_type'] as String? ?? '',
      entityId: json['entity_id'] as String? ?? '',
      payload: json['payload'] as String? ?? '{}',
      updatedAt: json['updated_at'] as int? ?? 0,
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }
}

class BackendSyncService {
  static const _storage = FlutterSecureStorage();
  static const _baseUrlKey = 'backend_base_url';
  static const _accessTokenKey = 'backend_access_token';
  static const _refreshTokenKey = 'backend_refresh_token';
  static const _userIdKey = 'backend_user_id';
  static const _userEmailKey = 'backend_user_email';
  static const _kdfSaltKey = 'backend_kdf_salt';
  static const _encryptedMasterKeyKey = 'backend_encrypted_master_key';
  static const _defaultBaseUrl = String.fromEnvironment(
    'BESTFIN_BACKEND_URL',
    defaultValue: 'http://10.0.2.2:28083',
  );

  final _authController = StreamController<SyncUser?>.broadcast();
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    ..idleTimeout = const Duration(seconds: 30);

  String _baseUrl = '';
  String? _accessToken;
  String? _refreshToken;
  SyncUser? _currentUser;
  bool _initialized = false;

  // Master key lives in memory only — never written to disk.
  Uint8List? _masterKey;

  bool get isInitialized => _initialized;
  bool get isSignedIn => _accessToken != null && _refreshToken != null;
  bool get hasEncryptionKey => _masterKey != null;
  SyncUser? get currentUser => _currentUser;
  String get baseUrl => _baseUrl;

  Stream<SyncUser?> get authStateChanges async* {
    yield _currentUser;
    yield* _authController.stream;
  }

  Future<BackendConfig> loadConfig() async {
    final stored = await _storage.read(key: _baseUrlKey);
    final config = BackendConfig(baseUrl: stored ?? _defaultBaseUrl);
    await initialize(baseUrl: config.baseUrl);
    return config;
  }

  Future<void> saveConfig(String baseUrl) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    await _storage.write(key: _baseUrlKey, value: normalized);
    await initialize(baseUrl: normalized);
  }

  Future<void> initialize({required String baseUrl}) async {
    _baseUrl = _normalizeBaseUrl(baseUrl);
    _accessToken = await _storage.read(key: _accessTokenKey);
    _refreshToken = await _storage.read(key: _refreshTokenKey);
    final userId = await _storage.read(key: _userIdKey);
    final email = await _storage.read(key: _userEmailKey);
    _currentUser = userId != null && email != null
        ? SyncUser(id: userId, email: email)
        : null;
    _initialized = _baseUrl.isNotEmpty;
    _authController.add(_currentUser);
    // masterKey is NOT restored from storage — user must re-authenticate.
  }

  /// Register a new account. Returns user + one-time 24-word mnemonic.
  Future<void> signUpWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    final kdfSalt = _generateHexSalt();
    final masterKey = E2ECryptoService.generateMasterKey();
    final kek = await E2ECryptoService.deriveKEK(password, kdfSalt);
    final encryptedMasterKey = await E2ECryptoService.encryptMasterKey(
      kek,
      masterKey,
    );
    final recoveryVerifier = await E2ECryptoService.computeRecoveryVerifier(
      masterKey,
    );

    await _request(
      'POST',
      '/auth/register',
      body: {
        'email': email,
        'password': password,
        if (displayName != null && displayName.isNotEmpty) 'name': displayName,
        'kdf_salt': kdfSalt,
        'encrypted_master_key': encryptedMasterKey,
        'recovery_verifier': recoveryVerifier,
      },
      authenticated: false,
    );
  }

  Future<SyncUser?> signInWithEmail(String email, String password) async {
    final body = await _request(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
      authenticated: false,
    );

    // Derive KEK from password + server-provided kdf_salt, then decrypt master key
    final kdfSalt = body['kdf_salt'] as String?;
    final encryptedMasterKey = body['encrypted_master_key'] as String?;
    Uint8List? masterKey;
    if (kdfSalt != null &&
        kdfSalt.isNotEmpty &&
        encryptedMasterKey != null &&
        encryptedMasterKey.isNotEmpty) {
      final kek = await E2ECryptoService.deriveKEK(password, kdfSalt);
      masterKey = await E2ECryptoService.decryptMasterKey(
        kek,
        encryptedMasterKey,
      );
    }

    return _storeAuth(body, fallbackEmail: email, masterKey: masterKey);
  }

  /// Recover account using mnemonic: sets a new password and re-wraps the master key.
  Future<void> recoverAccount({
    required String email,
    required String mnemonic,
    required String newPassword,
  }) async {
    final masterKey = E2ECryptoService.mnemonicToMasterKey(mnemonic);
    final recoveryVerifier = await E2ECryptoService.computeRecoveryVerifier(
      masterKey,
    );

    // We need the kdf_salt from the server to derive the new KEK.
    // Fetch it via a login attempt that will fail (we don't know the old password).
    // Instead, ask the server for the salt via a dedicated endpoint — or just use
    // the email as the salt derivation seed. Since kdf_salt is stored on register,
    // we request it via the recover endpoint which returns the updated token.
    //
    // The server validates recovery_verifier before touching the account.
    // We send a temporary salt together with the re-encrypted master key.
    final newKdfSalt = _generateHexSalt();
    final newKek = await E2ECryptoService.deriveKEK(newPassword, newKdfSalt);
    final newEncryptedMasterKey = await E2ECryptoService.encryptMasterKey(
      newKek,
      masterKey,
    );

    await _request(
      'POST',
      '/auth/recover',
      body: {
        'email': email,
        'recovery_verifier': recoveryVerifier,
        'new_password': newPassword,
        'encrypted_master_key': newEncryptedMasterKey,
        'kdf_salt': newKdfSalt,
      },
      authenticated: false,
    );
  }

  /// Re-wrap the master key after a password change.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final masterKey = _masterKey;
    if (masterKey == null) throw Exception('Não autenticado');

    final kdfSalt = await _storage.read(key: _kdfSaltKey);
    if (kdfSalt == null) throw Exception('KDF salt ausente');

    final newKek = await E2ECryptoService.deriveKEK(newPassword, kdfSalt);
    final newEncryptedMasterKey = await E2ECryptoService.encryptMasterKey(
      newKek,
      masterKey,
    );

    await _request(
      'PUT',
      '/auth/master-key',
      body: {'encrypted_master_key': newEncryptedMasterKey},
    );

    await _storage.write(
      key: _encryptedMasterKeyKey,
      value: newEncryptedMasterKey,
    );
  }

  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;
    _masterKey = null;
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _userEmailKey);
    await _storage.delete(key: _kdfSaltKey);
    await _storage.delete(key: _encryptedMasterKeyKey);
    _authController.add(null);
  }

  Future<void> pushRecords(List<BackendSyncRecord> records) async {
    final encrypted = await _encryptRecords(records);
    await _request(
      'POST',
      '/sync/push',
      body: {'records': encrypted.map((r) => r.toJson()).toList()},
    );
  }

  Future<List<BackendSyncRecord>> pullRecords({required int since}) async {
    final body = await _request('GET', '/sync/pull?since=$since');
    final rawRecords = body['records'] as List? ?? const [];
    final records = rawRecords
        .whereType<Map>()
        .map(
          (record) =>
              BackendSyncRecord.fromJson(Map<String, dynamic>.from(record)),
        )
        .toList();
    return _decryptRecords(records);
  }

  // ── Encryption helpers ────────────────────────────────────────────────────

  Future<List<BackendSyncRecord>> _encryptRecords(
    List<BackendSyncRecord> records,
  ) async {
    final masterKey = _masterKey;
    if (masterKey == null) {
      throw Exception('Chave de sincronização indisponível');
    }
    final result = <BackendSyncRecord>[];
    for (final r in records) {
      final encPayload = await E2ECryptoService.encryptPayload(
        masterKey,
        r.payload,
      );
      result.add(
        BackendSyncRecord(
          entityType: r.entityType,
          entityId: r.entityId,
          payload: encPayload,
          updatedAt: r.updatedAt,
          isDeleted: r.isDeleted,
        ),
      );
    }
    return result;
  }

  Future<List<BackendSyncRecord>> _decryptRecords(
    List<BackendSyncRecord> records,
  ) async {
    final masterKey = _masterKey;
    if (masterKey == null) {
      throw Exception('Chave de sincronização indisponível');
    }
    final result = <BackendSyncRecord>[];
    for (final r in records) {
      try {
        final plainPayload = await E2ECryptoService.decryptPayload(
          masterKey,
          r.payload,
        );
        result.add(
          BackendSyncRecord(
            entityType: r.entityType,
            entityId: r.entityId,
            payload: plainPayload,
            updatedAt: r.updatedAt,
            isDeleted: r.isDeleted,
          ),
        );
      } catch (_) {
        // Skip records that cannot be decrypted (e.g. corrupted / wrong key)
      }
    }
    return result;
  }

  // ── Private auth helpers ──────────────────────────────────────────────────

  Future<SyncUser?> _storeAuth(
    Map<String, dynamic> body, {
    required String fallbackEmail,
    Uint8List? masterKey,
  }) async {
    final token = body['token'] as String?;
    final refreshToken = body['refresh_token'] as String?;
    final userId = body['user_id'] as String?;
    final email = body['email'] as String? ?? fallbackEmail;
    if (token == null || refreshToken == null || userId == null) {
      throw Exception('Resposta de autenticação inválida');
    }

    _accessToken = token;
    _refreshToken = refreshToken;
    _currentUser = SyncUser(id: userId, email: email);
    _masterKey = masterKey;

    await _storage.write(key: _accessTokenKey, value: token);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _userIdKey, value: userId);
    await _storage.write(key: _userEmailKey, value: email);

    final kdfSalt = body['kdf_salt'] as String?;
    if (kdfSalt != null) await _storage.write(key: _kdfSaltKey, value: kdfSalt);
    final encMK = body['encrypted_master_key'] as String?;
    if (encMK != null && encMK.isNotEmpty) {
      await _storage.write(key: _encryptedMasterKeyKey, value: encMK);
    }

    _authController.add(_currentUser);
    return _currentUser;
  }

  Future<void> _refreshAccessToken() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) throw const HttpException('Sessão expirada');
    final body = await _request(
      'POST',
      '/auth/refresh',
      body: {'refresh_token': refreshToken},
      authenticated: false,
    );
    final token = body['token'] as String?;
    final nextRefresh = body['refresh_token'] as String?;
    if (token == null || nextRefresh == null) {
      throw Exception('Resposta de refresh inválida');
    }
    _accessToken = token;
    _refreshToken = nextRefresh;
    await _storage.write(key: _accessTokenKey, value: token);
    await _storage.write(key: _refreshTokenKey, value: nextRefresh);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    bool retried = false,
  }) async {
    if (_baseUrl.isEmpty) throw Exception('Backend não configurado');
    final uri = Uri.parse('$_baseUrl$path');
    final request = await _client.openUrl(method, uri);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (authenticated) {
      final token = _accessToken;
      if (token == null) throw const HttpException('Usuário não autenticado');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (body != null) request.write(jsonEncode(body));

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    if (response.statusCode == HttpStatus.unauthorized &&
        authenticated &&
        !retried) {
      await _refreshAccessToken();
      return _request(
        method,
        path,
        body: body,
        authenticated: authenticated,
        retried: true,
      );
    }
    if (response.statusCode == HttpStatus.forbidden) {
      final decoded = jsonDecode(responseBody);
      final error = decoded is Map ? decoded['error'] as String? ?? '' : '';
      if (error == 'account_pending_approval') {
        throw Exception('account_pending_approval');
      }
      if (error == 'account_rejected') {
        throw Exception('account_rejected');
      }
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    if (response.statusCode == HttpStatus.accepted) {
      if (responseBody.isEmpty) return {};
      final decoded = jsonDecode(responseBody);
      return decoded is Map<String, dynamic> ? decoded : {};
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        responseBody.isEmpty ? 'HTTP ${response.statusCode}' : responseBody,
        uri: uri,
      );
    }
    if (responseBody.isEmpty) return {};
    final decoded = jsonDecode(responseBody);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  String _normalizeBaseUrl(String value) {
    return value.trim().replaceFirst(RegExp(r'/+$'), '');
  }

  /// Generate a 16-byte random hex salt (client-side, for recovery re-wrap).
  static String _generateHexSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
