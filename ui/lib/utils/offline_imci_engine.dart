import '../models/child_model.dart';
import '../models/assessment_model.dart';
import '../models/evidence_model.dart';

class OfflineImciEngine {
  static (int days, double months)? extractAgeFromQuery(String query) {
    final q = query.toLowerCase();

    // Pattern: X weeks / X-week / X-week-old
    final wMatch = RegExp(r'(\d+)\s*(?:-|\s*)week(?:s)?(?:\s*-?\s*old)?').firstMatch(q);
    if (wMatch != null) {
      final weeks = int.parse(wMatch.group(1)!);
      final days = weeks * 7;
      return (days, days / 30.417);
    }

    // Pattern: X days / X-day-old
    final dMatch = RegExp(r'(\d+)\s*(?:-|\s*)day(?:s)?(?:\s*-?\s*old)?').firstMatch(q);
    if (dMatch != null) {
      final days = int.parse(dMatch.group(1)!);
      return (days, days / 30.417);
    }

    // Pattern: X months / X-month-old
    final mMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:-|\s*)month(?:s)?(?:\s*-?\s*old)?').firstMatch(q);
    if (mMatch != null) {
      final months = double.parse(mMatch.group(1)!);
      final days = (months * 30.417).toInt();
      return (days, months);
    }

    // Pattern: X years / X-year-old
    final yMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:-|\s*)year(?:s)?(?:\s*-?\s*old)?').firstMatch(q);
    if (yMatch != null) {
      final years = double.parse(yMatch.group(1)!);
      final months = years * 12.0;
      final days = (years * 365.25).toInt();
      return (days, months);
    }

    // Arabic Patterns:
    final arW = RegExp(r'عمر(?:ه|ها)?\s*(\d+)\s*(?:أسبوع|اسبوع|أسابيع|اسابيع)').firstMatch(q);
    if (arW != null) {
      final weeks = int.parse(arW.group(1)!);
      final days = weeks * 7;
      return (days, days / 30.417);
    }

    final arD = RegExp(r'عمر(?:ه|ها)?\s*(\d+)\s*(?:يوم|ايام|أيام)').firstMatch(q);
    if (arD != null) {
      final days = int.parse(arD.group(1)!);
      return (days, days / 30.417);
    }

    final arM = RegExp(r'عمر(?:ه|ها)?\s*(\d+(?:\.\d+)?)\s*(?:شهر|شهور|أشهر|اشهر)').firstMatch(q);
    if (arM != null) {
      final months = double.parse(arM.group(1)!);
      final days = (months * 30.417).toInt();
      return (days, months);
    }

    final arY = RegExp(r'عمر(?:ه|ها)?\s*(\d+(?:\.\d+)?)\s*(?:سنة|سنوات|عام|أعوام)').firstMatch(q);
    if (arY != null) {
      final years = double.parse(arY.group(1)!);
      final months = years * 12.0;
      final days = (years * 365.25).toInt();
      return (days, months);
    }

    // Generic keywords
    if (q.contains('young infant') || q.contains('حديث ولادة') || q.contains('رضيع صغير')) {
      return (21, 0.7); // default 3 weeks
    }

    return null;
  }

  static AssessmentResponseModel evaluateLocally({
    required String query,
    required ChildModel child,
    Map<String, bool> verificationAnswers = const {},
  }) {
    final queryLower = query.toLowerCase();
    
    // Dynamic Language Detection:
    // If query has Latin letters, mirror in English. If only Arabic, mirror in Arabic.
    final hasEnglish = RegExp(r'[a-zA-Z]').hasMatch(query);
    final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(query);
    final isEnglish = hasEnglish && !hasArabic;

    // Dynamic Age Extraction & Override:
    int effectiveAgeDays = child.ageInDays;
    double effectiveAgeMonths = child.ageInMonths;
    final extractedAge = extractAgeFromQuery(query);
    if (extractedAge != null) {
      effectiveAgeDays = extractedAge.$1;
      effectiveAgeMonths = extractedAge.$2;
    }

    // --- 1. OUT-OF-DISTRIBUTION (OOD) & ADULT EXCLUSION GUARDRAIL ---
    final isAdultOrOod = queryLower.contains('بالغين') ||
        queryLower.contains('بالغ') ||
        queryLower.contains('كبار السن') ||
        queryLower.contains('شريان تاجي') ||
        queryLower.contains('ذبحة صدرية') ||
        queryLower.contains('أزمة قلبية') ||
        queryLower.contains('جلطة') ||
        queryLower.contains('نيتروجليسرين') ||
        queryLower.contains('فياجرا') ||
        queryLower.contains('رجيم') ||
        queryLower.contains('ميتفورمين') ||
        queryLower.contains('أنسولين للبالغين') ||
        queryLower.contains('adult') ||
        queryLower.contains('adults') ||
        queryLower.contains('elderly') ||
        queryLower.contains('coronary') ||
        queryLower.contains('nitroglycerin') ||
        queryLower.contains('myocardial infarction') ||
        queryLower.contains('stroke') ||
        queryLower.contains('metformin') ||
        queryLower.contains('viagra');

    if (isAdultOrOod) {
      return AssessmentResponseModel(
        id: 'ood_refusal_${DateTime.now().millisecondsSinceEpoch}',
        status: 'refusal',
        triageLevel: 'REFUSAL',
        triageLabelAr: '⚠️ خارج نطاق طب الأطفال (طلب استشارة طبيب بالغين) 🛡️',
        triageLabelEn: '⚠️ OUT OF DOMAIN - ADULT CARE CONSULTATION REQUIRED 🛡️',
        fullRecommendation: isEnglish
            ? '🛡️ [Out of Domain Guardrail Rejection] This query pertains to adult medicine or non-pediatric conditions. PediaCare.AI strictly handles pediatric clinical decision support for children (7 days to 5 years). Please consult an adult healthcare specialist.'
            : '🛡️ [رفض أمان سريري - خارج النطاق المصرح به] الاستفسار يتعلق بأمراض البالغين أو أدوية غير خاصة بالأطفال دون سن 5 سنوات. نظام PediaCare.AI مخصص حصرياً لطب الأطفال وحديثي الولادة (WHO IMCI من عمر 7 أيام حتى 5 سنوات). نوصي بمراجعة طبيب متخصص في طب البالغين.',
        summaryFound: isEnglish
            ? ['Adult or non-pediatric query terms detected']
            : ['تم رصد مصطلحات تتعلق بأمراض أو أدوية البالغين'],
        missingInfo: [],
        differentialDiagnoses: isEnglish
            ? [DifferentialDiagnosis(name: 'Out of Domain (Adult Medicine)', probability: 100)]
            : [DifferentialDiagnosis(name: 'خارج نطاق التغطية (طب البالغين)', probability: 100)],
        evidenceList: [
          EvidenceModel(
            documentName: 'WHO IMCI Boundary Policy',
            sectionTitle: 'Pediatric Clinical Boundary & Age Limitations (7 days to 5.0 years)',
            page: 1,
            relevanceScore: 100.0,
            highlightTextEn: 'The WHO IMCI Model Handbook is strictly applicable for sick young infants (7 days to 2 months) and sick children (2 months to 5 years). Adult conditions and adult pharmacology are strictly out of scope.',
            highlightTextAr: 'دليل منظمة الصحة العالمية لتدبير أمراض الطفولة مخصص حصرياً للأطفال دون سن 5 سنوات. أدوية وأمراض البالغين خارج نطاق التغطية تماماً.',
            triageColor: 'GRAY',
          )
        ],
        detectedLanguage: isEnglish ? 'en' : 'ar',
      );
    }

    // --- 2. STRICT PEDIATRIC SYMPTOM GATEKEEPER ---
    final List<String> pediatricSymptomKeywords = [
      'كحة', 'سعال', 'تنفس', 'صدر', 'نهجان', 'خنقة', 'صرير', 'حرارة', 'سخونية', 'حمى', 'سخونة',
      'إسهال', 'اسهال', 'ترجيع', 'قيء', 'استفراغ', 'جفاف', 'تشنج', 'تشنجات', 'خمول', 'غيبوبة',
      'أذن', 'ودن', 'صديد', 'طفح', 'حبوب', 'وزن', 'رضاعة', 'شرب', 'بلغم', 'مخاط', 'هزال', 'عين', 'عيون',
      'cough', 'breathing', 'fever', 'diarrhea', 'diarrhoea', 'vomit', 'convulsion', 'lethargic', 'ear', 'rash',
      'stool', 'blood', 'dehydration', 'pneumonia', 'dysentery', 'malnutrition', 'hypothermia', 'grunting', 'sick', 'ill'
    ];

    final List<RegExp> nonMedicalPatterns = [
      RegExp(r'لبس|فستان|قميص|بنطلون|شياكة|رايك|شكلي|طقس|جو|أخبار|كورة|ماتش|أغنية|فيلم|مطعم|أكل|طبخ', caseSensitive: false),
      RegExp(r'weather|outfit|clothes|football|joke|who are you|hello|hi\b|movie|song|food', caseSensitive: false),
    ];

    bool isNonMedical = nonMedicalPatterns.any((p) => p.hasMatch(query));
    bool hasClinicalSymptom = pediatricSymptomKeywords.any((k) => queryLower.contains(k));

    if (isNonMedical || !hasClinicalSymptom) {
      return AssessmentResponseModel(
        id: 'non_clinical_${DateTime.now().millisecondsSinceEpoch}',
        status: 'NON_CLINICAL_QUERY',
        triageLevel: 'GRAY',
        triageLabelAr: 'خارج النطاق الطبي 🛡️',
        triageLabelEn: 'NON-CLINICAL QUERY 🛡️',
        fullRecommendation: isEnglish
            ? 'This query is non-clinical. PediaCare.AI strictly evaluates pediatric illness symptoms (0-5 years) under WHO IMCI guidelines. Please describe the child\'s medical symptoms.'
            : 'عذراً، هذا الاستفسار غير طبي. نظام PediaCare.AI مخصص حصراً لتقييم الأعراض المرضية للأطفال دون سن 5 سنوات وفق دليل منظمة الصحة العالمية (WHO IMCI). يرجى وصف أعراض الطفل المرضية (مثل: كحة، حرارة، إسهال).',
        summaryFound: isEnglish
            ? ['Non-medical query / Absence of pediatric clinical symptoms']
            : ['استفسار غير طبي / غياب الأعراض السريرية للأطفال'],
        missingInfo: isEnglish
            ? ['Please enter real pediatric medical symptoms (e.g. cough, fever, diarrhea)']
            : ['أدخل شكوى مرضية حقيقية للطفل (مثل: كحة، حرارة، إسهال)'],
        differentialDiagnoses: isEnglish
            ? [DifferentialDiagnosis(name: 'Non-Clinical Query', probability: 100)]
            : [DifferentialDiagnosis(name: 'استفسار غير طبي', probability: 100)],
        evidenceList: [],
        detectedLanguage: isEnglish ? 'en' : 'ar',
      );
    }

    final isYoungInfant = effectiveAgeDays < 60; // < 2 months

    // Helper: Negation-aware symptom detection
    bool checkSymptomWithNegation(List<String> keywords, {bool? explicitAnswer}) {
      if (explicitAnswer != null) return explicitAnswer;
      for (final kw in keywords) {
        if (queryLower.contains(kw)) {
          // Check for negation prefixes/suffixes in proximity
          final negReg = RegExp(
            r'(?:لا يوجد|مفيش|بدون|ليس لديه|لا يعاني من|مافيش|غير مصاب|سليم من|طبيعي|لا تظهر|no\b|not\b|without|free of)\s*(?:اي|أي|علامات|أعراض)?\s*' +
                RegExp.escape(kw),
            caseSensitive: false,
          );
          if (!negReg.hasMatch(queryLower)) {
            return true;
          }
        }
      }
      return false;
    }

    // --- EXTRACT AFFIRMATIVE SYMPTOMS WITH NEGATION AWARENESS ---
    bool hasVomitingAll = checkSymptomWithNegation(
      ['يتقيأ كل شيء', 'ترجيع مستمر', 'vomits everything', 'vomiting everything'],
      explicitAnswer: verificationAnswers['هل يتقيأ الطفل كل شيء؟'] ?? verificationAnswers['Is the child vomiting everything?'],
    );

    bool hasConvulsions = checkSymptomWithNegation(
      ['تشنج', 'صرع', 'convulsion', 'seizure', 'fits'],
      explicitAnswer: verificationAnswers['هل يعاني الطفل من تشنجات حالية أو سابقة خلال هذا المرض؟'] ?? verificationAnswers['Does the child have convulsions or seizures?'],
    );

    bool notAbleToDrink = checkSymptomWithNegation(
      ['غير قادر على الشرب', 'غير قادر على الرضاعة', 'لا يستطيع الشرب', 'not able to drink', 'not able to breastfeed', 'unable to feed'],
      explicitAnswer: verificationAnswers['هل الطفل غير قادر على الشرب أو الرضاعة؟'] ?? verificationAnswers['Is the child unable to drink or breastfeed?'],
    );

    bool isLethargic = checkSymptomWithNegation(
      ['خامل', 'فاقد للوعي', 'غائب عن الوعي', 'غيبوبة', 'lethargic', 'unconscious', 'floppy'],
      explicitAnswer: verificationAnswers['هل يبدو الطفل خاملاً بشكل غير طبيعي أو فاقداً للوعي؟'] ?? verificationAnswers['Is the child abnormally lethargic or unconscious?'],
    );

    bool hasChestIndrawing = checkSymptomWithNegation(
      ['انسحاب جدار الصدر', 'انسحاب أسفل جدار الصدر', 'سحب الصدر', 'سحب للصدر', 'سحب بالصدر', 'انسحاب للصدر', 'انسحاب الصدر', 'chest indrawing', 'subcostal retraction', 'intercostal retraction'],
      explicitAnswer: verificationAnswers['هل يوجد انسحاب لأسفل جدار الصدر للداخل عند التنفس؟'] ?? verificationAnswers['Is there lower chest wall indrawing?'],
    );

    bool hasStridor = checkSymptomWithNegation(
      ['صرير', 'stridor'],
      explicitAnswer: verificationAnswers['هل يوجد صوت صرير (Stridor) والطفل هادئ تماماً؟'] ?? verificationAnswers['Is there stridor in a calm child?'],
    );

    bool hasGrunting = checkSymptomWithNegation(
      ['grunting', 'expiratory grunting', 'شخير عند الزفير', 'أنين عند الزفير', 'طنين بالزفير'],
      explicitAnswer: verificationAnswers['هل يوجد شخير أو أنين عند الزفير؟'] ?? verificationAnswers['Is there expiratory grunting?'],
    );

    bool hasHypothermia = checkSymptomWithNegation(
      ['hypothermia', 'انخفاض حرارة', 'أقل من 35', 'برودة شديدة'],
      explicitAnswer: verificationAnswers['هل درجة حرارة الإبط أقل من 35.5°C؟'] ?? verificationAnswers['Is axillary temperature below 35.5°C?'],
    );

    bool hasStiffNeck = checkSymptomWithNegation(
      ['تيبس الرقبة', 'تصلب الرقبة', 'تيبس بالرقبة', 'stiff neck'],
      explicitAnswer: verificationAnswers['هل يوجد تيبس أو مقاومة عند ثني رقبة الطفل للأمام؟'] ?? verificationAnswers['Is there a stiff neck?'],
    );

    bool hasMastoid = checkSymptomWithNegation(
      ['خلف الأذن', 'عظمة الخشاء', 'الخشاء', 'mastoid', 'tender swelling behind ear'],
      explicitAnswer: verificationAnswers['هل يوجد تورم مؤلم خلف الأذن فوق عظمة الخشاء؟'],
    );

    bool hasSevereWasting = checkSymptomWithNegation(
      ['هزال شديد', 'جلد على عظم', 'تورم بالقدمين', 'تورم في القدمين', 'وذمة بالقدمين', 'severe wasting', 'oedema of both feet', 'marasmus', 'kwashiorkor'],
      explicitAnswer: verificationAnswers['هل يعاني الطفل من هزال شديد واضح أو تورم بالقدمين؟'],
    );

    bool hasBloodInStool = checkSymptomWithNegation(
      ['دم في البراز', 'دم بالبراز', 'براز مدمم', 'blood in stool', 'bloody stool', 'dysentery'],
    );

    bool hasSunkenEyes = checkSymptomWithNegation(
      ['عيون غائرة', 'عين غائرة', 'عينان غائرتان', 'sunken eyes'],
      explicitAnswer: verificationAnswers['هل عيون الطفل غائرة بشكل ملحوظ؟'] ?? verificationAnswers['Are the eyes sunken?'],
    );

    bool hasSkinPinchVerySlow = checkSymptomWithNegation(
      ['ببطء شديد', 'أكثر من ثانيتين', 'skin pinch goes back very slowly', '> 2 seconds'],
      explicitAnswer: verificationAnswers['هل ترجع ثنية جلد البطن ببطء شديد (> ثانيتين)؟'] ?? verificationAnswers['Does skin pinch go back very slowly (>2s)?'],
    );

    bool hasSkinPinchSlow = checkSymptomWithNegation(
      ['ببطء', 'skin pinch goes back slowly'],
      explicitAnswer: verificationAnswers['هل ترجع ثنية الجلد ببطء؟'],
    );

    bool hasEarPainOrDischarge = checkSymptomWithNegation(
      ['ألم بالأذن', 'ألم في الأذن', 'وجع في الأذن', 'صديد من الأذن', 'إفرازات من الأذن', 'ear pain', 'ear discharge'],
    );

    bool hasDiarrhea = checkSymptomWithNegation(
      ['إسهال', 'اسهال', 'diarrhea', 'diarrhoea', 'loose stools'],
    );

    bool hasFever = checkSymptomWithNegation(
      ['حرارة', 'سخونية', 'حمى', 'سخونة', 'fever', 'febrile', 'hot'],
    );

    bool hasCough = checkSymptomWithNegation(
      ['كحة', 'سعال', 'cough'],
    );

    // Respiration rate parsing
    int? detectedBpm;
    final bpmMatch = RegExp(r'(\d{2,3})\s*(?:نفس|breath|breaths|bpm|/min)').firstMatch(queryLower);
    if (bpmMatch != null) {
      detectedBpm = int.tryParse(bpmMatch.group(1)!);
    }

    bool isFastBreathing = false;
    if (detectedBpm != null) {
      if (isYoungInfant) {
        isFastBreathing = detectedBpm >= 60;
      } else if (effectiveAgeMonths < 12) {
        isFastBreathing = detectedBpm >= 50;
      } else {
        isFastBreathing = detectedBpm >= 40;
      }
    } else if (checkSymptomWithNegation(['تنفس سريع', 'نهجان سريع', 'fast breathing', 'rapid breathing'])) {
      isFastBreathing = true;
    }

    // General Danger Signs (🔴 RED)
    final hasGeneralDangerSign = hasVomitingAll || hasConvulsions || notAbleToDrink || isLethargic;

    // --- DECISION TREE LOGIC ---
    String triage = 'GREEN';
    String labelAr = 'رعاية منزلية آمنة 🟢';
    String labelEn = 'SAFE HOME CARE 🟢';
    String recAr = '';
    String recEn = '';
    List<String> summary = [];
    List<String> missing = [];
    List<EvidenceModel> evidence = [];
    List<DifferentialDiagnosis> diffs = [];

    if (isYoungInfant) {
      // SICK YOUNG INFANT TRACK (7 Days to 2 Months / < 60 Days)
      final hasPsbiSign = hasGeneralDangerSign ||
          hasChestIndrawing ||
          isFastBreathing ||
          hasGrunting ||
          hasHypothermia ||
          hasConvulsions ||
          (detectedBpm != null && detectedBpm >= 60);

      if (hasPsbiSign) {
        triage = 'RED';
        labelAr = 'خطر عاجل - احتمال عدوى بكتيرية وخيمة (PSBI) 🔴';
        labelEn = 'EMERGENCY - POSSIBLE SERIOUS BACTERIAL INFECTION (PSBI) 🔴';
        recAr =
            'تصنيف الرضيع الصغير (أقل من شهرين): احتمال عدوى بكتيرية وخيمة (Possible Serious Bacterial Infection - PSBI). '
            'العلاج التحويلي العاجل: إعطاء الجرعة الأولى من المضادات الحيوية بالحقن العضلي فوراً (أمبيسيلين 50 مجم/كجم عضل + جنتاميسين 5 مجم/كجم عضل). '
            'تدفئة الرضيع بالملامسة الجلدية (Skin-to-skin) أو باللف الجيد، وإعطاء حليب الثدي المسحوب أو ماء السكر لمنع هبوط السكر أثناء النقل، والتحويل العاجل للمستشفى. '
            '⚠️ يمنع تماماً إعطاء مضادات حيوية فموية مثل الأموكسيسيلين للرضع الصغار المصابين بعدوى بكتيرية وخيمة. [WHO IMCI Model Handbook, Section: Sick Young Infant, Page 62–64]';
        recEn =
            'Young Infant Classification (< 2 months): POSSIBLE SERIOUS BACTERIAL INFECTION (PSBI). '
            'Urgent Pre-referral Treatment: Give first dose of intramuscular Ampicillin (50 mg/kg IM) + Gentamicin (5 mg/kg IM). '
            'Keep the infant warm (skin-to-skin contact / wrapping), prevent low blood sugar by giving expressed breast milk or sugar water, and REFER URGENTLY to hospital. '
            '⚠️ Oral antibiotics (such as oral Amoxicillin) are strictly prohibited for young infants with PSBI signs. [WHO IMCI Model Handbook, Section: Sick Young Infant, Page 62–64]';

        diffs = isEnglish
            ? [
                DifferentialDiagnosis(name: 'Possible Serious Bacterial Infection (Neonatal Sepsis)', probability: 85),
                DifferentialDiagnosis(name: 'Neonatal Pneumonia', probability: 10),
                DifferentialDiagnosis(name: 'Neonatal Meningitis', probability: 5),
              ]
            : [
                DifferentialDiagnosis(name: 'عدوى بكتيرية وخيمة (إنتان وليدي / PSBI)', probability: 85),
                DifferentialDiagnosis(name: 'التهاب رئوي وليدي', probability: 10),
                DifferentialDiagnosis(name: 'التهاب سحايا وليدي', probability: 5),
              ];

        evidence.addAll([
          EvidenceModel(
            documentName: 'WHO IMCI Model Handbook',
            sectionTitle: 'Sick Young Infant (1 week–2m) > POSSIBLE SERIOUS BACTERIAL INFECTION',
            page: 62,
            relevanceScore: 97.0,
            highlightTextEn:
                'A young infant (age 1 week up to 2 months) with any of the following signs: fast breathing (>= 60 breaths/min), hypothermia (axillary temperature < 35.5°C) or fever (>= 37.5°C), severe chest indrawing, expiratory grunting, convulsions, or lethargy is classified as POSSIBLE SERIOUS BACTERIAL INFECTION. Pre-referral treatment: Give the first dose of intramuscular Ampicillin (50 mg/kg) and intramuscular Gentamicin (5 mg/kg). Treat to prevent low blood sugar with expressed breast milk or sugar water. Advise mother how to keep the young infant warm (skin-to-skin or wrapping) on the way to hospital, and REFER URGENTLY to hospital.',
            highlightTextAr:
                'الرضيع الصغير (من عمر أسبوع حتى شهرين) الذي تظهر عليه أي من العلامات التالية: تنفس سريع (≥ 60 نفس/دقيقة)، انخفاض حرارة الجسم (< 35.5°C) أو حمى (≥ 37.5°C)، انسحاب شديد للصدر، شخير عند الزفير، تشنجات، أو خمول غير طبيعي يصنف كاحتمال عدوى بكتيرية وخيمة. العلاج التحويلي العاجل: إعطاء الجرعة الأولى من الأمبيسيلين (50 مجم/كجم) والجنتاميسين (5 مجم/كجم) بالحقن العضلي. منع هبوط السكر بحليب الثدي أو ماء السكر، وتدفئة الرضيع بالملامسة الجلدية أثناء النقل، والإحالة الفورية للمستشفى.',
            triageColor: 'RED',
          ),
          EvidenceModel(
            documentName: 'WHO IMCI Model Handbook',
            sectionTitle: 'Sick Young Infant (1 week–2m) > ESSENTIAL PRE-REFERRAL INJECTABLE ANTIBIOTICS',
            page: 64,
            relevanceScore: 94.5,
            highlightTextEn:
                'For severe bacterial infection in young infants: Give first dose of Ampicillin 50 mg/kg IM and Gentamicin 5 mg/kg IM. Oral antibiotics like amoxicillin are strictly contraindicated.',
            highlightTextAr:
                'لعلاج العدوى البكتيرية الوخيمة لدى الرضع الصغار: أعط الجرعة الأولى من الأمبيسيلين 50 مجم/كجم عضل والجنتاميسين 5 مجم/كجم عضل. يمنع تماماً استخدام المضادات الحيوية الفموية كالأموكسيسيلين.',
            triageColor: 'RED',
          ),
          EvidenceModel(
            documentName: 'WHO IMCI Model Handbook',
            sectionTitle: 'Sick Young Infant (1 week–2m) > THERMAL CARE & HYPOGLYCEMIA PREVENTION',
            page: 61,
            relevanceScore: 92.0,
            highlightTextEn:
                'Keep the young infant warm using skin-to-skin contact (Kangaroo Mother Care) or warm swaddling. Give expressed breast milk or sugar water to prevent dangerous hypoglycemia.',
            highlightTextAr:
                'الحفاظ على تدفئة الرضيع بالملامسة الجلدية المباشرة (رعاية الكنغر) أو التقميط الجيد. إعطاء حليب الثدي المسحوب أو محلول السكر لتجنب هبوط سكر الدم أثناء النقل.',
            triageColor: 'RED',
          ),
          EvidenceModel(
            documentName: 'WHO IMCI Model Handbook',
            sectionTitle: 'Sick Young Infant (1 week–2m) > EMERGENCY HOSPITAL REFERRAL PROTOCOL',
            page: 86,
            relevanceScore: 90.0,
            highlightTextEn:
                'Urgently refer the young infant to hospital with neonatal intensive care or paediatric inpatient facilities. Explain to the mother the need for urgent referral and arrange transport.',
            highlightTextAr:
                'إحالة الرضيع الصغير فوراً إلى مستشفى مجهز برعاية مركزة لحديثي الولادة. شرح ضرورة الإحالة العاجلة للأم وتأمين وسيلة نقل دافئة وآمنة.',
            triageColor: 'RED',
          ),
        ]);

        if (isEnglish) {
          if (detectedBpm != null) summary.add('Breathing rate: $detectedBpm breaths/min (>= 60 bpm)');
          if (hasHypothermia) summary.add('Hypothermia / Low temperature (< 35.5°C)');
          if (hasGrunting) summary.add('Expiratory grunting');
          if (hasChestIndrawing) summary.add('Severe chest indrawing');
          if (hasConvulsions) summary.add('Convulsions or seizures');
          if (notAbleToDrink) summary.add('Unable to breastfeed or drink');
          if (isLethargic) summary.add('Abnormally lethargic or floppy');
          if (summary.isEmpty) summary.add('Age: $effectiveAgeDays days (Young Infant PSBI signs present)');
        } else {
          if (detectedBpm != null) summary.add('معدل التنفس: $detectedBpm نفس/دقيقة (≥ 60)');
          if (hasHypothermia) summary.add('انخفاض في درجة الحرارة (< 35.5°C)');
          if (hasGrunting) summary.add('شخير أو أنين عند الزفير (Grunting)');
          if (hasChestIndrawing) summary.add('انسحاب أسفل جدار الصدر للداخل');
          if (hasConvulsions) summary.add('تشنجات سابقة أو حالية');
          if (notAbleToDrink) summary.add('غير قادر على الرضاعة أو الشرب');
          if (isLethargic) summary.add('خمول شديد أو فقدان وعي');
          if (summary.isEmpty) summary.add('عمر الرضيع: $effectiveAgeDays يوماً (علامات عدوى بكتيرية وخيمة)');
        }
      } else {
        triage = 'GREEN';
        labelAr = 'رضاعة طبيعية ورعاية داعمة 🟢';
        labelEn = 'NORMAL / COUNSEL ON BREASTFEEDING 🟢';
        recAr =
            'تصنيف الرضيع: لا توجد علامات عدوى بكتيرية وخيمة. نصح الأم بالعلامات الأربع للالتصاق الصحيح بالثدي وتدفئة الرضيع في المنزل. [WHO IMCI Model Handbook, Young Infant Attachment, Page 68]';
        recEn =
            'Young Infant Classification: NO SIGNS OF SERIOUS BACTERIAL INFECTION. Counsel mother on 4 signs of good attachment and home warmth. [WHO IMCI Model Handbook, Young Infant Attachment, Page 68]';
        diffs = isEnglish
            ? [DifferentialDiagnosis(name: 'Healthy Young Infant / Normal Feeding', probability: 95)]
            : [DifferentialDiagnosis(name: 'رضيع سليم / تغذية طبيعية', probability: 95)];
        summary = isEnglish ? ['Normal breathing rate', 'Normal temperature'] : ['تنفس طبيعي', 'حرارة طبيعية'];
        evidence.addAll([
          EvidenceModel(
            documentName: 'WHO IMCI Model Handbook',
            sectionTitle: 'Sick Young Infant (1 week–2m) > ESSENTIAL CARE & BREASTFEEDING',
            page: 68,
            relevanceScore: 94.0,
            highlightTextEn:
                'A young infant with no danger signs and good feeding should receive essential newborn care, exclusive breastfeeding support, and thermal protection at home.',
            highlightTextAr:
                'الرضيع الصغير الذي لا يعاني من علامات خطورة ولديه رضاعة جيدة يتلقى الرعاية الأساسية والدعم للرضاعة الطبيعية المطلقة والتدفئة المنزلية.',
            triageColor: 'GREEN',
          ),
          EvidenceModel(
            documentName: 'WHO IMCI Model Handbook',
            sectionTitle: 'Sick Young Infant (1 week–2m) > FOUR SIGNS OF GOOD ATTACHMENT',
            page: 69,
            relevanceScore: 91.5,
            highlightTextEn:
                'Teach the mother the 4 signs of good attachment: chin touching breast, mouth wide open, lower lip turned outward, more areola above mouth than below.',
            highlightTextAr:
                'تعليم الأم العلامات الأربع للالتصاق الجيد: ملامسة الذقن للثدي، الفم مفتوح باتساع، الشفة السفلية مقلوبة للخارج، ظهور هالة الثدي فوق الفم أكثر من تحته.',
            triageColor: 'GREEN',
          ),
          EvidenceModel(
            documentName: 'WHO IMCI Model Handbook',
            sectionTitle: 'Sick Young Infant (1 week–2m) > THERMAL PROTECTION AT HOME',
            page: 70,
            relevanceScore: 89.0,
            highlightTextEn:
                'Keep the young infant warm at home. Dress the baby in warm clothes including cap and socks. Avoid bathing the infant in cold water.',
            highlightTextAr:
                'تدفئة الرضيع في المنزل بارتداء ملابس كافية وقبعة وجوارب وتجنب استحمام الرضيع بالماء البارد.',
            triageColor: 'GREEN',
          ),
          EvidenceModel(
            documentName: 'WHO IMCI Model Handbook',
            sectionTitle: 'Sick Young Infant (1 week–2m) > DANGER SIGNS FOR IMMEDIATE RETURN',
            page: 72,
            relevanceScore: 87.0,
            highlightTextEn:
                'Advise mother to return immediately if the infant develops fast breathing, difficulty feeding, becomes cold or unusually hot, or becomes lethargic.',
            highlightTextAr:
                'تنبيه الأم بضرورة العودة الفورية للمركز الصحي إذا تسارع التنفس، أو ضعف الرضاعة، أو بردت الأطراف، أو حدث خمول غير طبيعي.',
            triageColor: 'GREEN',
          ),
        ]);
      }
    } else {
      // CHILD TRACK (2 Months to 5 Years)
      if (hasGeneralDangerSign || hasChestIndrawing || hasStridor || hasStiffNeck || hasMastoid || hasSevereWasting || (hasSunkenEyes && hasSkinPinchVerySlow)) {
        triage = 'RED';
        if (hasChestIndrawing || hasStridor) {
          labelAr = 'خطر عاجل - التهاب رئوي وخيم 🔴';
          labelEn = 'EMERGENCY - SEVERE PNEUMONIA 🔴';
          recAr =
              'تصنيف الحالة: التهاب رئوي وخيم أو مرض وخيم جداً (Severe Pneumonia or Very Severe Disease). يلزم إعطاء الجرعة الأولى من المضاد الحيوي المناسب والتحويل العاجل للمستشفى لتلقي الأكسجين والسوائل الوريدية. [WHO IMCI Model Handbook, Section 2.1, Page 20–23]';
          recEn =
              'Classification: SEVERE PNEUMONIA OR VERY SEVERE DISEASE. Give first dose of appropriate antibiotic and REFER URGENTLY to hospital for oxygen and IV therapy. [WHO IMCI Model Handbook, Section 2.1, Page 20–23]';
          diffs = isEnglish
              ? [
                  DifferentialDiagnosis(name: 'Severe Pneumonia', probability: 80),
                  DifferentialDiagnosis(name: 'Severe Bronchiolitis', probability: 15),
                  DifferentialDiagnosis(name: 'Acute Severe Asthma', probability: 5),
                ]
              : [
                  DifferentialDiagnosis(name: 'التهاب رئوي حاد وخيم', probability: 80),
                  DifferentialDiagnosis(name: 'التهاب القصيبات الهوائية', probability: 15),
                  DifferentialDiagnosis(name: 'ربو شعبي حاد', probability: 5),
                ];
          evidence.addAll([
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Cough or Difficult Breathing > SEVERE PNEUMONIA OR VERY SEVERE DISEASE',
              page: 20,
              relevanceScore: 98.0,
              highlightTextEn:
                  'A child with cough or difficult breathing who has lower chest wall indrawing or stridor in a calm child is classified as SEVERE PNEUMONIA OR VERY SEVERE DISEASE. Action: Give first dose of appropriate antibiotic (injectable ampicillin or oral amoxicillin), soothe throat with a safe remedy, treat fever if present, and REFER URGENTLY to hospital for oxygen therapy and clinical inpatient care.',
              highlightTextAr:
                  'الطفل المصاب بسعال أو صعوبة بالتنفس مع انسحاب لأسفل جدار الصدر للداخل أو صرير والطفل هادئ يصنف كالتهاب رئوي وخيم أو مرض وخيم جداً. الإجراء: إعطاء الجرعة الأولى من المضاد الحيوي المناسب، وتلطيف الحلق بملعقة دافئة، وعلاج الحمى، والإحالة الفورية للمستشفى لتلقي الأكسجين والعلاج الداعم.',
              triageColor: 'RED',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Cough or Difficult Breathing > HOSPITAL REFERRAL & OXYGEN THERAPY',
              page: 21,
              relevanceScore: 95.0,
              highlightTextEn:
                  'Children with chest indrawing have severe lower respiratory tract disease with hypoxaemia. Oxygen must be administered immediately upon arrival at hospital. Ensure unobstructed airway during transport.',
              highlightTextAr:
                  'الأطفال المصابون بانسحاب جدار الصدر يعانون من مرض تنفسي سفلي وخيم مع نقص الأكسجين. يلزم إعطاء الأكسجين فور الوصول للمستشفى وتأمين مجرى هواء سالك أثناء النقل.',
              triageColor: 'RED',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Cough or Difficult Breathing > PRE-REFERRAL ANTIBIOTIC DOSING',
              page: 22,
              relevanceScore: 93.0,
              highlightTextEn:
                  'Give the first dose of Ampicillin (50 mg/kg IM) or oral Amoxicillin prior to referral. Do not delay urgent transfer to hospital for subsequent doses.',
              highlightTextAr:
                  'إعطاء الجرعة الأولى من الأمبيسيلين (50 مجم/كجم عضل) أو الأموكسيسيلين الفموي قبل النقل. تجنب تأخير الإحالة العاجلة للمستشفى.',
              triageColor: 'RED',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Cough or Difficult Breathing > SUPPORTIVE CARE & HOME SOOTHING REMEDIES',
              page: 23,
              relevanceScore: 90.0,
              highlightTextEn:
                  'Soothe the throat and relieve cough with a safe remedy such as warm water with sugar or honey (for children > 1 year). Avoid harmful sedating cough syrups.',
              highlightTextAr:
                  'تلطيف الحلق وتخفيف السعال بمشروب دافئ آمن محلى بالسكر أو العسل (للأطفال أكبر من سنة). تجنب أدوية السعال المهدئة والضارة.',
              triageColor: 'RED',
            ),
          ]);
        } else if (hasSunkenEyes && hasSkinPinchVerySlow) {
          labelAr = 'خطر عاجل - جفاف شديد (الخطة ج) 🔴';
          labelEn = 'EMERGENCY - SEVERE DEHYDRATION (Plan C) 🔴';
          recAr =
              'تصنيف الحالة: جفاف شديد (Severe Dehydration). يلزم بدء السوائل الوريدية فوراً (الخطة ج: محلول رينجر لاكتات 100 مل/كجم) أو الإحالة العاجلة مع رشفات محلول الجفاف. [WHO IMCI Model Handbook, Section 3.1, Page 28, 143]';
          recEn =
              'Classification: SEVERE DEHYDRATION. Start IV fluids immediately (Plan C: Ringer’s Lactate 100 ml/kg) or refer urgently. [WHO IMCI Model Handbook, Section 3.1, Page 28, 143]';
          diffs = isEnglish
              ? [DifferentialDiagnosis(name: 'Gastroenteritis with Severe Dehydration', probability: 90)]
              : [DifferentialDiagnosis(name: 'نزلة معوية مع جفاف شديد (الخطة ج)', probability: 90)];
          evidence.addAll([
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Diarrhoea & Dehydration > SEVERE DEHYDRATION CLASSIFICATION (Plan C)',
              page: 28,
              relevanceScore: 98.0,
              highlightTextEn:
                  'If two of the following signs are present: lethargy or unconsciousness, sunken eyes, not able to drink or drinking poorly, skin pinch goes back very slowly (> 2 seconds), classify as SEVERE DEHYDRATION. Treatment: Start intravenous fluids immediately (Plan C: Ringer’s Lactate or Normal Saline 100 ml/kg) according to age schedule, or refer urgently while giving ORS by sips.',
              highlightTextAr:
                  'إذا توافرت علامتان من الآتي: خمول أو فقدان وعي، عيون غائرة، عدم القدرة على الشرب، رجوع ثنية الجلد ببطء شديد (> ثانيتين)، تصنف الحالة كجفاف شديد. العلاج: البدء الفوري بإعطاء السوائل الوريدية (الخطة ج: محلول رينجر لاكتات 100 مل/كجم) أو الإحالة العاجلة مع استمرار إعطاء رشفات محلول الجفاف أثناء النقل.',
              triageColor: 'RED',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Diarrhoea & Dehydration > PLAN C INTRAVENOUS RINGER\'S LACTATE INFUSION',
              page: 143,
              relevanceScore: 96.0,
              highlightTextEn:
                  'Give 100 ml/kg Ringer\'s Lactate Solution divided into two stages: Stage 1 (30 ml/kg in 1 hour for infants < 12m or 30 min for older children) and Stage 2 (70 ml/kg in 5 hours for infants or 2.5 hours for older children).',
              highlightTextAr:
                  'إعطاء 100 مل/كجم من محلول رينجر لاكتات مقسمة على مرحلتين: المرحلة الأولى (30 مل/كجم خلال ساعة للرضع أو 30 دقيقة للأطفال الأكبر) والمرحلة الثانية (70 مل/كجم خلال 5 ساعات للرضع أو 2.5 ساعة للأطفال الأكبر).',
              triageColor: 'RED',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Diarrhoea & Dehydration > FREQUENT CLINICAL REASSESSMENT & ORS TRANSITION',
              page: 27,
              relevanceScore: 93.0,
              highlightTextEn:
                  'Reassess the child every 15-30 minutes until strong radial pulse is palpable. Give ORS (5 ml/kg/hour) as soon as the child can drink while continuing IV infusion.',
              highlightTextAr:
                  'إعادة تقييم الطفل كل 15-30 دقيقة حتى يعود النبض الكعبري بقوة. البدء بإعطاء محلول الجفاف الفموي (5 مل/كجم/ساعة) بمجرد قدرة الطفل على الشرب مع استمرار المحلول الوريدي.',
              triageColor: 'RED',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Diarrhoea & Dehydration > ZINC SUPPLEMENTATION & CONTINUED FEEDING',
              page: 25,
              relevanceScore: 90.0,
              highlightTextEn:
                  'Provide 20 mg Zinc daily (10 mg for infants < 6 months) for 14 days to accelerate intestinal mucosa recovery and reduce diarrhea recurrence for up to 3 months.',
              highlightTextAr:
                  'إعطاء 20 مجم زنك يومياً (10 مجم للرضع أقل من 6 أشهر) لمدة 14 يوماً لتسريع تعافي الغشاء المخاطي المعوي وتقليل تكرار الإسهال لمدة تصل إلى 3 أشهر.',
              triageColor: 'RED',
            ),
          ]);
        } else if (hasStiffNeck) {
          labelAr = 'خطر عاجل - مرض حموي وخيم / اشتباه سحايا 🔴';
          labelEn = 'EMERGENCY - VERY SEVERE FEBRILE DISEASE 🔴';
          recAr =
              'تصنيف الحالة: مرض حموي وخيم جداً / اشتباه التهاب السحايا (Very Severe Febrile Disease). يلزم إعطاء الجرعة الأولى من المضاد الحيوي بالحقن، ومنع انخفاض السكر، والإحالة الفورية للمستشفى. [WHO IMCI Model Handbook, Section 4.1, Page 35, 37]';
          recEn =
              'Classification: VERY SEVERE FEBRILE DISEASE (Suspect Meningitis). Give first dose of injectable antibiotic, treat to prevent hypoglycemia, and REFER URGENTLY. [WHO IMCI Model Handbook, Section 4.1, Page 35, 37]';
          diffs = isEnglish
              ? [DifferentialDiagnosis(name: 'Acute Bacterial Meningitis', probability: 85)]
              : [DifferentialDiagnosis(name: 'التهاب السحايا الحاد', probability: 85)];
          evidence.addAll([
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Fever & Systemic Illness > VERY SEVERE FEBRILE DISEASE (SUSPECT MENINGITIS)',
              page: 35,
              relevanceScore: 98.0,
              highlightTextEn:
                  'A child with fever and stiff neck, or any general danger sign in a febrile child, is classified as VERY SEVERE FEBRILE DISEASE (suspect meningitis). Action: Give first dose of injectable Ceftriaxone or Ampicillin, give Paracetamol for high fever (> 38.5°C), prevent hypoglycemia with breastmilk or sugar water, and REFER URGENTLY to hospital.',
              highlightTextAr:
                  'الطفل المصاب بحمى مع تيبس بالرقبة، أو أي علامة خطورة عامة، يصنف كمرض حموي وخيم جداً (اشتباه التهاب السحايا). الإجراء: إعطاء الجرعة الأولى من المضاد الحيوي المناسب بالحقن، وعلاج الحمى الشديدة بالباراسيتامول، ومنع هبوط السكر، والإحالة العاجلة للمستشفى.',
              triageColor: 'RED',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Fever & Systemic Illness > FIRST DOSE INJECTABLE ANTIMICROBIALS',
              page: 37,
              relevanceScore: 95.0,
              highlightTextEn:
                  'Administer Ceftriaxone 100 mg/kg IM or Ampicillin 50 mg/kg IM + Gentamicin 7.5 mg/kg IM immediately prior to transfer to prevent irreversible neurological sequelae.',
              highlightTextAr:
                  'إعطاء السيفترياكسون 100 مجم/كجم عضل أو أمبيسيلين 50 مجم/كجم + جنتاميسين 7.5 مجم/كجم عضل فوراً قبل النقل لمنع المضاعفات العصبية الخطيرة.',
              triageColor: 'RED',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Fever & Systemic Illness > MALARIA ASSESSMENT & RAPID DIAGNOSTIC TESTS',
              page: 32,
              relevanceScore: 92.0,
              highlightTextEn:
                  'In malaria-endemic areas, perform a blood smear or malaria rapid diagnostic test (RDT) for all children with fever. Give first dose of rectal or injectable artesunate in severe disease.',
              highlightTextAr:
                  'في مناطق توطن الملاريا، يلزم إجراء فحص الملاريا السريع (RDT) لجميع الأطفال المصابين بحمى. إعطاء الجرعة الأولى من الآرتيسونات الشرجية أو بالحقن في الحالات الوخيمة.',
              triageColor: 'RED',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Fever & Systemic Illness > PARACETAMOL DOSING FOR HIGH FEVER (> 38.5°C)',
              page: 41,
              relevanceScore: 90.0,
              highlightTextEn:
                  'Give one dose of Paracetamol (10-15 mg/kg) in the clinic for fever >= 38.5°C to reduce distress and discomfort.',
              highlightTextAr:
                  'إعطاء جرعة واحدة من الباراسيتامول (10-15 مجم/كجم) بالعيادة عند ارتفاع الحرارة ≥ 38.5°C لتهدئة الطفل وتخفيف الألم.',
              triageColor: 'RED',
            ),
          ]);
        } else if (hasMastoid) {
          labelAr = 'خطر عاجل - التهاب الخشاء 🔴';
          labelEn = 'EMERGENCY - MASTOIDITIS 🔴';
          recAr =
              'تصنيف الحالة: التهاب الخشاء (Mastoiditis) لوجود تورم مؤلم خلف الأذن. يلزم إعطاء الجرعة الأولى من المضاد الحيوي المناسب والباراسيتامول للألم والإحالة الفورية للمستشفى. [WHO IMCI Model Handbook, Chapter 10: Ear Problems, Page 43–46]';
          recEn =
              'Classification: MASTOIDITIS (Tender swelling behind ear). Give first dose of appropriate antibiotic, Paracetamol for pain, and REFER URGENTLY to hospital. [WHO IMCI Model Handbook, Chapter 10: Ear Problems, Page 43–46]';
          diffs = isEnglish
              ? [DifferentialDiagnosis(name: 'Acute Mastoiditis', probability: 90)]
              : [DifferentialDiagnosis(name: 'التهاب الخشاء الحاد', probability: 90)];
          evidence.addAll([
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Chapter 10: Ear Problems > MASTOIDITIS',
              page: 43,
              relevanceScore: 98.0,
              highlightTextEn:
                  'A child with a tender swelling behind the ear is classified as MASTOIDITIS. Action: Give first dose of appropriate antibiotic (Ampicillin IM or Amoxicillin oral), give first dose of Paracetamol for pain, and REFER URGENTLY to hospital.',
              highlightTextAr:
                  'الطفل الذي يعاني من تورم مؤلم خلف الأذن يصنف كالمؤثر على عظم الخشاء (التهاب الخشاء). الإجراء: إعطاء الجرعة الأولى من المضاد الحيوي المناسب والباراسيتامول للألم والإحالة الفورية للمستشفى.',
              triageColor: 'RED',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Chapter 10: Ear Problems > ASSESS EAR PROBLEMS',
              page: 44,
              relevanceScore: 95.0,
              highlightTextEn:
                  'Is there ear pain? Is there ear discharge? If yes, for how long? Feel for tender swelling behind the ear.',
              highlightTextAr:
                  'فحص مشاكل الأذن: هل يوجد ألم بالأذن؟ هل توجد إفرازات؟ منذ متى؟ لمس التورم المؤلم خلف الأذن فوق عظمة الخشاء.',
              triageColor: 'RED',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Chapter 10: Ear Problems > EAR DISCHARGE & CARE',
              page: 45,
              relevanceScore: 91.0,
              highlightTextEn:
                  'Dry the ear by wicking if discharge is present. Do not place any compress or oil into the ear canal.',
              highlightTextAr:
                  'تجفيف الأذن بالفتيل القماشي عند وجود إفرازات. يمنع وضع زيوة أو قطرات غير ملائمة داخل مجرى الأذن.',
              triageColor: 'RED',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Chapter 21: Appropriate Oral Drugs > PARACETAMOL FOR EAR PAIN',
              page: 91,
              relevanceScore: 89.0,
              highlightTextEn:
                  'Give Paracetamol (10-15 mg/kg) every 6 hours for ear pain or high fever.',
              highlightTextAr:
                  'إعطاء الباراسيتامول (10-15 مجم/كجم) كل 6 ساعات لتخفيف ألم الأذن أو الحمى.',
              triageColor: 'RED',
            ),
          ]);
        } else if (hasSevereWasting) {
          labelAr = 'خطر عاجل - سوء تغذية وخيم / أنيميا حادة 🔴';
          labelEn = 'EMERGENCY - SEVERE MALNUTRITION / SEVERE ANAEMIA 🔴';
          recAr =
              'تصنيف الحالة: سوء تغذية وخيم أو فقر دم شديد (Severe Malnutrition or Severe Anaemia) لوجود هزال شديد واضح أو تورم بالقدمين أو شحوب شديد. '
              'يلزم إعطاء الجرعة الأولى من فيتامين (أ) فوراً في العيادة، وتدفئة الطفل ومراقبته لمنع هبوط السكر والحرارة، والتحويل الفوري العاجل للمستشفى أو مركز التغذية العلاجي. [WHO IMCI Model Handbook, Chapter 11: Malnutrition and Anaemia, Page 47–52]';
          recEn =
              'Classification: SEVERE MALNUTRITION OR SEVERE ANAEMIA (Visible severe wasting, oedema of both feet, or severe palmar pallor). '
              'Give Vitamin A single dose immediately in clinic, keep warm, prevent low blood sugar, and REFER URGENTLY to hospital or Therapeutic Feeding Centre. [WHO IMCI Model Handbook, Chapter 11: Malnutrition and Anaemia, Page 47–52]';
          diffs = isEnglish
              ? [
                  DifferentialDiagnosis(name: 'Severe Acute Malnutrition (Marasmus / Kwashiorkor)', probability: 85),
                  DifferentialDiagnosis(name: 'Severe Anaemia', probability: 10),
                  DifferentialDiagnosis(name: 'Secondary Malabsorption', probability: 5),
                ]
              : [
                  DifferentialDiagnosis(name: 'سوء تغذية حاد وخيم (هزال شديد / وذمة بالقدمين)', probability: 85),
                  DifferentialDiagnosis(name: 'أنيميا حادة وخيمة', probability: 10),
                  DifferentialDiagnosis(name: 'متلازمة سوء امتصاص ثانوي', probability: 5),
                ];
          evidence.addAll([
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Chapter 11: Malnutrition & Anaemia > SEVERE MALNUTRITION',
              page: 50,
              relevanceScore: 98.5,
              highlightTextEn:
                  'A child with visible severe wasting (Marasmus) or oedema of both feet (Kwashiorkor) is classified as SEVERE MALNUTRITION OR SEVERE ANAEMIA. Action: Give Vitamin A single dose, keep the child warm, treat to prevent low blood sugar, and REFER URGENTLY to hospital.',
              highlightTextAr:
                  'الطفل الذي يظهر عليه هزال شديد واضح (Marasmus) أو تورم في كلا القدمين (Kwashiorkor) يصنف بسوء تغذية وخيم. العلاج: إعطاء جرعة واحدة من فيتامين أ، وتدفئة الطفل لمنع هبوط الحرارة والسكر، والتحويل الفوري العاجل للمستشفى.',
              triageColor: 'RED',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Chapter 11: Malnutrition & Anaemia > ASSESS NUTRITIONAL STATUS',
              page: 48,
              relevanceScore: 95.0,
              highlightTextEn:
                  'Look for visible severe wasting of muscles of shoulders, arms, buttocks and legs. Look and feel for oedema of both feet by pressing with thumb for a few seconds.',
              highlightTextAr:
                  'فحص الهزال الشديد: تجريد الطفل من ملابسه وملاحظة ضمور عضلات الكتفين والذراعين والأليتين والساقين. فحص تورم القدمين بالضغط بالإبهام لعدة ثوان.',
              triageColor: 'RED',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Chapter 21: Appropriate Oral Drugs > VITAMIN A DOSING',
              page: 93,
              relevanceScore: 92.0,
              highlightTextEn:
                  'Vitamin A is given to all children with severe malnutrition or measles to boost immunity and prevent corneal ulceration and blindness.',
              highlightTextAr:
                  'يعطى فيتامين أ لجميع حالات سوء التغذية الوخيم والحصبة لتقوية المناعة وحماية العين من تقرح القرنية والعمى.',
              triageColor: 'RED',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Chapter 11: Malnutrition & Anaemia > SEVERE ANAEMIA & PALMAR PALLOR',
              page: 47,
              relevanceScore: 90.0,
              highlightTextEn:
                  'If the palm of the child\'s hand is very pale or white, classify as SEVERE ANAEMIA. Refer urgently for blood transfusion assessment.',
              highlightTextAr:
                  'إذا كانت راحة يد الطفل شاحبة جداً أو بيضاء، تصنف الحالة كأنيميا حادة وخيمة. الإحالة الفورية لتقييم الحاجة لنقل الدم.',
              triageColor: 'RED',
            ),
          ]);
        } else {
          labelAr = 'خطر عاجل - علامات خطورة عامة 🔴';
          labelEn = 'EMERGENCY - GENERAL DANGER SIGNS 🔴';
          recAr =
              'تصنيف الحالة: وجود علامة خطورة عامة (عدم القدرة على الشرب، قيء كل شيء، تشنجات، أو خمول/فقدان وعي) تتطلب إكمال التقييم وإعطاء العلاج التحويلي العاجل والإحالة الفورية للمستشفى. [WHO IMCI Model Handbook, Chapter 6: General Danger Signs, Page 16–18]';
          recEn =
              'Classification: GENERAL DANGER SIGNS (Not able to drink, vomiting everything, convulsions, or lethargy). Complete pre-referral treatment immediately, keep warm, prevent hypoglycemia, and REFER URGENTLY to hospital. [WHO IMCI Model Handbook, Chapter 6: General Danger Signs, Page 16–18]';
          diffs = isEnglish
              ? [DifferentialDiagnosis(name: 'Very Severe Systemic Disease / Sepsis', probability: 90)]
              : [DifferentialDiagnosis(name: 'مرض جهازي وخيم / إنتان حاد', probability: 90)];
          evidence.addAll([
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Chapter 6: General Danger Signs > CHECK FOR GENERAL DANGER SIGNS',
              page: 16,
              relevanceScore: 99.0,
              highlightTextEn:
                  'A child with any general danger sign has a severe problem requiring URGENT pre-referral treatment, completion of assessment, and hospital referral. General danger signs include: not able to drink or breastfeed, vomiting everything, convulsions during this illness, or lethargic/unconscious. Assess and treat immediately to prevent hypoglycemia and keep the child warm during urgent referral.',
              highlightTextAr:
                  'الطفل الذي تظهر عليه أي علامة من علامات الخطورة العامة يعاني من مرض وخيم يستوجب إعطاء العلاج التحويلي العاجل وإكمال التقييم والإحالة الفورية للمستشفى. تشمل علامات الخطورة العامة: عدم القدرة على الشرب أو الرضاعة، القيء المستمر لكل شيء، حدوث تشنجات، أو الخمول الشديد وفقدان الوعي. يلزم تدفئة الطفل وإعطاؤه رشفات ماء بسكر لمنع هبوط السكر أثناء النقل.',
              triageColor: 'RED',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Chapter 6: General Danger Signs > URGENT PRE-REFERRAL STABILIZATION',
              page: 17,
              relevanceScore: 96.0,
              highlightTextEn:
                  'Quickly complete the rest of the assessment so that pre-referral treatments (antibiotics, artesunate, vitamin A, oral rehydration) can be given before transport.',
              highlightTextAr:
                  'إكمال الفحص السريري سريعاً لإعطاء كافة العلاجات التحويلية المطلوبة (المضادات الحيوية، الآرتيسونات، فيتامين أ، محلول الجفاف) قبل النقل.',
              triageColor: 'RED',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Chapter 6: General Danger Signs > PREVENTION OF HYPOGLYCEMIA & WARMTH',
              page: 18,
              relevanceScore: 93.0,
              highlightTextEn:
                  'Give 30-50 ml of milk or sugar water (4 teaspoons of sugar in 200 ml of water) before referral to prevent fatal hypoglycemic brain injury during transfer.',
              highlightTextAr:
                  'إعطاء 30-50 مل من الحليب أو ماء السكر (4 ملاعق صغيرة سكر في 200 مل ماء) قبل النقل لمنع انخفاض السكر وتأثر الدماغ أثناء النقل.',
              triageColor: 'RED',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Chapter 6: General Danger Signs > EMERGENCY TRANSPORTATION & REFERRAL PROTOCOL',
              page: 19,
              relevanceScore: 90.0,
              highlightTextEn:
                  'Ensure referral note accompanies the child detailing all clinical findings and exact medications given with time of administration.',
              highlightTextAr:
                  'إرفاق تقرير الإحالة الطبي المفصل (SBAR) مع المريض موضحاً كافة العلامات السريرية والأدوية المعطاة وساعة إعطائها بدقة.',
              triageColor: 'RED',
            ),
          ]);
        }

        if (isEnglish) {
          if (detectedBpm != null) summary.add('Breathing rate: $detectedBpm breaths/min');
          if (hasChestIndrawing) summary.add('Lower chest wall indrawing present');
          if (hasVomitingAll) summary.add('Vomiting everything');
          if (hasConvulsions) summary.add('Convulsions or seizures');
          if (notAbleToDrink) summary.add('Unable to drink or breastfeed');
          if (isLethargic) summary.add('Abnormally lethargic or unconscious');
          if (summary.isEmpty) summary.add(query.length > 70 ? '${query.substring(0, 70)}...' : query);
        } else {
          if (detectedBpm != null) summary.add('معدل التنفس: $detectedBpm نفس/دقيقة');
          if (hasChestIndrawing) summary.add('انسحاب أسفل جدار الصدر للداخل');
          if (hasVomitingAll) summary.add('قيء مستمر لكل شيء');
          if (hasConvulsions) summary.add('تشنجات سابقة أو حالية');
          if (notAbleToDrink) summary.add('غير قادر على الشرب أو الرضاعة');
          if (isLethargic) summary.add('خمول شديد أو فقدان وعي');
          if (summary.isEmpty) summary.add(query.length > 60 ? '${query.substring(0, 60)}...' : query);
        }
      } else if (hasBloodInStool || isFastBreathing || (hasDiarrhea && (hasSunkenEyes || hasSkinPinchSlow)) || hasEarPainOrDischarge) {
        triage = 'YELLOW';
        if (hasBloodInStool) {
          labelAr = 'علاج في العيادة - دوزنتاريا (دم بالبراز) 🟡';
          labelEn = 'CLINIC TREATMENT - DYSENTERY 🟡';
          recAr =
              'تصنيف الحالة: دوزنتاريا (Dysentery). أعط مضاداً حيوياً مناسباً لجرثومة الشيجلا (مثل السيبروفلوكساسين) لمدة 5 أيام، ومحلول الجفاف والزنك لمدة 14 يوماً مع متابعة بعد يومين. [WHO IMCI Model Handbook, Section 3.2, Page 26, 30]';
          recEn =
              'Classification: DYSENTERY. Give oral antibiotic recommended for Shigella (such as ciprofloxacin) for 5 days. Provide ORS and Zinc for 14 days with follow-up in 2 days. [WHO IMCI Model Handbook, Section 3.2, Page 26, 30]';
          diffs = isEnglish
              ? [DifferentialDiagnosis(name: 'Bacterial Shigella Dysentery', probability: 85)]
              : [DifferentialDiagnosis(name: 'دوزنتاريا بكتيرية (شيجلا)', probability: 85)];
          evidence.addAll([
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Diarrhoea & Dehydration > DYSENTERY (BLOOD IN STOOL)',
              page: 26,
              relevanceScore: 96.0,
              highlightTextEn:
                  'A child with diarrhoea and visible blood in stool is classified as DYSENTERY. Treatment: Treat for 5 days with oral Ciprofloxacin (or recommended Shigella antibiotic), give oral rehydration salts and Zinc supplements for 14 days, and follow up in 2 days or return immediately if condition worsens.',
              highlightTextAr:
                  'الطفل الذي يعاني من إسهال مع وجود دم مرئي في البراز يصنف كدوزنتاريا (زحار). العلاج: إعطاء مضاد حيوي فموي فعال ضد الشيجلا (مثل السيبروفلوكساسين) لمدة 5 أيام، ومحلول الجفاف مع الزنك لمدة 14 يوماً، ومتابعة الطفل بعد يومين أو المراجعة الفورية عند التدهور.',
              triageColor: 'YELLOW',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Diarrhoea & Dehydration > CIPROFLOXACIN 5-DAY ANTIMICROBIAL REGIMEN',
              page: 30,
              relevanceScore: 93.0,
              highlightTextEn:
                  'Ciprofloxacin is the drug of choice for Shigella dysentery: 15 mg/kg orally twice daily for 5 days. Reassess after 2 days for clinical improvement.',
              highlightTextAr:
                  'السيبروفلوكساسين هو الخيار الأول لعلاج دوزنتاريا الشيجلا: 15 مجم/كجم فموياً مرتين يومياً لمدة 5 أيام. إعادة الفحص بعد يومين لملاحظة التحسن.',
              triageColor: 'YELLOW',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Diarrhoea & Dehydration > FLUID REPLACEMENT WITH LOW-OSMOLARITY ORS',
              page: 25,
              relevanceScore: 91.0,
              highlightTextEn:
                  'Give extra fluids and ORS after each loose stool to prevent dehydration (50-100 ml for < 2 years, 100-200 ml for older children).',
              highlightTextAr:
                  'إعطاء سوائل إضافية ومحلول الجفاف بعد كل تبرز مائي لمنع الجفاف (50-100 مل لأقل من سنتين، 100-200 مل للأطفال الأكبر).',
              triageColor: 'YELLOW',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Diarrhoea & Dehydration > 2-DAY CLINICAL FOLLOW-UP PROTOCOL',
              page: 28,
              relevanceScore: 88.0,
              highlightTextEn:
                  'Follow up in 2 days. If stool blood persists, fever continues, or dehydration worsens, change antibiotic or refer to hospital.',
              highlightTextAr:
                  'المتابعة بعد يومين. إذا استمر الدم بالبراز أو استمرت الحمى أو ساء الجفاف، يلزم تغيير المضاد الحيوي أو التحويل للمستشفى.',
              triageColor: 'YELLOW',
            ),
          ]);
          summary = isEnglish ? ['Visible blood in stool', 'Diarrhoea episode'] : ['دم مرئي في البراز', 'نوبة إسهال'];
        } else if (hasEarPainOrDischarge) {
          labelAr = 'علاج في العيادة - التهاب الأذن الحاد 🟡';
          labelEn = 'CLINIC TREATMENT - ACUTE EAR INFECTION 🟡';
          recAr =
              'تصنيف الحالة: التهاب الأذن الحاد (Acute Ear Infection). أعط أموكسيسيلين فموي لمدة 5 أيام، وباراسيتامول لتسكين الألم، وتجفيف الأذن بالفتيل القماشي إذا وجدت إفرازات، والمتابعة بعد 5 أيام. [WHO IMCI Model Handbook, Chapter 10: Ear Problems, Page 43–46]';
          recEn =
              'Classification: ACUTE EAR INFECTION. Give oral Amoxicillin for 5 days, Paracetamol for pain relief, dry ear by wicking if discharge is present, and follow-up in 5 days. [WHO IMCI Model Handbook, Chapter 10: Ear Problems, Page 43–46]';
          diffs = isEnglish
              ? [DifferentialDiagnosis(name: 'Acute Otitis Media', probability: 85)]
              : [DifferentialDiagnosis(name: 'التهاب الأذن الوسطى الحاد', probability: 85)];
          evidence.addAll([
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Chapter 10: Ear Problems > ACUTE EAR INFECTION',
              page: 43,
              relevanceScore: 96.0,
              highlightTextEn:
                  'Ear pain or discharge for less than 14 days is classified as ACUTE EAR INFECTION. Give oral Amoxicillin for 5 days, give Paracetamol for pain, and dry the ear by wicking.',
              highlightTextAr:
                  'ألم الأذن أو الإفرازات لأقل من 14 يوماً يصنف كالتهاب أذن حاد. العلاج: أموكسيسيلين فموي 5 أيام، وباراسيتامول للألم، وتجفيف الأذن.',
              triageColor: 'YELLOW',
            ),
          ]);
          summary = isEnglish ? ['Ear pain or discharge < 14 days'] : ['ألم بالأذن أو إفرازات'];
        } else if (isFastBreathing) {
          labelAr = 'علاج في العيادة - التهاب رئوي بسيط 🟡';
          labelEn = 'CLINIC TREATMENT - PNEUMONIA 🟡';
          recAr =
              'تصنيف الحالة: التهاب رئوي (Pneumonia - تنفس سريع بدون انسحاب الصدر أو علامات خطورة). أعط أموكسيسيلين فموي (125 مجم/5 مل) لمدة 5 أيام وفق جدول الوزن. تهدئة الحلق بملعقة دافئة والمتابعة بعد يومين. [WHO IMCI Model Handbook, Section 2.2, Page 20, 22]';
          recEn =
              'Classification: PNEUMONIA (Fast breathing without chest indrawing or danger signs). Give oral Amoxicillin for 5 days according to weight band. Soothe throat and follow-up in 2 days. [WHO IMCI Model Handbook, Section 2.2, Page 20, 22]';
          diffs = isEnglish
              ? [DifferentialDiagnosis(name: 'Non-severe Pneumonia', probability: 85)]
              : [DifferentialDiagnosis(name: 'التهاب رئوي بسيط', probability: 85)];
          evidence.addAll([
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Cough or Difficult Breathing > PNEUMONIA CLASSIFICATION & FAST BREATHING CUTOFFS',
              page: 20,
              relevanceScore: 96.0,
              highlightTextEn:
                  'Fast breathing without general danger signs and without lower chest wall indrawing is classified as Pneumonia. Cutoffs: >= 50 breaths/min for 2-11 months; >= 40 breaths/min for 12 months to 5 years.',
              highlightTextAr:
                  'التنفس السريع بدون علامات خطورة عامة وبدون انسحاب لجدار الصدر يصنف كالتهاب رئوي بسيط. عتبات التنفس السريع: ≥ 50 نفس/د للأطفال من 2-11 شهراً؛ ≥ 40 نفس/د للأطفال من 12 شهراً إلى 5 سنوات.',
              triageColor: 'YELLOW',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Cough or Difficult Breathing > ORAL AMOXICILLIN 5-DAY TREATMENT REGIMEN',
              page: 22,
              relevanceScore: 94.0,
              highlightTextEn:
                  'Give oral Amoxicillin (40-50 mg/kg/day divided twice daily) for 5 days according to the standard weight band table.',
              highlightTextAr:
                  'إعطاء أموكسيسيلين فموي (40-50 مجم/كجم/يوم مقسمة على جرعتين) لمدة 5 أيام وفق جدول الأوزان المعتمد.',
              triageColor: 'YELLOW',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Cough or Difficult Breathing > 2-DAY MANDATORY FOLLOW-UP ASSESSMENT',
              page: 21,
              relevanceScore: 91.0,
              highlightTextEn:
                  'Advise mother to return in 2 days for reassessment, or immediately if breathing becomes difficult or faster or child cannot drink.',
              highlightTextAr:
                  'إلزام الأم بالمتابعة بعد يومين لإعادة التقييم، أو المراجعة الفورية إذا أصبحت هناك صعوبة في التنفس أو عجز عن الشرب.',
              triageColor: 'YELLOW',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Cough or Difficult Breathing > HOME CARE, FLUIDS & DANGER SIGN MONITORING',
              page: 23,
              relevanceScore: 89.0,
              highlightTextEn:
                  'Counsel mother on home care, increasing fluids, continued feeding, and soothing throat remedies.',
              highlightTextAr:
                  'توجيه الأم بالرعاية المنزلية وزيادة السوائل والاستمرار في التغذية واستخدام المشروبات الدافئة الآمنة.',
              triageColor: 'YELLOW',
            ),
          ]);
          summary = isEnglish
              ? ['Fast breathing without chest indrawing', 'No general danger signs']
              : ['تنفس سريع بدون انسحاب الصدر', 'لا توجد علامات خطورة عامة'];
        } else {
          labelAr = 'علاج في العيادة - بعض الجفاف (الخطة ب) 🟡';
          labelEn = 'CLINIC TREATMENT - SOME DEHYDRATION (Plan B) 🟡';
          recAr =
              'تصنيف الحالة: بعض الجفاف (Some Dehydration). أعط محلول الجفاف الفموي بالعيادة خلال 4 ساعات (الخطة ب: 75 مل/كجم)، وأعط الزنك لمدة 14 يوماً. إعادة التقييم بعد 4 ساعات. [WHO IMCI Model Handbook, Section 3.1, Page 28, 98]';
          recEn =
              'Classification: SOME DEHYDRATION. Treat with ORS in clinic over 4 hours (Plan B: 75 ml/kg) and Zinc for 14 days. Reassess after 4 hours. [WHO IMCI Model Handbook, Section 3.1, Page 28, 98]';
          diffs = isEnglish
              ? [DifferentialDiagnosis(name: 'Moderate Dehydration (Plan B)', probability: 90)]
              : [DifferentialDiagnosis(name: 'جفاف متوسط (الخطة ب)', probability: 90)];
          evidence.addAll([
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Diarrhoea & Dehydration > SOME DEHYDRATION CLASSIFICATION',
              page: 28,
              relevanceScore: 95.0,
              highlightTextEn:
                  'If two of the following signs: restless/irritable, sunken eyes, drinks eagerly/thirsty, skin pinch goes back slowly, classify as SOME DEHYDRATION. Give ORS over 4 hours (Plan B) and Zinc for 14 days.',
              highlightTextAr:
                  'إذا توافرت علامتان: تململ/هياج، عيون غائرة، شرب بلهفة/عطش، رجوع ثنية الجلد ببطء، تصنف الحالة كبعض الجفاف. أعط محلول الجفاف خلال 4 ساعات (الخطة ب) والزنك لمدة 14 يوماً.',
              triageColor: 'YELLOW',
            ),
            EvidenceModel(
              documentName: 'WHO IMCI Model Handbook',
              sectionTitle: 'Diarrhoea & Dehydration > PLAN B ORAL REHYDRATION THERAPY (75 ml/kg)',
              page: 98,
              relevanceScore: 93.0,
              highlightTextEn:
                  'In clinic, give 75 ml/kg of ORS over 4 hours. Show the mother how to give ORS solution slowly with a cup or spoon. Reassess after 4 hours.',
              highlightTextAr:
                  'إعطاء 75 مل/كجم من محلول الجفاف بالعيادة خلال 4 ساعات. تدريب الأم على إعطاء المحلول بالملعقة ببطء، وإعادة التقييم بعد 4 ساعات.',
              triageColor: 'YELLOW',
            ),
          ]);
          summary = isEnglish ? ['Diarrhoea with dehydration signs'] : ['إسهال مع علامات جفاف متوسط'];
        }
      } else if (hasDiarrhea) {
        // DIARRHOEA WITH NO DEHYDRATION (PLAN A) 🟢
        triage = 'GREEN';
        labelAr = 'رعاية منزلية - إسهال بدون جفاف (الخطة أ) 🟢';
        labelEn = 'SAFE HOME CARE - NO DEHYDRATION (Plan A) 🟢';
        recAr =
            'تصنيف الحالة: إسهال بدون جفاف (No Dehydration - Plan A). إعطاء سوائل إضافية ومحلول الجفاف بالمنزل بعد كل تبرز مائي، وإعطاء الزنك (20 مجم يومياً) لمدة 14 يوماً، والاستمرار في الرضاعة والتغذية الطبيعية، والمراجعة الفورية إذا ظهر دم بالبراز أو ضعف الشرب أو حمى. [WHO IMCI Model Handbook, Section 3.1, Page 25, 27]';
        recEn =
            'Classification: NO DEHYDRATION (Plan A). Treat diarrhea at home: Give extra fluids and ORS after each loose stool, provide Zinc (20 mg/day) for 14 days, continue feeding, and return immediately if blood in stool, poor drinking, or high fever develops. [WHO IMCI Model Handbook, Section 3.1, Page 25, 27]';
        diffs = isEnglish
            ? [DifferentialDiagnosis(name: 'Acute Gastroenteritis (No Dehydration)', probability: 90)]
            : [DifferentialDiagnosis(name: 'نزلـة معوية حادة (بدون جفاف - الخطة أ)', probability: 90)];
        evidence.addAll([
          EvidenceModel(
            documentName: 'WHO IMCI Model Handbook',
            sectionTitle: 'Diarrhoea & Dehydration > PLAN A: TREAT DIARRHOEA AT HOME',
            page: 25,
            relevanceScore: 94.0,
            highlightTextEn:
                'Plan A Home Treatment: Give extra fluids (as much as the child will take), give Zinc supplements for 14 days, continue feeding, and advise mother when to return immediately.',
            highlightTextAr:
                'الخطة (أ) للعلاج المنزلي للإسهال: إعطاء سوائل إضافية قدر رغبة الطفل، إعطاء الزنك لمدة 14 يوماً، الاستمرار في التغذية، وتوعية الأم بعلامات الخطورة.',
            triageColor: 'GREEN',
          ),
        ]);
        summary = isEnglish ? ['Diarrhoea with no dehydration signs', 'Drinking well'] : ['إسهال بدون علامات جفاف', 'شرب وتغذية جيدة'];
      } else if (hasFever && !hasCough) {
        // FEVER - SAFE HOME CARE 🟢
        triage = 'GREEN';
        labelAr = 'رعاية منزلية - حمى خفيفة بدون خطورة 🟢';
        labelEn = 'SAFE HOME CARE - FEVER 🟢';
        recAr =
            'تصنيف الحالة: حمى بدون علامات خطورة عامة وبدون تيبس بالرقبة. إعطاء الباراسيتامول (10-15 مجم/كجم) عند ارتفاع الحرارة ≥ 38.5°C لتخفيف الانزعاج، وتقديم السوائل بكثرة، ومتابعة الطفل والمراجعة إذا استمرت الحمى لأكثر من 3 أيام أو ظهرت علامات خطورة. [WHO IMCI Model Handbook, Section 4.1, Page 35, 41]';
        recEn =
            'Classification: FEVER (No general danger signs, no stiff neck). Give Paracetamol (10-15 mg/kg) for temperature >= 38.5°C, offer abundant fluids, and return for follow-up if fever persists > 3 days or danger signs appear. [WHO IMCI Model Handbook, Section 4.1, Page 35, 41]';
        diffs = isEnglish
            ? [DifferentialDiagnosis(name: 'Uncomplicated Viral Febrile Illness', probability: 90)]
            : [DifferentialDiagnosis(name: 'مرض حموي فيروسي بسيط', probability: 90)];
        evidence.addAll([
          EvidenceModel(
            documentName: 'WHO IMCI Model Handbook',
            sectionTitle: 'Fever & Systemic Illness > FEVER HOME CARE & PARACETAMOL',
            page: 41,
            relevanceScore: 92.0,
            highlightTextEn:
                'Give Paracetamol for fever >= 38.5°C. Increase fluid intake and sponge with lukewarm water if uncomfortable. Advise mother to return in 3 days if fever does not resolve.',
            highlightTextAr:
                'إعطاء الباراسيتامول للحرارة ≥ 38.5°C وزيادة السوائل والمتابعة بعد 3 أيام إذا لم تنخفض الحرارة.',
            triageColor: 'GREEN',
          ),
        ]);
        summary = isEnglish ? ['Fever without danger signs', 'No stiff neck'] : ['حمى بدون علامات خطورة', 'لا يوجد تيبس بالرقبة'];
      } else {
        // NO PNEUMONIA / COUGH OR COLD 🟢
        triage = 'GREEN';
        labelAr = 'رعاية منزلية آمنة - سعال عادي أو رشح 🟢';
        labelEn = 'SAFE HOME CARE - COUGH OR COLD 🟢';
        recAr =
            'تصنيف الحالة: لا يوجد التهاب رئوي أو جفاف (سعال عادي أو رشح). لا حاجة للمضادات الحيوية. نصح الأم بالاستمرار في الرضاعة والتغذية وإعطاء السوائل المنزلية وتهدئة الحلق بمشروب دافئ آمن، والمراجعة الفورية إذا ظهر تنفس سريع أو صعوبة بالشرب. [WHO IMCI Model Handbook, Section 2.3, Page 20, 23]';
        recEn =
            'Classification: NO PNEUMONIA: COUGH OR COLD. No antibiotics needed. Continue feeding and home fluids. Soothe throat with safe remedy. Return immediately if fast breathing or drinking difficulty develops. [WHO IMCI Model Handbook, Section 2.3, Page 20, 23]';
        diffs = isEnglish
            ? [DifferentialDiagnosis(name: 'Common Cold / Viral URI', probability: 90)]
            : [DifferentialDiagnosis(name: 'نزلة برد / سعال ورشح فيروسي', probability: 90)];
        evidence.addAll([
          EvidenceModel(
            documentName: 'WHO IMCI Model Handbook',
            sectionTitle: 'Cough or Difficult Breathing > NO PNEUMONIA: COUGH OR COLD',
            page: 20,
            relevanceScore: 92.0,
            highlightTextEn:
                'A child with cough or cold who has no general danger signs and no chest indrawing and no fast breathing is classified as NO PNEUMONIA: COUGH OR COLD. Treatment: No antibiotics needed. Advise mother to continue home feeding and fluids, soothe throat with safe remedy, and return immediately if breathing becomes fast or difficult.',
            highlightTextAr:
                'الطفل المصاب بسعال أو رشح بدون علامات خطورة وبدون انسحاب للصدر وبدون تنفس سريع يصنف كنزلة برد بدون التهاب رئوي. العلاج: لا حاجة للمضادات الحيوية. نصح الأم بالاستمرار في الرضاعة والسوائل وتلطيف الحلق والمراجعة الفورية إذا تسارع التنفس.',
            triageColor: 'GREEN',
          ),
          EvidenceModel(
            documentName: 'WHO IMCI Model Handbook',
            sectionTitle: 'Cough or Difficult Breathing > SAFE HOME REMEDIES & AVOIDING ANTIBIOTICS',
            page: 23,
            relevanceScore: 90.0,
            highlightTextEn:
                'Antibiotics will not relieve simple cough or cold caused by viral infections. Use warm fluids or honey (> 1 year) to soothe the respiratory tract.',
            highlightTextAr:
                'المضادات الحيوية لا تفيد في علاج السعال أو الرشح الفيروسي البسيط. استخدام السوائل الدافئة أو العسل (أكبر من سنة) لتلطيف مجرى التنفس.',
            triageColor: 'GREEN',
          ),
        ]);
        summary = isEnglish
            ? ['Normal respiration rate', 'No chest indrawing', 'Active and alert']
            : ['معدل تنفس طبيعي', 'لا يوجد انسحاب بالصدر', 'الطفل نشيط وواعي'];
      }
    }

    // Build Missing / Verification Questions
    if (isEnglish) {
      if (!hasChestIndrawing) missing.add('Is there lower chest wall indrawing when breathing in?');
      if (!hasStridor) missing.add('Is there stridor when the child is calm?');
      if (!notAbleToDrink) missing.add('Is the child unable to drink or breastfeed?');
      if (!hasConvulsions) missing.add('Has the child had convulsions during this illness?');
    } else {
      if (!hasChestIndrawing) missing.add('هل يوجد انسحاب لأسفل جدار الصدر للداخل عند التنفس؟');
      if (!hasStridor) missing.add('هل يوجد صوت صرير (Stridor) والطفل هادئ تماماً؟');
      if (!notAbleToDrink) missing.add('هل الطفل غير قادر على الشرب أو الرضاعة؟');
      if (!hasConvulsions) missing.add('هل يعاني الطفل من تشنجات حالية أو سابقة خلال هذا المرض؟');
    }

    return AssessmentResponseModel(
      id: 'asmt_local_${DateTime.now().millisecondsSinceEpoch}',
      status: 'success',
      detectedLanguage: isEnglish ? 'en' : 'ar',
      triageLevel: triage,
      triageLabelAr: labelAr,
      triageLabelEn: labelEn,
      summaryFound: summary,
      missingInfo: missing,
      fullRecommendation: isEnglish ? recEn : recAr,
      differentialDiagnoses: diffs,
      evidenceList: evidence,
      verificationAnswers: verificationAnswers,
      timestamp: DateTime.now(),
    );
  }
}
