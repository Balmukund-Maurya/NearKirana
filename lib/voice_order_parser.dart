// Natural Language Hindi / Hinglish / English Voice Order Parser
// Feature 61: Voice-Based Grocery Ordering (वॉइस-बेस्ड ग्रॉसरी ऑर्डरिंग)

import 'voice_order_models.dart';

class VoiceOrderParser {
  /// Map of Hindi / Hinglish and English numerals to numeric values
  static const Map<String, double> numberWords = {
    // English words
    'one': 1.0,
    'two': 2.0,
    'three': 3.0,
    'four': 4.0,
    'five': 5.0,
    'six': 6.0,
    'seven': 7.0,
    'eight': 8.0,
    'nine': 9.0,
    'ten': 10.0,

    // Hinglish transliteration
    'ek': 1.0,
    'aik': 1.0,
    'do': 2.0,
    'teen': 3.0,
    'tin': 3.0,
    'char': 4.0,
    'chaar': 4.0,
    'paanch': 5.0,
    'panch': 5.0,
    'chhe': 6.0,
    'che': 6.0,
    'saat': 7.0,
    'sat': 7.0,
    'aath': 8.0,
    'ath': 8.0,
    'nau': 9.0,
    'das': 10.0,
    'gyarah': 11.0,
    'barah': 12.0,

    // Hindi Devanagari numerals
    'एक': 1.0,
    'दो': 2.0,
    'तीन': 3.0,
    'चार': 4.0,
    'पांच': 5.0,
    'पाँच': 5.0,
    'छह': 6.0,
    'सात': 7.0,
    'आठ': 8.0,
    'नौ': 9.0,
    'दस': 10.0,
    'ग्यारह': 11.0,
    'बारह': 12.0,

    // Fractions & Kirana colloquial quantities
    'aadha': 0.5,
    'adha': 0.5,
    'half': 0.5,
    'आधा': 0.5,
    'paav': 0.25,
    'pao': 0.25,
    'pav': 0.25,
    'quarter': 0.25,
    'पाव': 0.25,
    'sawa': 1.25,
    'सवा': 1.25,
    'dedh': 1.5,
    'डेढ़': 1.5,
    'dhai': 2.5,
    'ढाई': 2.5,
  };

  /// Common unit definitions and aliases
  static const Map<String, String> unitAliases = {
    // Weight
    'kilo': 'kg',
    'kilos': 'kg',
    'kg': 'kg',
    'kgs': 'kg',
    'kilogram': 'kg',
    'किलो': 'kg',
    'किलोग्राम': 'kg',

    'gram': 'gram',
    'grams': 'gram',
    'gm': 'gram',
    'gms': 'gram',
    'g': 'gram',
    'ग्राम': 'gram',

    // Volume
    'litre': 'litre',
    'liter': 'litre',
    'litres': 'litre',
    'liters': 'litre',
    'ltr': 'litre',
    'l': 'litre',
    'लीटर': 'litre',

    'ml': 'ml',
    'मिली': 'ml',

    // Count / Packets
    'packet': 'packet',
    'packets': 'packet',
    'pkt': 'packet',
    'pkts': 'packet',
    'pack': 'packet',
    'packs': 'packet',
    'पैकेट': 'packet',

    'piece': 'piece',
    'pieces': 'piece',
    'pc': 'piece',
    'pcs': 'piece',
    'पीस': 'piece',
    'tukda': 'piece',

    'bottle': 'bottle',
    'bottles': 'bottle',
    'बोतल': 'bottle',

    'darjan': 'dozen',
    'dozen': 'dozen',
    'दर्जन': 'dozen',

    'box': 'box',
    'boxes': 'box',
    'डिब्बा': 'box',
  };

  /// Hindi vernacular synonyms mapping to English and standard grocery terms
  static const Map<String, List<String>> vernacularSynonyms = {
    'doodh': ['milk', 'doodh', 'amul', 'mother dairy'],
    'dudh': ['milk', 'doodh'],
    'दूध': ['milk', 'doodh'],
    'atta': ['atta', 'flour', 'aashirvaad', 'chakki'],
    'aata': ['atta', 'flour'],
    'आटा': ['atta', 'flour'],
    'cheeni': ['sugar', 'cheeni', 'shakkar'],
    'shakkar': ['sugar', 'cheeni'],
    'चीनी': ['sugar', 'cheeni'],
    'chai': ['tea', 'chai', 'taj mahal', 'tata tea', 'red label'],
    'chaipatti': ['tea', 'chai'],
    'चाय': ['tea', 'chai'],
    'tel': ['oil', 'mustard oil', 'fortune', 'refined', 'tel'],
    'sarson': ['mustard', 'sarson'],
    'तेल': ['oil'],
    'chawal': ['rice', 'chawal', 'basmati', 'kolam'],
    'चावल': ['rice', 'chawal'],
    'daal': ['dal', 'daal', 'toor', 'moong', 'chana', 'urad', 'masoor'],
    'dal': ['dal', 'daal'],
    'दाल': ['dal', 'daal'],
    'aloo': ['potato', 'aloo', 'batata'],
    'alu': ['potato', 'aloo'],
    'आलू': ['potato', 'aloo'],
    'pyaaz': ['onion', 'pyaaz', 'kanda'],
    'pyaj': ['onion', 'pyaaz'],
    'प्याज': ['onion', 'pyaaz'],
    'tamatar': ['tomato', 'tamatar'],
    'टमाटर': ['tomato', 'tamatar'],
    'namak': ['salt', 'namak', 'tata salt'],
    'नमक': ['salt', 'namak'],
    'dahi': ['curd', 'dahi', 'yogurt'],
    'दही': ['curd', 'dahi'],
    'paneer': ['paneer', 'cottage cheese'],
    'पनीर': ['paneer'],
    'makhan': ['butter', 'makhan', 'amul butter'],
    'मक्खन': ['butter'],
    'ghee': ['ghee', 'desi ghee', 'amul ghee'],
    'घी': ['ghee'],
    'sabun': ['soap', 'sabun', 'lifebuoy', 'dettol', 'lux', 'dove'],
    'साबुन': ['soap'],
    'surf': ['detergent', 'surf excel', 'surf', 'ariel', 'tide', 'wheel'],
    'detergent': ['detergent', 'surf', 'surf excel'],
    'biscuit': ['biscuit', 'parle', 'parle-g', 'marie', 'good day', 'oreo'],
    'biskoot': ['biscuit'],
    'बिस्कुट': ['biscuit'],
    'maggi': ['maggi', 'noodles', 'yippee'],
    'मैगी': ['maggi'],
    'haldi': ['turmeric', 'haldi'],
    'हल्दी': ['turmeric'],
    'mirch': ['chilli', 'chilly', 'mirchi', 'mirch'],
    'mirchi': ['chilli', 'mirch'],
    'मिर्च': ['chilli'],
    'dhaniya': ['coriander', 'dhaniya'],
    'धनिया': ['coriander'],
    'jeera': ['cumin', 'jeera'],
    'जीरा': ['cumin'],
    'kela': ['banana', 'kela'],
    'केला': ['banana'],
    'seb': ['apple', 'seb'],
    'सेब': ['apple'],
    'bread': ['bread', 'pav', 'loaf'],
    'ब्रेड': ['bread'],
    'anda': ['egg', 'eggs', 'anda'],
    'ande': ['egg', 'eggs', 'anda'],
    'अंडा': ['egg'],
  };

  /// Common filler words and action instructions to strip from segments
  static final List<RegExp> _actionFillers = [
    RegExp(r'\b(add\s+karo|add\s+kardo|add\s+kar\s+do|add\s+karna|add)\b', caseSensitive: false),
    RegExp(r'\b(cart\s+me\s+daal\s+do|cart\s+me\s+add\s+karo|cart\s+me\s+jod\s+do)\b', caseSensitive: false),
    RegExp(r'\b(daal\s+do|daalo|chahiye|mangwana\s+hai|dedo|de\s+do|bhejo)\b', caseSensitive: false),
    RegExp(r'\b(pack\s+karo|pack\s+kardo|laga\s+do|le\s+lo|kripya|please)\b', caseSensitive: false),
    RegExp(r'\b(mujhe|humko|bhi|ek\s+baar|kardo|kar\s+do)\b', caseSensitive: false),
    RegExp(r'(जोड़ें|डालें|चाहिए|भेजो|दीजिए|करो|कृपया)', caseSensitive: false),
  ];

  /// Conjunction splitter (Hindi: aur, tatha, evam, phir, sath me; English: and, or, comma, plus)
  static final RegExp _conjunctionSplitter = RegExp(
    r'(?:\b(?:aur|and|or|tatha|evam|phir|sath\s+me|sath\s+mein|bhi)\b|[,+;&\n]+|\bऔर\b|\bतथा\b|\bएवं\b)',
    caseSensitive: false,
  );

  /// Detect language style of spoken query
  static String detectLanguage(String text) {
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) {
      return 'Hindi';
    }
    final lower = text.toLowerCase();
    final hinglishMarkers = ['karo', 'chahiye', 'doodh', 'atta', 'kilo', 'aadha', 'aur', 'pyaaz', 'aloo', 'ek', 'do'];
    for (final marker in hinglishMarkers) {
      if (lower.contains(marker)) {
        return 'Hinglish';
      }
    }
    return 'English';
  }

  /// Parse the entire spoken phrase into items matched against store catalog
  static VoiceOrderParseResult parseSpokenOrder({
    required String spokenText,
    required List<VoiceCatalogProduct> catalog,
  }) {
    final cleanInput = spokenText.trim();
    if (cleanInput.isEmpty) {
      return VoiceOrderParseResult(
        spokenText: spokenText,
        detectedLanguage: 'Hinglish',
        parsedItems: [],
      );
    }

    final detectedLang = detectLanguage(cleanInput);

    // Split input into item segments
    final rawSegments = cleanInput
        .split(_conjunctionSplitter)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final List<ParsedVoiceItem> parsedItems = [];

    for (final segment in rawSegments) {
      final parsed = _parseSingleSegment(segment, catalog);
      if (parsed != null) {
        parsedItems.add(parsed);
      }
    }

    return VoiceOrderParseResult(
      spokenText: spokenText,
      detectedLanguage: detectedLang,
      parsedItems: parsedItems,
    );
  }

  /// Parse a single segment like "Do kilo atta" or "ek litre doodh add karo"
  static ParsedVoiceItem? _parseSingleSegment(
    String rawSegment,
    List<VoiceCatalogProduct> catalog,
  ) {
    String working = rawSegment;

    // 1. Strip common action fillers
    for (final pattern in _actionFillers) {
      working = working.replaceAll(pattern, ' ');
    }
    working = working.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (working.isEmpty) return null;

    // 2. Extract Quantity and Unit
    double quantity = 1.0;
    String? detectedUnit;
    bool quantityExplicitlyFound = false;

    // Match patterns like "500 gram", "2 kg", "2.5 kilo", "1.5 ltr"
    final numericUnitRegex = RegExp(
      r'(\d+(?:\.\d+)?)\s*([a-zA-Z\u0900-\u097F]+)?',
      caseSensitive: false,
    );
    final numericMatch = numericUnitRegex.firstMatch(working);

    if (numericMatch != null) {
      final numStr = numericMatch.group(1);
      final possibleUnit = numericMatch.group(2)?.toLowerCase().trim();

      if (numStr != null) {
        final parsedNum = double.tryParse(numStr);
        if (parsedNum != null) {
          quantity = parsedNum;
          quantityExplicitlyFound = true;

          // Check if possibleUnit is a valid unit
          if (possibleUnit != null && unitAliases.containsKey(possibleUnit)) {
            detectedUnit = unitAliases[possibleUnit];
            // Remove the quantity and unit from working string
            working = working.replaceFirst(numericMatch.group(0)!, ' ').trim();
          } else {
            // Remove just the number
            working = working.replaceFirst(numStr, ' ').trim();
          }
        }
      }
    }

    // If no numeric digits found, look for word numerals (e.g. "do", "teen", "aadha", "paav", "ek")
    if (!quantityExplicitlyFound) {
      final words = working.split(' ');
      for (int i = 0; i < words.length; i++) {
        final w = words[i].toLowerCase();
        if (numberWords.containsKey(w)) {
          quantity = numberWords[w]!;
          quantityExplicitlyFound = true;

          // Check if the next word is a unit (e.g., "do kilo")
          if (i + 1 < words.length) {
            final nextWord = words[i + 1].toLowerCase();
            if (unitAliases.containsKey(nextWord)) {
              detectedUnit = unitAliases[nextWord];
              // Remove both numeral and unit
              words.removeAt(i + 1);
            }
          }
          words.removeAt(i);
          working = words.join(' ');
          break;
        }
      }
    }

    // If unit was not attached to number, check remaining words for standalone unit (e.g. "kilo", "litre", "packet")
    if (detectedUnit == null) {
      final words = working.split(' ');
      for (int i = 0; i < words.length; i++) {
        final w = words[i].toLowerCase();
        if (unitAliases.containsKey(w)) {
          detectedUnit = unitAliases[w];
          words.removeAt(i);
          working = words.join(' ');
          break;
        }
      }
    }

    // Clean up residual punctuation and spaces
    String cleanedItemQuery = working
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s\u0900-\u097F]'), '')
        .trim();

    if (cleanedItemQuery.isEmpty) {
      // If only quantity was given without an item name
      return null;
    }

    // 3. Match against product catalog
    final matchResult = _matchCatalog(cleanedItemQuery, catalog);

    // 4. Compute final normalized quantity
    final effectiveMatchedProd = matchResult.matchedProduct;
    double finalQuantity = quantity;

    if (effectiveMatchedProd != null) {
      finalQuantity = _normalizeQuantity(
        rawQuantity: quantity,
        unit: detectedUnit,
        product: effectiveMatchedProd,
      );
    } else if (matchResult.candidateProducts.isNotEmpty) {
      finalQuantity = _normalizeQuantity(
        rawQuantity: quantity,
        unit: detectedUnit,
        product: matchResult.candidateProducts.first,
      );
    }

    return ParsedVoiceItem(
      rawSegment: rawSegment,
      rawItemName: cleanedItemQuery,
      requestedQuantity: quantity,
      unit: detectedUnit,
      matchedProduct: matchResult.matchedProduct,
      candidateProducts: matchResult.candidateProducts,
      status: matchResult.status,
      clarificationReason: matchResult.clarificationReason,
      finalQuantity: finalQuantity,
    );
  }

  /// Catalog Matching with scoring, synonyms, and ambiguity detection
  static _CatalogMatchResult _matchCatalog(
    String query,
    List<VoiceCatalogProduct> catalog,
  ) {
    if (catalog.isEmpty) {
      return _CatalogMatchResult(
        status: VoiceItemStatus.notFound,
        clarificationReason: 'No products in store catalog',
      );
    }

    final queryLower = query.toLowerCase().trim();
    final queryWords = queryLower
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // Expand query words with vernacular synonyms
    final expandedTerms = <String>{queryLower, ...queryWords};
    for (final word in queryWords) {
      if (vernacularSynonyms.containsKey(word)) {
        expandedTerms.addAll(vernacularSynonyms[word]!);
      }
    }

    // Score all catalog products
    final List<MapEntry<VoiceCatalogProduct, int>> scoredProducts = [];

    for (final prod in catalog) {
      final prodNameLower = prod.name.toLowerCase();
      final prodKeywords = prod.searchKeywords.map((k) => k.toLowerCase()).toSet();
      final prodCategory = prod.category?.toLowerCase() ?? '';

      int score = 0;

      // 1. Exact Name match (100 pts)
      if (prodNameLower == queryLower) {
        score += 100;
      }
      // 2. Exact containment
      else if (prodNameLower.contains(queryLower)) {
        score += 75;
      } else if (queryLower.contains(prodNameLower)) {
        score += 65;
      }

      // 3. Keyword matches
      if (prodKeywords.contains(queryLower)) {
        score += 50;
      }

      int matchedTermCount = 0;
      for (final term in expandedTerms) {
        if (prodNameLower.contains(term)) {
          score += 35;
          matchedTermCount++;
        } else if (prodKeywords.contains(term)) {
          score += 25;
          matchedTermCount++;
        } else if (prodCategory.contains(term)) {
          score += 15;
          matchedTermCount++;
        }
      }

      if (matchedTermCount > 1) {
        score += (matchedTermCount * 10);
      }

      if (score > 0) {
        scoredProducts.add(MapEntry(prod, score));
      }
    }

    if (scoredProducts.isEmpty) {
      return _CatalogMatchResult(
        status: VoiceItemStatus.notFound,
        clarificationReason: 'No matching product found in store',
      );
    }

    // Sort descending by match score
    scoredProducts.sort((a, b) => b.value.compareTo(a.value));

    final topScore = scoredProducts.first.value;

    // Filter products that have a competitive score (>= 75% of top score)
    final candidateEntries = scoredProducts
        .where((e) => e.value >= (topScore * 0.75).round())
        .toList();

    final bestProduct = scoredProducts.first.key;
    final bool isExactFullNameMatch =
        bestProduct.name.toLowerCase() == queryLower;

    // Case A: Multiple competitive products found -> Ambiguous
    if (candidateEntries.length > 1 && !isExactFullNameMatch) {
      final candidates = candidateEntries.map((e) => e.key).toList();
      return _CatalogMatchResult(
        candidateProducts: candidates,
        status: VoiceItemStatus.ambiguous,
        clarificationReason:
            'Multiple products match "$query". Please choose which brand or variant you want.',
      );
    }

    // Case B: Single dominant product match
    // Check stock availability
    if (!bestProduct.isAvailable) {
      return _CatalogMatchResult(
        matchedProduct: bestProduct,
        status: VoiceItemStatus.outOfStock,
        clarificationReason: '${bestProduct.name} is currently out of stock',
      );
    }

    return _CatalogMatchResult(
      matchedProduct: bestProduct,
      candidateProducts: [bestProduct],
      status: VoiceItemStatus.ready,
    );
  }

  /// Normalizes requested quantity based on product unit and loose vs packaged status
  static double _normalizeQuantity({
    required double rawQuantity,
    required String? unit,
    required VoiceCatalogProduct product,
  }) {
    if (rawQuantity <= 0) return 1.0;

    // If unit is grams
    if (unit == 'gram') {
      if (product.isLoose || (product.unit?.toLowerCase() == 'kg')) {
        // 500 grams -> 0.5 kg, 250 grams -> 0.25 kg
        return (rawQuantity / 1000.0);
      }
      return 1.0;
    }

    // If unit is dozen
    if (unit == 'dozen') {
      if (product.name.toLowerCase().contains('dozen')) {
        return rawQuantity;
      }
      // If sold individually
      return rawQuantity * 12.0;
    }

    // If unit is litre and product is 500ml milk packet
    if (unit == 'litre') {
      if (product.name.toLowerCase().contains('500ml') ||
          (product.unit?.toLowerCase() == '500ml')) {
        // 1 litre = 2 packets of 500ml
        return rawQuantity * 2.0;
      }
      return rawQuantity;
    }

    // Default: use parsed quantity directly
    return rawQuantity;
  }
}

class _CatalogMatchResult {
  final VoiceCatalogProduct? matchedProduct;
  final List<VoiceCatalogProduct> candidateProducts;
  final VoiceItemStatus status;
  final String? clarificationReason;

  _CatalogMatchResult({
    this.matchedProduct,
    this.candidateProducts = const [],
    required this.status,
    this.clarificationReason,
  });
}
