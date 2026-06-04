import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  static const _defaultBaseUrl = String.fromEnvironment(
    'BESTFIN_BACKEND_URL',
    defaultValue: 'http://10.0.2.2:8080',
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

  bool get isInitialized => _initialized;
  bool get isSignedIn => _accessToken != null && _refreshToken != null;
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
  }

  Future<SyncUser?> signInWithEmail(String email, String password) async {
    final body = await _request(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
      authenticated: false,
    );
    return _storeAuth(body, fallbackEmail: email);
  }

  Future<SyncUser?> signUpWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    final body = await _request(
      'POST',
      '/auth/register',
      body: {
        'email': email,
        'password': password,
        if (displayName != null && displayName.isNotEmpty) 'name': displayName,
      },
      authenticated: false,
    );
    return _storeAuth(body, fallbackEmail: email);
  }

  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _userEmailKey);
    await _storage.delete(key: _kdfSaltKey);
    _authController.add(null);
  }

  Future<void> pushRecords(List<BackendSyncRecord> records) async {
    await _request(
      'POST',
      '/sync/push',
      body: {'records': records.map((r) => r.toJson()).toList()},
    );
  }

  Future<List<BackendSyncRecord>> pullRecords({required int since}) async {
    final body = await _request('GET', '/sync/pull?since=$since');
    final rawRecords = body['records'] as List? ?? const [];
    return rawRecords
        .whereType<Map>()
        .map(
          (record) =>
              BackendSyncRecord.fromJson(Map<String, dynamic>.from(record)),
        )
        .toList();
  }

  Future<SyncUser?> _storeAuth(
    Map<String, dynamic> body, {
    required String fallbackEmail,
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
    await _storage.write(key: _accessTokenKey, value: token);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _userIdKey, value: userId);
    await _storage.write(key: _userEmailKey, value: email);
    final kdfSalt = body['kdf_salt'] as String?;
    if (kdfSalt != null) await _storage.write(key: _kdfSaltKey, value: kdfSalt);
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
}
