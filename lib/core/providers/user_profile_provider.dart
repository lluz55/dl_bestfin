import 'dart:io';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kUserNameKey = 'user_name';
const kUserPhotoPathKey = 'user_photo_path';

// Set before runApp() via main.dart — seed síncrono do provider.
String? initialUserName;
String? initialUserPhotoPath;

/// Perfil local do usuário (nome e foto). Totalmente opcional: preenchido no
/// onboarding ou nas configurações e exibido na saudação do Dashboard.
@immutable
class UserProfile {
  const UserProfile({this.name, this.photoPath});

  final String? name;

  /// Caminho absoluto da foto dentro do diretório de documentos do app.
  final String? photoPath;

  bool get hasName => name != null && name!.trim().isNotEmpty;
  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;

  /// Primeiro nome, para saudações curtas ("Bom dia, Lucas").
  String? get firstName =>
      hasName ? name!.trim().split(RegExp(r'\s+')).first : null;

  /// Iniciais (até 2 letras) para o avatar quando não há foto.
  String? get initials {
    if (!hasName) return null;
    final parts = name!.trim().split(RegExp(r'\s+'));
    final first = parts.first.characters.first;
    if (parts.length == 1) return first.toUpperCase();
    return (first + parts.last.characters.first).toUpperCase();
  }
}

class UserProfileNotifier extends Notifier<UserProfile> {
  @override
  UserProfile build() =>
      UserProfile(name: initialUserName, photoPath: initialUserPhotoPath);

  Future<void> setName(String? name) async {
    final trimmed = name?.trim();
    final value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    state = UserProfile(name: value, photoPath: state.photoPath);

    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(kUserNameKey);
    } else {
      await prefs.setString(kUserNameKey, value);
    }
  }

  /// Copia a imagem escolhida para o diretório do app (a origem — galeria ou
  /// file picker — pode ser um cache temporário do SO) e remove a foto
  /// anterior. O nome do arquivo leva timestamp para invalidar o cache de
  /// imagens do Flutter, que é indexado pelo caminho.
  Future<void> setPhoto(String sourcePath) async {
    final docs = await getApplicationDocumentsDirectory();
    final ext = p.extension(sourcePath).isEmpty
        ? '.jpg'
        : p.extension(sourcePath);
    final destPath = p.join(
      docs.path,
      'profile_photo_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await File(sourcePath).copy(destPath);

    final previous = state.photoPath;
    state = UserProfile(name: state.name, photoPath: destPath);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kUserPhotoPathKey, destPath);
    await _deleteFileQuietly(previous);
  }

  Future<void> removePhoto() async {
    final previous = state.photoPath;
    state = UserProfile(name: state.name);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kUserPhotoPathKey);
    await _deleteFileQuietly(previous);
  }

  static Future<void> _deleteFileQuietly(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[UserProfile] Falha ao remover foto antiga: $e');
    }
  }
}

final userProfileProvider = NotifierProvider<UserProfileNotifier, UserProfile>(
  UserProfileNotifier.new,
);
