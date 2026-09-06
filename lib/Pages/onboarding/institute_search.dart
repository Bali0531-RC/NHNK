/// Accent folding for the onboarding institution search. Kept out of the widget so
/// the matching rule can be tested without building a page.
const Map<String, String> _fold = {
  'á': 'a', 'ä': 'a', 'â': 'a',
  'é': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'î': 'i',
  'ó': 'o', 'ö': 'o', 'ő': 'o', 'ô': 'o',
  'ú': 'u', 'ü': 'u', 'ű': 'u', 'û': 'u',
};

String normaliseInstituteName(String value) {
  final buffer = StringBuffer();
  for (final ch in value.toLowerCase().split('')) {
    buffer.write(_fold[ch] ?? ch);
  }
  return buffer.toString();
}

bool instituteMatches(String name, String query) {
  final q = normaliseInstituteName(query.trim());
  if (q.isEmpty) return true;
  return normaliseInstituteName(name).contains(q);
}
