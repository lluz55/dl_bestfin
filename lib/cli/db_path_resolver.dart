import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolve o caminho do `bestfin.sqlite` no desktop (CLI/TUI) sem depender do
/// `path_provider` — ele quebra quando o `xdg-user-dir` não está no PATH
/// (NixOS minimal, `nix run .#bestfin` sem devShell). Replica o fallback de
/// `getAppDocumentsDirectory()` em `lib/core/utils/app_paths.dart`, com o
/// mesmo acréscimo de criar `~/.local/share/bestfin/documents` se nenhum
/// diretório convencional existir.
///
/// Flag `--db <path>` sempre tem prioridade quando fornecida.
String resolveBestfinDbPath({String? override}) {
  if (override != null && override.trim().isNotEmpty) {
    return override.trim();
  }
  return p.join(_resolveLinuxDocumentsDir().path, 'bestfin.sqlite');
}

Directory _resolveLinuxDocumentsDir() {
  final home = Platform.environment['HOME'] ?? '/tmp';

  for (final candidate in _xdgUserDirCandidates()) {
    if (candidate.isNotEmpty) return Directory(candidate);
  }

  // Verifica ambos os locales — se os dois existirem, prefere o que tem
  // o arquivo de banco maior (um banco real tem KB; arquivo espúrio tem bytes).
  Directory? best;
  int bestSize = 0;
  for (final name in ['Documentos', 'Documents']) {
    final dir = Directory(p.join(home, name));
    if (!dir.existsSync()) continue;
    final db = File(p.join(dir.path, 'bestfin.sqlite'));
    if (!db.existsSync()) continue;
    final len = db.lengthSync();
    if (len > bestSize) {
      bestSize = len;
      best = dir;
    }
  }
  if (best != null) return best;

  final fallback = Directory(
    p.join(home, '.local', 'share', 'bestfin', 'documents'),
  );
  fallback.createSync(recursive: true);
  return fallback;
}

List<String> _xdgUserDirCandidates() {
  try {
    final result = Process.runSync('xdg-user-dir', ['DOCUMENTS']);
    if (result.exitCode == 0) {
      final out = (result.stdout as String).trim();
      if (out.isNotEmpty) return [out];
    }
  } on ProcessException {
    // xdg-user-dir ausente — segue para o fallback.
  }
  return const <String>[];
}
