import 'dart:math';

/// Multinomial Naive Bayes with Laplace (add-1) smoothing for transaction categorization.
/// Trained incrementally from the user's confirmed transaction history.
class NaiveBayesClassifier {
  final Map<String, Map<String, int>> _tokenCounts = {};
  final Map<String, int> _docCounts = {};
  final Set<String> _vocabulary = {};

  int get totalDocuments => _docCounts.values.fold(0, (s, v) => s + v);

  bool get hasSufficientData => totalDocuments >= 15 && _docCounts.length >= 2;

  void train(String description, String categoryId) {
    final tokens = _tokenize(description);
    if (tokens.isEmpty) return;
    _docCounts[categoryId] = (_docCounts[categoryId] ?? 0) + 1;
    _tokenCounts[categoryId] ??= {};
    for (final token in tokens) {
      _tokenCounts[categoryId]![token] =
          (_tokenCounts[categoryId]![token] ?? 0) + 1;
      _vocabulary.add(token);
    }
  }

  /// Returns (categoryId, confidence 0–1) or null when data is insufficient.
  (String, double)? predict(String description) {
    if (!hasSufficientData) return null;
    final tokens = _tokenize(description);
    if (tokens.isEmpty) return null;

    final totalDocs = totalDocuments;
    final vocabSize = _vocabulary.length + 1; // +1 for smoothing stability

    double bestScore = double.negativeInfinity;
    double secondBestScore = double.negativeInfinity;
    String? bestCat;

    for (final catId in _docCounts.keys) {
      final catDocs = _docCounts[catId]!;
      double score = log(catDocs / totalDocs);
      final catTokens = _tokenCounts[catId] ?? {};
      final catTotal = catTokens.values.fold(0, (s, v) => s + v);
      for (final token in tokens) {
        score += log(((catTokens[token] ?? 0) + 1) / (catTotal + vocabSize));
      }
      if (score > bestScore) {
        secondBestScore = bestScore;
        bestScore = score;
        bestCat = catId;
      } else if (score > secondBestScore) {
        secondBestScore = score;
      }
    }

    if (bestCat == null) return null;

    final margin = secondBestScore.isFinite
        ? bestScore - secondBestScore
        : 1.5; // only one category → moderate confidence
    final confidence = (1.0 - exp(-margin)).clamp(0.0, 0.95);

    return (bestCat, confidence);
  }

  static Set<String> _tokenize(String text) => text
      .toLowerCase()
      .split(RegExp(r'[\s\-_/,\.!?@#&\(\)]+'))
      .where((w) => w.length >= 3)
      .toSet();
}
