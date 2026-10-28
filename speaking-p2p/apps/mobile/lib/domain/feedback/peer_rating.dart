// The guided feedback rubric (Design 2.0 §9.2 #4): each candidate privately
// scores the other 1–5 on the four Cambridge speaking criteria. Only the person
// rated sees it. Not an official mark: a nudge towards concrete feedback.
enum Criterion { grammar, discourse, pronunciation, interaction }

class PeerRating {
  const PeerRating({this.scores = const {}});
  final Map<Criterion, int> scores;

  static const min = 1, max = 5;

  int? of(Criterion c) => scores[c];
  bool get isEmpty => scores.isEmpty;

  PeerRating withScore(Criterion c, int v) {
    if (v < min || v > max) throw ArgumentError.value(v, 'score', 'must be $min..$max');
    return PeerRating(scores: {...scores, c: v});
  }

  /// Column names in public.peer_ratings.
  static const column = {
    Criterion.grammar: 'grammar',
    Criterion.discourse: 'discourse',
    Criterion.pronunciation: 'pronunciation',
    Criterion.interaction: 'interaction',
  };

  Map<String, Object?> toRow() => {for (final c in Criterion.values) column[c]!: scores[c]};

  static PeerRating fromRow(Map<String, Object?> row) => PeerRating(scores: {
        for (final c in Criterion.values)
          if (row[column[c]] is int) c: row[column[c]]! as int,
      });
}

/// Averages of the ratings received (each criterion over the ratings that scored it).
class FeedbackSummary {
  const FeedbackSummary({this.count = 0, this.averages = const {}});
  final int count;
  final Map<Criterion, double> averages;

  factory FeedbackSummary.of(List<PeerRating> ratings) {
    final rated = ratings.where((r) => !r.isEmpty).toList();
    final avg = <Criterion, double>{};
    for (final c in Criterion.values) {
      final v = [for (final r in rated) ?r.of(c)];
      if (v.isNotEmpty) avg[c] = v.reduce((a, b) => a + b) / v.length;
    }
    return FeedbackSummary(count: rated.length, averages: avg);
  }
}
