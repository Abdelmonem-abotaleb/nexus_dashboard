class FuzzyMatchResult {
  final bool matches;
  final int score;
  final List<int> matchedIndices;

  const FuzzyMatchResult({
    required this.matches,
    required this.score,
    this.matchedIndices = const [],
  });

  static const FuzzyMatchResult noMatch = FuzzyMatchResult(
    matches: false,
    score: -1,
  );
}

class FuzzyMatcher {
  const FuzzyMatcher._();

  /// Scores a candidate against a query. Higher score is better.
  /// Returns [FuzzyMatchResult.noMatch] if query characters do not appear in order.
  static FuzzyMatchResult match(String query, String candidate) {
    final cleanQuery = query.trim().toLowerCase();
    final cleanCandidate = candidate.trim().toLowerCase();

    if (cleanQuery.isEmpty) {
      return const FuzzyMatchResult(matches: true, score: 0);
    }

    if (cleanCandidate.isEmpty) {
      return FuzzyMatchResult.noMatch;
    }

    // Exact match
    if (cleanCandidate == cleanQuery) {
      return const FuzzyMatchResult(matches: true, score: 200);
    }

    // Direct prefix match
    if (cleanCandidate.startsWith(cleanQuery)) {
      final score = 150 - (cleanCandidate.length - cleanQuery.length);
      final indices = List<int>.generate(cleanQuery.length, (i) => i);
      return FuzzyMatchResult(
        matches: true,
        score: score,
        matchedIndices: indices,
      );
    }

    // Substring match
    final substringIndex = cleanCandidate.indexOf(cleanQuery);
    if (substringIndex != -1) {
      final score = 100 - substringIndex - (cleanCandidate.length - cleanQuery.length);
      final indices = List<int>.generate(cleanQuery.length, (i) => substringIndex + i);
      return FuzzyMatchResult(
        matches: true,
        score: score,
        matchedIndices: indices,
      );
    }

    // Fuzzy subsequence search
    var queryIdx = 0;
    var score = 0;
    var consecutive = 0;
    final matchedIndices = <int>[];

    for (var i = 0; i < cleanCandidate.length && queryIdx < cleanQuery.length; i++) {
      if (cleanCandidate[i] == cleanQuery[queryIdx]) {
        matchedIndices.add(i);

        // Word boundary bonus
        final isWordStart = i == 0 ||
            cleanCandidate[i - 1] == ' ' ||
            cleanCandidate[i - 1] == '-' ||
            cleanCandidate[i - 1] == '_' ||
            cleanCandidate[i - 1] == '.';

        if (isWordStart) {
          score += 25;
        } else if (consecutive > 0) {
          score += 15 * consecutive;
        } else {
          score += 5;
        }

        consecutive++;
        queryIdx++;
      } else {
        consecutive = 0;
      }
    }

    if (queryIdx < cleanQuery.length) {
      return FuzzyMatchResult.noMatch;
    }

    // Penalty for length differences
    score -= (cleanCandidate.length - cleanQuery.length);

    return FuzzyMatchResult(
      matches: true,
      score: score,
      matchedIndices: matchedIndices,
    );
  }
}
