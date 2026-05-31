enum LlmStatus { uninitialized, downloading, loading, ready, generating, error }

class LlmState {
  final LlmStatus status;
  final double downloadProgress; // 0.0 to 1.0
  final String? errorMessage;

  const LlmState({
    required this.status,
    this.downloadProgress = 0.0,
    this.errorMessage,
  });

  const LlmState.initial() : this(status: LlmStatus.uninitialized);

  bool get isReady => status == LlmStatus.ready;
  bool get isBusy =>
      status == LlmStatus.downloading ||
      status == LlmStatus.loading ||
      status == LlmStatus.generating;
  bool get canChat =>
      status == LlmStatus.ready || status == LlmStatus.generating;

  LlmState copyWith({
    LlmStatus? status,
    double? downloadProgress,
    String? errorMessage,
  }) {
    return LlmState(
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
