/// Première ligne du texte utilisateur comme titre d’issue (max 255 caractères).
String deriveFeedbackIssueTitle(String text) {
  if (text.isEmpty) return 'Feedback';
  final firstLine = text.split(RegExp(r'\r?\n')).first.trim();
  if (firstLine.isEmpty) return 'Feedback';
  if (firstLine.length <= 255) return firstLine;
  return firstLine.substring(0, 255);
}
