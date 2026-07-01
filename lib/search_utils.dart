List<String> generateSearchKeywords(String name) {
  List<String> keywords = [];
  String lowercaseName = name.toLowerCase().trim();

  if (lowercaseName.isEmpty) return keywords;

  // 1. Generate deduplicated variant (e.g. maggi -> magi, aashirvaad -> ashirvad)
  String deduplicated = lowercaseName.replaceAll(RegExp(r'(.)\1+'), r'$1');

  List<String> baseStrings = [lowercaseName, deduplicated];

  for (String base in baseStrings) {
    List<String> words = base.split(RegExp(r'\s+'));

    // Add full name and individual words
    keywords.add(base);
    keywords.addAll(words);

    // Generate prefixes for each word
    for (String word in words) {
      for (int i = 1; i <= word.length; i++) {
        keywords.add(word.substring(0, i));
      }

      // 2. Generate vowel-dropped variants for words > 4 chars (e.g. masala -> masla)
      if (word.length > 4) {
        String firstChar = word[0];
        String lastChar = word[word.length - 1];
        String middle = word.substring(1, word.length - 1);
        String middleNoVowels = middle.replaceAll(RegExp(r'[aeiou]'), '');
        String typoWord = firstChar + middleNoVowels + lastChar;

        if (typoWord != word) {
          keywords.add(typoWord);
          for (int i = 1; i <= typoWord.length; i++) {
            keywords.add(typoWord.substring(0, i));
          }
        }
      }
    }

    // Generate prefixes for full name
    for (int i = 1; i <= base.length; i++) {
      keywords.add(base.substring(0, i));
    }
  }

  return keywords.where((k) => k.isNotEmpty).toSet().toList();
}
