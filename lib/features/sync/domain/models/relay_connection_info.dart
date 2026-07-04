enum RelayStatus { connecting, connected, error }

class RelayConnectionInfo {
  final String url;
  final RelayStatus status;
  final String? errorMessage;

  const RelayConnectionInfo({
    required this.url,
    required this.status,
    this.errorMessage,
  });
}
