import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Diretório de "documentos" do app, multiplataforma.
///
/// No Android/iOS/Web/macOS/Windows o `path_provider` resolve corretamente.
/// No Linux ele delega ao utilitário `xdg-user-dir`, que:
///   * não vem instalado em algumas distros (NixOS minimal, containers Alpine);
///   * não está no PATH do binário bundleado pelo Flutter quando rodamos
///     `nix run .#bestfin` direto (sem passar pelo devShell).
///
/// Em ambos os casos o `path_provider_linux` lança
/// `MissingPlatformDirectoryException`, que estoura na abertura do SQLite
/// (`app_database.dart:640`). Este helper faz fallback automático para
/// `~/Documents` (ou `~/Documentos` em pt-BR), ou cria o diretório sob
/// `~/.local/share/bestfin/documents` se nenhum dos candidatos existir.
Future<Directory> getAppDocumentsDirectory() async {
  if (!Platform.isLinux) {
    return getApplicationDocumentsDirectory();
  }
  return _resolveLinuxDocumentsDir();
}

Directory _resolveLinuxDocumentsDir() {
  final home = Platform.environment['HOME'] ?? '/tmp';

  for (final candidate in _xdgUserDirCandidates()) {
    if (candidate.isNotEmpty) return Directory(candidate);
  }

  for (final name in ['Documents', 'Documentos']) {
    final dir = Directory(p.join(home, name));
    if (dir.existsSync()) return dir;
  }

  final fallback = Directory(p.join(home, '.local', 'share', 'bestfin', 'documents'));
  fallback.createSync(recursive: true);
  return fallback;
}

/// Tenta `xdg-user-dir DOCUMENTS` — o mesmo que o `path_provider_linux`
/// chama por baixo dos panos. Quando o binário não existe, retorna lista
/// vazia (o caller cai no fallback).
List<String> _xdgUserDirCandidates() {
  try {
    final result = Process.runSync('xdg-user-dir', ['DOCUMENTS']);
    if (result.exitCode == 0) {
      final out = (result.stdout as String).trim();
      if (out.isNotEmpty) {
        return [out];
      }
    }
  } on ProcessException {
    // xdg-user-dir não existe no PATH — silencioso, segue para o fallback.
  }
  return const <String>[];
}
