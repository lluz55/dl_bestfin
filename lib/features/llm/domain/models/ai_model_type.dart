enum AiModelRuntime { llamaServer, llamaCpp, liteRtLm }

enum AiModelType {
  minicpmV4_6,
  minicpm5_1b,
  qwen3_0_6bLiteRt,
  gemma3nE2bLiteRt;

  // minicpmV4_6 uses the 'qwen35' GGUF architecture, supported only in the
  // Linux llama-server binary. The Android pre-built SOs lack qwen35 support,
  // and vision (the model's main feature) is not available on Android anyway.
  bool get isLinuxOnly => this == AiModelType.minicpmV4_6;

  bool get isAndroidOnly => runtime == AiModelRuntime.liteRtLm;

  AiModelRuntime get runtime => switch (this) {
    AiModelType.minicpmV4_6 => AiModelRuntime.llamaServer,
    AiModelType.minicpm5_1b => AiModelRuntime.llamaCpp,
    AiModelType.qwen3_0_6bLiteRt => AiModelRuntime.liteRtLm,
    AiModelType.gemma3nE2bLiteRt => AiModelRuntime.liteRtLm,
  };

  String get id => name;

  String get displayName => switch (this) {
    AiModelType.minicpmV4_6 => 'MiniCPM-V 4.6 (Multimodal)',
    AiModelType.minicpm5_1b => 'MiniCPM5-1B (Apenas Texto)',
    AiModelType.qwen3_0_6bLiteRt => 'Qwen3 0.6B (LiteRT, Android)',
    AiModelType.gemma3nE2bLiteRt => 'Gemma 3n E2B (LiteRT, Android)',
  };

  String get fileName => switch (this) {
    AiModelType.minicpmV4_6 => 'MiniCPM-V-4_6-Q4_K_M.gguf',
    AiModelType.minicpm5_1b => 'MiniCPM5-1B-Q4_K_M.gguf',
    AiModelType.qwen3_0_6bLiteRt => 'Qwen3-0.6B.litertlm',
    AiModelType.gemma3nE2bLiteRt => 'gemma-3n-E2B-it-int4.litertlm',
  };

  String get url => switch (this) {
    AiModelType.minicpmV4_6 =>
      'https://huggingface.co/openbmb/MiniCPM-V-4.6-gguf/resolve/main/MiniCPM-V-4_6-Q4_K_M.gguf',
    AiModelType.minicpm5_1b =>
      'https://huggingface.co/openbmb/MiniCPM5-1B-GGUF/resolve/main/MiniCPM5-1B-Q4_K_M.gguf',
    AiModelType.qwen3_0_6bLiteRt => const String.fromEnvironment(
      'BESTFIN_QWEN3_LITERT_URL',
      defaultValue:
          'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B.litertlm',
    ),
    AiModelType.gemma3nE2bLiteRt => const String.fromEnvironment(
      'BESTFIN_GEMMA_LITERT_URL',
      defaultValue:
          'https://huggingface.co/google/gemma-3n-E2B-it-litert-lm/resolve/main/gemma-3n-E2B-it-int4.litertlm',
    ),
  };

  int get sizeMb => switch (this) {
    AiModelType.minicpmV4_6 => 529,
    AiModelType.minicpm5_1b => 657,
    AiModelType.qwen3_0_6bLiteRt => 586,
    AiModelType.gemma3nE2bLiteRt => 3660,
  };

  // Exact byte sizes for integrity checks (source: actual downloaded files).
  int get sizeBytes => switch (this) {
    AiModelType.minicpmV4_6 => 554_600_960,
    AiModelType.minicpm5_1b => 688_065_920,
    AiModelType.qwen3_0_6bLiteRt => 586_000_000,
    AiModelType.gemma3nE2bLiteRt => 3_660_000_000,
  };

  String get description => switch (this) {
    AiModelType.minicpmV4_6 =>
      'Modelo multimodal com suporte a imagem e texto, ideal para escanear faturas.',
    AiModelType.minicpm5_1b =>
      'Modelo compacto de texto, ultra-rápido para responder perguntas financeiras.',
    AiModelType.qwen3_0_6bLiteRt =>
      'Modelo local pequeno, rápido e sem licença gated para Android.',
    AiModelType.gemma3nE2bLiteRt =>
      'Modelo local Gemma otimizado para Android via LiteRT-LM.',
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
