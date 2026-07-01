List<String> generateSearchKeywords(String name) {
  List<String> keywords = [];
  String lowercaseName = name.toLowerCase().trim();

  if (lowercaseName.isEmpty) return keywords;

  List<String> words = lowercaseName.split(RegExp(r'\s+'));

  // Add full name and individual words
  keywords.add(lowercaseName);
  keywords.addAll(words);

  // Generate prefixes for each word
  for (String word in words) {
    for (int i = 1; i <= word.length; i++) {
      keywords.add(word.substring(0, i));
    }
  }

  // Generate prefixes for full name
  for (int i = 1; i <= lowercaseName.length; i++) {
    keywords.add(lowercaseName.substring(0, i));
  }

  return keywords.toSet().toList();
}
