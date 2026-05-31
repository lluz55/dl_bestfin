enum AiModelType {
  minicpmV4_6,
  minicpm5_1b;

  String get id => name;

  String get displayName => switch (this) {
        AiModelType.minicpmV4_6 => 'MiniCPM-V 4.6 (Multimodal)',
        AiModelType.minicpm5_1b => 'MiniCPM5-1B (Apenas Texto)',
      };

  String get fileName => switch (this) {
        AiModelType.minicpmV4_6 => 'MiniCPM-V-4_6-Q4_K_M.gguf',
        AiModelType.minicpm5_1b => 'MiniCPM5-1B-Q4_K_M.gguf',
      };

  String get url => switch (this) {
        AiModelType.minicpmV4_6 =>
          'https://huggingface.co/openbmb/MiniCPM-V-4.6-gguf/resolve/main/MiniCPM-V-4_6-Q4_K_M.gguf',
        AiModelType.minicpm5_1b =>
          'https://huggingface.co/openbmb/MiniCPM5-1B-GGUF/resolve/main/MiniCPM5-1B-Q4_K_M.gguf',
      };

  int get sizeMb => switch (this) {
        AiModelType.minicpmV4_6 => 529,
        AiModelType.minicpm5_1b => 657,
      };

  String get description => switch (this) {
        AiModelType.minicpmV4_6 =>
          'Modelo multimodal com suporte a imagem e texto, ideal para escanear faturas.',
        AiModelType.minicpm5_1b =>
          'Modelo compacto de texto, ultra-rápido para responder perguntas financeiras.',
      };

  /// Whether this model supports image/vision input via a separate mmproj file.
  bool get hasVision => this == AiModelType.minicpmV4_6;

  /// Filename of the multimodal projector (mmproj) required for vision support.
  /// Returns null for text-only models.
  String? get mmProjFileName => switch (this) {
        AiModelType.minicpmV4_6 => 'mmproj-MiniCPM-V-4_6-f16.gguf',
        _ => null,
      };

  /// Download URL for the mmproj file, or null if not applicable.
  String? get mmProjUrl => switch (this) {
        AiModelType.minicpmV4_6 =>
          'https://huggingface.co/openbmb/MiniCPM-V-4.6-gguf/resolve/main/mmproj-MiniCPM-V-4_6-f16.gguf',
        _ => null,
      };

  /// Approximate size of the mmproj file in MB.
  int? get mmProjSizeMb => switch (this) {
        AiModelType.minicpmV4_6 => 570,
        _ => null,
      };
}
