import 'terminology_store.dart';

/// Spoken-word → symptom-chip catalogue (user 2026-08-22: "make a proper
/// catalogue and mapping correct — take time and put every related word").
///
/// The doctor dictates the Observation in Hindi / Hinglish / English and
/// every problem mentioned must appear as a selected symptom chip.
///
/// MATCHING IS WORD-BASED, not substring-based: "पीठ में दर्द हो रहा है"
/// normalises to `pith men dard ho raha hai`; filler words (में/हो/रहा/है…)
/// are dropped and the remaining words {pith, dard} are compared against
/// each pattern's words — ALL pattern words present (any order) = chip.
/// Per-word comparison is triple-tolerant:
///   1. loose equality (repeated letters collapse: bukhaar == bukhar)
///   2. consonant skeleton (vowels vary wildly in Hinglish: peeth == pith,
///      seene == sina, jukham == jukam)
///   3. containment for longer words (sardard contains dard)
/// Devanagari goes through TerminologyStore.normalize's transliteration
/// first, so बुखार / bukhaar / fever all land on the same chip, and one
/// sentence can light up several chips at once.
class SymptomCatalog {
  SymptomCatalog._();

  /// Filler / grammar words in Hindi, Hinglish and English that carry no
  /// clinical meaning. NOTE: nahi/kam are deliberately KEPT (they are
  /// load-bearing in "bhukh nahi", "nind kam").
  static const Set<String> _stop = {
    'me', 'mein', 'men', 'mem', 'mai', 'may', 'ho', 'hota', 'hoti', 'hona',
    'raha', 'rahi', 'rahe', 'rha', 'rhi', 'hai', 'hain', 'he', 'hei',
    'ka', 'ki', 'ke', 'ko', 'se', 'par', 'pe', 'per', 'aur', 'or', 'bhi',
    'to', 'toh', 'ye', 'yah', 'yeh', 'wo', 'vo', 'us', 'is', 'and', 'the',
    'mera', 'meri', 'mere', 'mujhe', 'muje', 'unko', 'usko', 'inko',
    'bahut', 'bohot', 'bhut', 'jyada', 'zyada', 'thoda', 'thodi', 'sa',
    'si', 'lag', 'laga', 'lagta', 'lagti', 'lagi', 'karta', 'karti', 'kar',
    'din', 'dino', 'subah', 'sham', 'raat', 'patient', 'patients', 'said',
    'says', 'complains', 'complaint', 'of', 'in', 'my', 'his', 'her', 'a',
    'an', 'are', 'was', 'has', 'have', 'had', 'from', 'since', 'for',
    'with', 'feel', 'feels', 'feeling',
  };

  /// label → patterns. A pattern is one-or-more words; every word must be
  /// found in the dictation (any order). Keep every word already
  /// normalize-friendly (roman, lowercase) — Devanagari input arrives
  /// transliterated.
  static const Map<String, List<String>> _catalog = {
    'Fever': [
      'bukhar', 'bukhaar', 'bukhara', 'buhar', 'fever', 'jvar', 'jwar',
      'jwara', 'jvara', 'taap', 'tap tez', 'taap tez', 'temperature',
      'febrile', 'garmi lagti', 'garmi lagta', 'badan garam', 'jism garam',
      'tez bukhar', 'high fever', 'viral fever',
    ],
    'Chills': [
      'kapkapi', 'kapkapee', 'thand lagna', 'thandi lagna', 'thand lag',
      'thandi lag', 'chills', 'shivering', 'kanpkanpi', 'kaanpkanpi',
      'sardi lagna kapkapi', 'body chills',
    ],
    'Sweating': [
      'pasina', 'paseena', 'pasine', 'paseene', 'sweating', 'raat pasina',
      'thanda pasina', 'excessive sweating', 'bahut pasina',
    ],
    'Headache': [
      'sar dard', 'sir dard', 'sardard', 'sirdard', 'headache', 'head ache',
      'matha dard', 'mathe dard', 'sar bhari', 'sir bhari', 'sir bhaari',
      'migraine', 'adhkapari', 'sar fatna', 'sir fatna', 'sar fatta',
      'sar dukhta', 'sir dukhta',
    ],
    'Dizziness': [
      'chakkar', 'chakar', 'chakker', 'dizziness', 'dizzy', 'sir ghumna',
      'sar ghumna', 'sir ghoomna', 'ghumeri', 'ghoomeri', 'vertigo',
      'ankhon andhera', 'ankh andhera', 'andhera chhana', 'sir chakrana',
    ],
    'Body ache': [
      'badan dard', 'badan dukhna', 'sharir dard', 'sarir dard',
      'poora badan dard', 'sara badan dard', 'body pain', 'body ache',
      'bodyache', 'ang dard', 'haath pair dard', 'hath pair dard',
      'pura badan dard', 'muscle pain', 'muscles pain', 'maspeshi dard',
      'maspeshiyon dard',
    ],
    'Back pain': [
      // No 'peet dard' — loose() collapses 'peet' to 'pet' (= पेट,
      // stomach) so it fired Back pain on stomach-pain dictations
      // (user 2026-08-26).
      'pith dard', 'peeth dard', 'kamar dard', 'kamar dukhna',
      'back pain', 'backache', 'back ache', 'kamar akadna', 'reedh dard',
      'rid dard', 'lower back pain', 'upper back pain', 'kamar niche dard',
      'kamar bhari',
    ],
    'Neck pain': [
      'gardan dard', 'grdan dard', 'gardan dukhna', 'neck pain', 'neckache',
      'gardan akadna', 'gardan sakht', 'gardan bhari',
    ],
    'Joint Pain': [
      'jodo dard', 'jodon dard', 'jod dard', 'joint pain', 'joints pain',
      'joint ache', 'joints dard', 'jodo sujan dard', 'gathiya', 'arthritis',
      'jod akadna', 'jod sakht',
    ],
    'Knee pain': [
      'ghutne dard', 'ghutno dard', 'ghutna dard', 'ghootne dard',
      'knee pain', 'knees pain', 'knee ache', 'ghutna dukhna',
    ],
    'Leg pain': [
      // NOTE: no 'per dard' (user 2026-08-26 — 'per' is a stop word
      // meaning "on/at" in Hindi, so after stop-filtering the pattern
      // collapsed to just 'dard' and matched every mention of pain).
      'pair dard', 'pairo dard', 'pairon dard', 'pero dard', 'peron dard',
      'paon dard', 'paun dard', 'paav dard', 'leg pain',
      'legs pain', 'thigh pain', 'jangh dard', 'jaangh dard',
      'pindli dard', 'pair dukhna', 'pairo dukhna', 'pero dukhna',
      'pair mein dard', 'paron mein dard',
    ],
    'Hand pain': [
      // No 'bahu dard' — 'bahut' (much) contains 'bahu' (arm), so
      // "बहुत दर्द" fired Hand pain (user 2026-08-26).
      'hath dard', 'haath dard', 'hatho dard', 'haatho dard', 'hand pain',
      'hands pain', 'hath dukhna', 'baazu dard', 'arm pain',
      'kalai dard', 'kalayi dard', 'ungli dard',
    ],
    'Chest pain': [
      'sine dard', 'seene dard', 'chati dard', 'chhati dard', 'chest pain',
      'sine bhari', 'seene jakdan', 'chest jakdan',
    ],
    'Palpitations': [
      'dhadkan tez', 'dhadkan', 'palpitation', 'palpitations',
      'dil dhadakna', 'dil ghabrana',
    ],
    'Breathlessness': [
      'sans phulna', 'sans fulna', 'saans phulna', 'saans fulna',
      'sans dikkat', 'sans taklif', 'sans pareshani', 'sans lene dikkat',
      'sans lene taklif', 'sans chadhna', 'dam phulna', 'breathless',
      'breathlessness', 'shortness breath', 'breathing problem', 'dama',
      'sans ruk', 'sans ghutna', 'hanphna', 'hafna',
    ],
    'Cough': [
      'khansi', 'khasi', 'khansee', 'khaansi', 'khaansee', 'cough',
      'coughing', 'khokhi', 'khokhee', 'balgam', 'balgum', 'kaf', 'kapha',
      'sukhi khansi', 'sookhi khansi', 'khansi balgam', 'raat khansi',
      'gili khansi',
    ],
    'Runny nose': [
      'jukam', 'jukham', 'zukam', 'zukhaam', 'zukaam', 'sardi jukam',
      'nazla', 'nazla zukam', 'runny nose', 'nak behna', 'naak behna',
      'nak beh', 'nak band', 'naak band', 'blocked nose', 'common cold',
      'cold', 'sardi', 'sardee', 'chheenk', 'chink', 'chink aana',
      'sneezing', 'sneeze',
    ],
    'Sore throat': [
      'gala dard', 'gale dard', 'gale kharash', 'gala kharab',
      'gale kharab', 'sore throat', 'throat pain', 'gala baithna',
      'nigalne dard', 'gale sujan', 'tonsil',
    ],
    'Toothache': [
      'dant dard', 'daant dard', 'dat dard', 'danto dard', 'toothache',
      'tooth pain', 'masudo dard', 'masuda sujan',
    ],
    'Ear pain': [
      'kan dard', 'kaan dard', 'ear pain', 'earache', 'kan behna',
      'kan bhari', 'kan sunai kam',
    ],
    'Eye pain': [
      'ankh dard', 'aankh dard', 'ankho dard', 'eye pain', 'ankh jalan',
      'ankh lal', 'ankh pani', 'ankh dhundla', 'dhundla dikhna',
      'blurred vision',
    ],
    'Abdominal pain': [
      'pet dard', 'pait dard', 'stomach pain', 'stomach ache',
      'abdominal pain', 'pet marod', 'udar dard', 'pet ainthan',
      'pet niche dard',
    ],
    'Acidity': [
      'acidity', 'gas', 'gais', 'khatti dakar', 'pet jalan', 'sine jalan',
      'seene jalan', 'heartburn', 'pet phulna', 'bloating', 'afara',
    ],
    'Nausea': [
      'matli', 'michlana', 'jee michlana', 'ji michlana', 'ubkai',
      'ulti jaisa', 'nausea', 'jee ghabrana', 'ji ghabrana',
    ],
    'Vomiting': ['ulti', 'ultiya', 'vomiting', 'vomit', 'qai', 'ulti hui'],
    'Diarrhoea': [
      'dast', 'loose motion', 'loose motions', 'patla dast', 'patle dast',
      'diarrhoea', 'diarrhea', 'bar bar latrine', 'pani jaisa dast',
    ],
    'Constipation': [
      'kabj', 'kabz', 'constipation', 'pet saf nahi', 'latrine sakht',
      'sauch dikkat',
    ],
    'Piles': ['bawasir', 'bavasir', 'piles', 'khooni bawasir', 'latrine khoon'],
    'Loss of appetite': [
      'bhukh nahi', 'bhookh nahi', 'bhukh kam', 'appetite loss',
      'loss appetite', 'khana man nahi',
    ],
    'Weakness': [
      'kamjori', 'kamzori', 'kamjoree', 'kamzoree', 'weakness', 'weak',
      'taqat nahi', 'takat nahi', 'kamjor', 'kamzor', 'himmat nahi',
      'shakti nahi', 'urja nahi', 'jism kamjor',
    ],
    'Fatigue': [
      'thakan', 'thakaan', 'thakawat', 'thakavat', 'fatigue', 'fatigued',
      'tired', 'tiredness', 'exhausted', 'exhaustion', 'sust', 'susti',
      'sustee', 'alasya', 'alasy', 'jaldi thak', 'jaldi thakna',
      'thak jana', 'thak jaata',
    ],
    'Insomnia': [
      'nind nahi', 'neend nahi', 'nind kam', 'neend kam', 'insomnia',
      'sleepless', 'sleeplessness', 'so nahi pata', 'so nahi pati',
      'nind dikkat', 'neend dikkat', 'nind udna', 'neend udna',
      'nind kharab', 'neend kharab', 'nind na aana', 'neend na aana',
    ],
    'Anxiety': [
      'ghabrahat', 'ghabrahut', 'ghabraht', 'ghabraahat', 'ghabrahaat',
      'bechaini', 'bechainee', 'bechain', 'bechaen', 'bechaeni',
      'anxiety', 'anxious', 'ghabra', 'ghabrata', 'ghabrati', 'ghabrahna',
      'chinta', 'chintaa', 'chintit', 'tanaav', 'tanav', 'tension',
      'nervous', 'nervousness', 'panic', 'ghabraye', 'ghabraya',
      'man ghabrana', 'mann ghabrana', 'man bechain', 'dar lagna',
      'dar dar lagna',
    ],
    'Low mood': [
      'udas', 'udaas', 'udasi', 'udaasi', 'man udas', 'mann udas',
      'mun udas', 'low mood', 'depressed', 'depression', 'mann bhari',
      'man bhari', 'mun bhari', 'sad', 'sadness', 'niraash', 'nirash',
      'niraashaa', 'niraasha', 'nirasha', 'man nahi lagta',
      'mann nahi lagta', 'kuch achha nahi', 'ro dena', 'rona aata',
      'kisi kaam man nahi',
    ],
    'Itching': ['khujli', 'itching', 'khaj', 'kharish', 'khujlana'],
    'Skin rash': [
      'dane', 'daane', 'rash', 'rashes', 'chakatte', 'funsi', 'funsiyan',
      'skin dane', 'chamdi dane', 'pitti', 'chhale', 'allergy dane',
    ],
    'Swelling': [
      'sujan', 'sojan', 'soojan', 'swelling', 'pair sujan', 'pero sujan',
      'chehra sujan', 'hath sujan',
    ],
    'Numbness': [
      'sunn', 'sun ho jana', 'jhunjhuni', 'jhanjhanahat', 'numbness',
      'tingling', 'sui chubhna', 'hath pair sunn',
    ],
    'Burning urination': [
      'peshab jalan', 'pesab jalan', 'urine jalan', 'burning urine',
      'burning urination', 'mutra jalan', 'peshab dard',
    ],
    'Frequent urination': [
      'bar bar peshab', 'bar bar pesab', 'frequent urination',
      'peshab bar bar', 'raat peshab bar',
    ],
    'Jaundice': ['piliya', 'pilia', 'jaundice', 'ankh pili', 'peshab pila'],
    'Worms': ['pet kide', 'pet keede', 'worms', 'kide latrine'],
    'White discharge': [
      'safed pani', 'white discharge', 'safed pani jana',
    ],
    'Period pain': [
      'mahwari dard', 'mahavari dard', 'periods dard', 'period pain',
      'masik dard', 'dysmenorrhea',
    ],
    'Irregular periods': [
      'mahwari niyamit nahi', 'periods irregular', 'irregular periods',
      'mahwari der', 'periods late',
    ],
  };

  /// Consonant skeleton — first letter + consonants of the rest. Hinglish
  /// vowels are unreliable (peeth/pith, seene/sina, jukham/jukam); the
  /// consonant frame is what survives. Only used for words ≥4 chars whose
  /// frame is ≥3 chars, so tiny frames can't collide across words.
  static String _skel(String w) {
    if (w.length < 4) return '';
    final rest = w.substring(1).replaceAll(RegExp(r'[aeiou]'), '');
    final s = w[0] + rest;
    return s.length >= 3 ? s : '';
  }

  /// True when every word of [pws] appears in [textSeq] in order, with
  /// no more than [_maxGap] intervening words between CONSECUTIVE
  /// pattern words (the first word can start anywhere in the text —
  /// user 2026-08-26 fix: "पेट में दर्द" wasn't matching Abdominal
  /// pain because 'pet' sits 10 words into the dictation and the
  /// earlier search only scanned the first few words).
  static bool _sequenceHit(List<String> textSeq, List<String> pws) {
    for (var start = 0; start < textSeq.length; start++) {
      if (!_wordHit({textSeq[start]}, pws.first)) continue;
      var i = start + 1;
      var ok = true;
      for (var k = 1; k < pws.length; k++) {
        final maxIdx = (i + _maxGap).clamp(0, textSeq.length - 1);
        var found = -1;
        for (var j = i; j <= maxIdx && j < textSeq.length; j++) {
          if (_wordHit({textSeq[j]}, pws[k])) { found = j; break; }
        }
        if (found < 0) { ok = false; break; }
        i = found + 1;
      }
      if (ok) return true;
    }
    return false;
  }

  static bool _wordHit(Set<String> textWords, String pw) {
    final pSkel = _skel(pw);
    for (final w in textWords) {
      if (w == pw) return true;
      if (pw.length >= 4 && w.contains(pw)) return true; // sardard ⊃ dard
      // Pattern-contains-word: allow ONLY when the word is close to the
      // pattern's full length (user 2026-08-26: leg-pain observation
      // "दर्द" was triggering Headache because pattern "sardard" (7)
      // contains generic "dard" (4)). Reserving this branch for near-
      // full-length variants — e.g. "bukhar" (6) ⇒ "bukhaar" (7).
      if (w.length >= 4 && pw.length >= 4 && pw.contains(w) &&
          w.length >= pw.length - 2) return true;
      if (pSkel.isNotEmpty && pSkel == _skel(w)) return true;
    }
    return false;
  }

  /// Content words of [text] (normalized, loose, stop-words dropped) —
  /// public so the sheet-synonym pass can run the SAME whole-phrase test.
  static Set<String> wordsOf(String text) {
    final words = <String>{};
    for (final raw in TerminologyStore.normalize(text).split(RegExp(r'\s+'))) {
      final w = TerminologyStore.loose(raw.trim());
      if (w.length < 2 || _stop.contains(w)) continue;
      words.add(w);
    }
    return words;
  }

  /// True when EVERY content word of [phrase] appears in [textWords] —
  /// a single shared word ("dard") is NOT a hit (user 2026-08-22:
  /// "हाथ में दर्द" was lighting up Headache + Abdominal pain).
  static bool phraseHit(Set<String> textWords, String phrase) {
    final pws = [
      for (final pw in phrase.split(RegExp(r'\s+')))
        if (pw.trim().isNotEmpty) TerminologyStore.loose(
            TerminologyStore.normalize(pw.trim())),
    ]..removeWhere((w) => w.length < 2 || _stop.contains(w));
    if (pws.isEmpty) return false;
    return pws.every((pw) => _wordHit(textWords, pw));
  }

  /// Every catalogue label whose pattern words appear IN ORDER with a
  /// short gap in the dictated text (user 2026-08-26 — the earlier
  /// "any order, any distance" rule was combining a sentence-opening
  /// honorific "सर, ..." (Sir) with a later "दर्द" to fire Headache;
  /// a fully-contiguous rule then rejected legitimate "पेट में दर्द"
  /// because "में" sits between "पेट" and "दर्द"). We now allow up to
  /// _MAX_GAP filler words between each pair of pattern words while
  /// requiring the pattern order.
  static const int _maxGap = 3;
  static List<String> match(String text) {
    final words = wordsOf(text);
    if (words.isEmpty) return const [];
    final normText = TerminologyStore.loose(TerminologyStore.normalize(text));
    // Positions of every word in the normalized text (space-split, no
    // stop-filter — gap counts real filler words too).
    final textSeq = normText.split(' ');
    final out = <String>[];
    _catalog.forEach((label, patterns) {
      for (final p in patterns) {
        final pws = [
          for (final pw in p.split(' '))
            if (pw.trim().isNotEmpty) TerminologyStore.loose(pw.trim()),
        ]..removeWhere(_stop.contains);
        if (pws.isEmpty) continue;
        bool hit;
        if (pws.length == 1) {
          hit = _wordHit(words, pws.first);
        } else {
          hit = _sequenceHit(textSeq, pws);
        }
        if (hit) {
          out.add(label);
          break;
        }
      }
    });
    return out;
  }
}
