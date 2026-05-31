class LlmMetrics {
  final Duration timeToFirstToken;
  final Duration totalTime;
  final int tokensGenerated;
  final double tokensPerSecond;
  final String modelName;

  const LlmMetrics({
    required this.timeToFirstToken,
    required this.totalTime,
    required this.tokensGenerated,
    required this.tokensPerSecond,
    required this.modelName,
  });
}
