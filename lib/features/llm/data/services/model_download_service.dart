import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:bestfin/features/llm/domain/models/ai_model_type.dart';

class DownloadProgress {
  final int received;
  final int total;

  const DownloadProgress(this.received, this.total);

  double get fraction => total > 0 ? received / total : 0.0;
  bool get isComplete => total > 0 && received >= total;
}

class ModelDownloadService {
  static Future<Directory> _llmDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'llm'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<String> modelPath(AiModelType modelType) async {
    final dir = await _llmDir();
    return p.join(dir.path, modelType.fileName);
  }

  static Future<bool> isModelPresent(AiModelType modelType) async {
    final path = await modelPath(modelType);
    return File(path).existsSync();
  }

  static Stream<DownloadProgress> downloadModel(AiModelType modelType) async* {
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
  }

  // ── mmproj (vision projector) support ───────────────────────────────────────

  static Future<String?> mmProjPath(AiModelType modelType) async {
    if (modelType.mmProjFileName == null) return null;
    final dir = await _llmDir();
    return p.join(dir.path, modelType.mmProjFileName!);
  }

  static Future<bool> isMmProjPresent(AiModelType modelType) async {
    final path = await mmProjPath(modelType);
    if (path == null) return false;
    return File(path).existsSync();
  }

  static Stream<DownloadProgress> downloadMmProj(AiModelType modelType) async* {
    final url = modelType.mmProjUrl;
    final fileName = modelType.mmProjFileName;
    if (url == null || fileName == null) {
      throw UnsupportedError('Model ${modelType.id} does not have a vision projector.');
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
    if (path == null) return;
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  }
}
