import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bestfin/features/llm/domain/models/ai_model_type.dart';

class DownloadProgress {
  final int received;
  final int total;

  const DownloadProgress(this.received, this.total);

  double get fraction => total > 0 ? received / total : 0.0;
  bool get isComplete => total > 0 && received >= total;
}

class ModelDownloadService {
  static const _channel = MethodChannel('com.bestfin.bestfin/download_manager');

  static Future<Directory> _llmDir() async {
    if (Platform.isAndroid) {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final dir = Directory(p.join(extDir.path, 'llm'));
        if (!dir.existsSync()) dir.createSync(recursive: true);
        return dir;
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'llm'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<String> modelPath(AiModelType modelType) async {
    if (Platform.isAndroid) {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final path = p.join(extDir.path, 'llm', modelType.fileName);
        if (File(path).existsSync()) return path;
      }
    }
    final dir = await _llmDir();
    return p.join(dir.path, modelType.fileName);
  }

  static Future<bool> isModelPresent(AiModelType modelType) async {
    if (Platform.isAndroid) {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final path = p.join(extDir.path, 'llm', modelType.fileName);
        if (_isFileComplete(File(path), modelType)) return true;
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    final internalPath = p.join(docs.path, 'llm', modelType.fileName);
    return _isFileComplete(File(internalPath), modelType);
  }

  // Returns true only when the file exists and is at least 95 % of the
  // expected size — catches downloads that were interrupted mid-way.
  static bool _isFileComplete(File file, AiModelType modelType) {
    if (!file.existsSync()) return false;
    final minBytes = (modelType.sizeBytes * 0.95).round();
    return file.lengthSync() >= minBytes;
  }

  static Future<int?> getActiveDownloadId(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key);
  }

  static Future<void> saveActiveDownloadId(String key, int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, id);
  }

  static Future<void> clearActiveDownloadId(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static Stream<DownloadProgress> _downloadNativeAndroid({
    required String url,
    required String fileName,
    required String prefKey,
  }) async* {
    int? downloadId = await getActiveDownloadId(prefKey);

    if (downloadId == null) {
      try {
        final result = await _channel.invokeMethod<int>('startDownload', {
          'url': url,
          'fileName': fileName,
        });
        if (result == null) throw Exception('Falha ao iniciar download nativo');
        downloadId = result;
        await saveActiveDownloadId(prefKey, downloadId);
      } catch (e) {
        throw Exception('Erro ao iniciar download nativo: $e');
      }
    }

    yield const DownloadProgress(0, 100);

    bool completed = false;
    while (!completed) {
      await Future.delayed(const Duration(seconds: 1));
      try {
        final Map<dynamic, dynamic>? progress =
            await _channel.invokeMethod<Map<dynamic, dynamic>>('getDownloadProgress', {
          'downloadId': downloadId,
        });

        if (progress == null) {
          throw Exception('Não foi possível obter o progresso do download');
        }

        final status = progress['status'] as String;
        final bytesDownloaded = progress['bytesDownloaded'] as int? ?? 0;
        final bytesTotal = progress['bytesTotal'] as int? ?? 0;

        if (status == 'successful') {
          await clearActiveDownloadId(prefKey);
          yield DownloadProgress(bytesDownloaded, bytesDownloaded > 0 ? bytesDownloaded : 1);
          completed = true;
        } else if (status == 'failed') {
          await clearActiveDownloadId(prefKey);
          final reason = progress['reason'] as int? ?? 0;
          throw Exception('Download falhou no Android DownloadManager (erro: $reason)');
        } else {
          yield DownloadProgress(
            bytesDownloaded,
            bytesTotal > 0 ? bytesTotal : 100,
          );
        }
      } catch (e) {
        await clearActiveDownloadId(prefKey);
        rethrow;
      }
    }
  }

  static Stream<DownloadProgress> downloadModel(AiModelType modelType) async* {
    if (Platform.isAndroid) {
      yield* _downloadNativeAndroid(
        url: modelType.url,
        fileName: modelType.fileName,
        prefKey: 'active_download_id_model_${modelType.id}',
      );
      return;
    }

    final path = await modelPath(modelType);
    final file = File(path);
    final tmp = File('$path.tmp');

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(modelType.url));
      request.headers.set('User-Agent', 'BestFin/1.0');
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      final total = response.contentLength;
      int received = 0;
      final sink = tmp.openWrite();

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        yield DownloadProgress(received, total);
      }

      await sink.flush();
      await sink.close();
      client.close();

      // Atomic rename
      await tmp.rename(path);
      yield DownloadProgress(received, received);
    } catch (e) {
      if (tmp.existsSync()) tmp.deleteSync();
      if (file.existsSync()) file.deleteSync();
      rethrow;
    }
  }

  static Future<void> deleteModel(AiModelType modelType) async {
    final path = await modelPath(modelType);
    final file = File(path);
    if (file.existsSync()) file.deleteSync();

    if (Platform.isAndroid) {
      final docs = await getApplicationDocumentsDirectory();
      final internalPath = p.join(docs.path, 'llm', modelType.fileName);
      final internalFile = File(internalPath);
      if (internalFile.existsSync()) internalFile.deleteSync();
    }
  }

  // ── mmproj (vision projector) support ───────────────────────────────────────

  static Future<String?> mmProjPath(AiModelType modelType) async {
    if (modelType.mmProjFileName == null) return null;

    if (Platform.isAndroid) {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final path = p.join(extDir.path, 'llm', modelType.mmProjFileName!);
        if (File(path).existsSync()) return path;
      }
    }

    final dir = await _llmDir();
    return p.join(dir.path, modelType.mmProjFileName!);
  }

  static Future<bool> isMmProjPresent(AiModelType modelType) async {
    if (modelType.mmProjFileName == null || modelType.mmProjSizeMb == null) return false;
    final minBytes = (modelType.mmProjSizeMb! * 1024 * 1024 * 0.95).round();

    if (Platform.isAndroid) {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final path = p.join(extDir.path, 'llm', modelType.mmProjFileName!);
        final f = File(path);
        if (f.existsSync() && f.lengthSync() >= minBytes) return true;
      }
    }

    final docs = await getApplicationDocumentsDirectory();
    final internalPath = p.join(docs.path, 'llm', modelType.mmProjFileName!);
    final f = File(internalPath);
    return f.existsSync() && f.lengthSync() >= minBytes;
  }

  static Stream<DownloadProgress> downloadMmProj(AiModelType modelType) async* {
    final url = modelType.mmProjUrl;
    final fileName = modelType.mmProjFileName;
    if (url == null || fileName == null) {
      throw UnsupportedError('Model ${modelType.id} does not have a vision projector.');
    }

    if (Platform.isAndroid) {
      yield* _downloadNativeAndroid(
        url: url,
        fileName: fileName,
        prefKey: 'active_download_id_mmproj_${modelType.id}',
      );
      return;
    }

    final path = (await mmProjPath(modelType))!;
    final file = File(path);
    final tmp = File('$path.tmp');

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'BestFin/1.0');
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      final total = response.contentLength;
      int received = 0;
      final sink = tmp.openWrite();

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        yield DownloadProgress(received, total);
      }

      await sink.flush();
      await sink.close();
      client.close();

      await tmp.rename(path);
      yield DownloadProgress(received, received);
    } catch (e) {
      if (tmp.existsSync()) tmp.deleteSync();
      if (file.existsSync()) file.deleteSync();
      rethrow;
    }
  }

  static Future<void> deleteMmProj(AiModelType modelType) async {
    final path = await mmProjPath(modelType);
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    }

    if (Platform.isAndroid && modelType.mmProjFileName != null) {
      final docs = await getApplicationDocumentsDirectory();
      final internalPath = p.join(docs.path, 'llm', modelType.mmProjFileName!);
      final internalFile = File(internalPath);
      if (internalFile.existsSync()) internalFile.deleteSync();
    }
  }
}
