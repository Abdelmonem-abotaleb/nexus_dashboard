import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_dashboard/services/fuzzy_matcher.dart';

void main() {
  group('FuzzyMatcher', () {
    test('empty query matches everything with score 0', () {
      final res = FuzzyMatcher.match('', 'Google Chrome');
      expect(res.matches, isTrue);
      expect(res.score, 0);
    });

    test('exact match has highest score', () {
      final exact = FuzzyMatcher.match('chrome', 'chrome');
      final prefix = FuzzyMatcher.match('chrome', 'chrome beta');
      expect(exact.matches, isTrue);
      expect(prefix.matches, isTrue);
      expect(exact.score, greaterThan(prefix.score));
    });

    test('prefers prefix match over substring match', () {
      final prefix = FuzzyMatcher.match('chr', 'Chrome');
      final substring = FuzzyMatcher.match('chr', 'Google Chrome');
      expect(prefix.matches, isTrue);
      expect(substring.matches, isTrue);
      expect(prefix.score, greaterThan(substring.score));
    });

    test('fuzzy subsequence matches characters in order', () {
      final match = FuzzyMatcher.match('gc', 'Google Chrome');
      expect(match.matches, isTrue);
    });

    test('does not match out of order characters', () {
      final match = FuzzyMatcher.match('cg', 'Google Chrome');
      expect(match.matches, isFalse);
    });

    test('case insensitive matching', () {
      final match = FuzzyMatcher.match('cHrOmE', 'chrome');
      expect(match.matches, isTrue);
    });
  });
}
