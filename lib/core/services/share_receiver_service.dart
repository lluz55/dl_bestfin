import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ShareReceiverService {
  static const _channel = MethodChannel('com.bestfin.bestfin/share_receiver');

  /// Verifica se há dados compartilhados pendentes no lado nativo.
  /// Retorna um mapa contendo 'text' e/ou 'imageUri' (o caminho local em cache).
  static Future<Map<String, String?>?> checkSharedData() async {
    try {
      final Map<dynamic, dynamic>? data = await _channel.invokeMethod(
        'getSharedData',
      );
      if (data != null) {
        return Map<String, String?>.from(data);
      }
    } on PlatformException catch (e) {
      debugPrint('Erro ao verificar dados de compartilhamento: ${e.message}');
    }
    return null;
  }
}
