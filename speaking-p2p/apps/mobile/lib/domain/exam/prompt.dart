// Part 2 instructions shown like the real candidate booklet: the questions
// apart from the rest (D-052). Display only: the content, its audio and
// audioMs never change, and [PromptParts.text] rebuilds the exact original.
//
//   "Candidate A, … Choose two of the pictures and say what X, and how Y."
//   -> lead "Candidate A, … Choose two of the pictures and say"
//      questions ["what X", "how Y"]
class PromptParts {
  const PromptParts(this.lead, this.questions);

  final String lead;
  final List<String> questions;

  // Up to the first " and say ", then the questions, ending in a full stop.
  static final _shape = RegExp(r'^(.*? and say) (.+)\.$', dotAll: true);

  /// Null when [text] does not have that shape (B1, the questions to the
  /// partner, any future wording): the card then shows the text as it is.
  static PromptParts? parse(String text) {
    final m = _shape.firstMatch(text);
    if (m == null) return null;
    final questions = m.group(2)!.split(', and ');
    if (questions.any((q) => q.trim().isEmpty)) return null;
    final parts = PromptParts(m.group(1)!, questions);
    return parts.text == text ? parts : null;
  }

  /// The original sentence, character for character.
  String get text => '$lead ${questions.join(', and ')}.';
}
