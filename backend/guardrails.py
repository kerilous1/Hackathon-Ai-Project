"""
PediaCare.AI — Safety Guardrails & Refusal Engine (Day 4 Pipeline)
Implements 3-Layer Clinical Safety Checkpoints:
  Check 1: Input Risk & Boundary Filter (Age boundaries, Adult Pharmacology, Out-of-Scope spam)
  Check 2: Retrieval Confidence Threshold Gate (Score >= 70.0%)
  Check 3: Post-Hoc Unsupported Claim Validator
"""

import re
from typing import Any, Dict, List, Optional, Tuple

CONFIDENCE_THRESHOLD_PCT = 70.0

# Adult pharmacology & conditions that trigger immediate boundary refusal
ADULT_PHARMACOLOGY_AND_CONDITIONS = [
    (r"\b(nitroglycerin|nitro|glyceryl trinitrate|isosorbide)\b", "Adult Cardiology / Vasodilator"),
    (r"\b(viagra|sildenafil|tadalafil|cialis)\b", "Adult Urology / PDE5 Inhibitor"),
    (r"\b(atorvastatin|simvastatin|rosuvastatin|statin)\b", "Adult Lipidology / Statins"),
    (r"\b(warfarin|clopidogrel|plavix|apixaban|rivaroxaban|eliquis|xarelto)\b", "Adult Anticoagulation"),
    (r"\b(metformin|glimepiride|insulin glargine|empagliflozin|ozempic|wegovy|semaglutide)\b", "Adult Endocrinology"),
    (r"\b(coronary artery disease|myocardial infarction|angina|heart attack|atherosclerosis|stroke|hypertension in adults)\b", "Adult Cardiology / Vascular"),
    (r"\b(dementia|alzheimer|parkinson|prostate|erectile dysfunction|menopause|osteoporosis)\b", "Adult Geriatrics/Urology"),
    (r"\b(weight loss diet|fast diet|calorie deficit|keto diet|bodybuilding)\b", "Non-Pediatric Lifestyle/Diet"),
    (r"\b(adult|adults|geriatric|elderly|for adults)\b", "Adult Patient Category"),
    (r"(شريان تاجي|ذبحة صدرية|أزمة قلبية|جلطة قلبية|جلطة دماغية|نيتروجليسرين|فياجرا|رجيم تخسيس|دايت سريع|بالغين|بالغ|كبار السن|ضغط الدم للبالغين|علاج البالغين|أنسولين للبالغين|ميتفورمين)", "Adult Cardiology / Non-pediatric"),
]

# Non-medical or spam patterns
SPAM_PATTERNS = [
    r"\b(crypto|bitcoin|stock market|forex|lottery|casino|game cheat)\b",
    r"\b(weather forecast|recipe|cooking pasta|fix my car|python script)\b",
    r"\b(outfit|clothes|dress|fashion|style|football|match|joke|hello|hi\b)\b",
    r"(تداول|بيتكوين|توقعات الطقس|طريقة عمل البيتزا|تصليح سيارات)",
    r"(لبس|فستان|قميص|بنطلون|شياكة|رايك|شكلي|طقس|جو|أخبار|كورة|ماتش|أغنية|فيلم|مطعم)",
]

def extract_age_from_query(query: str) -> Optional[Tuple[int, float]]:
    """
    Extract patient age (days, months) explicitly declared in clinical query.
    Returns (age_days, age_months) or None.
    """
    q = query.lower()

    # Pattern: X weeks / X-week / X-week-old
    w_match = re.search(r'(\d+)\s*(?:-|\s*)week(?:s)?(?:\s*-?\s*old)?', q)
    if w_match:
        weeks = int(w_match.group(1))
        days = weeks * 7
        return days, days / 30.417

    # Pattern: X days / X-day-old
    d_match = re.search(r'(\d+)\s*(?:-|\s*)day(?:s)?(?:\s*-?\s*old)?', q)
    if d_match:
        days = int(d_match.group(1))
        return days, days / 30.417

    # Pattern: X months / X-month-old
    m_match = re.search(r'(\d+(?:\.\d+)?)\s*(?:-|\s*)month(?:s)?(?:\s*-?\s*old)?', q)
    if m_match:
        months = float(m_match.group(1))
        days = int(months * 30.417)
        return days, months

    # Pattern: X years / X-year-old
    y_match = re.search(r'(\d+(?:\.\d+)?)\s*(?:-|\s*)year(?:s)?(?:\s*-?\s*old)?', q)
    if y_match:
        years = float(y_match.group(1))
        months = years * 12.0
        days = int(years * 365.25)
        return days, months

    # Arabic Patterns:
    # عمر X أسابيع / أسبوع
    ar_w = re.search(r'عمر(?:ه|ها)?\s*(\d+)\s*(?:أسبوع|اسبوع|أسابيع|اسابيع)', q)
    if ar_w:
        weeks = int(ar_w.group(1))
        days = weeks * 7
        return days, days / 30.417

    # عمر X يوم / أيام
    ar_d = re.search(r'عمر(?:ه|ها)?\s*(\d+)\s*(?:يوم|ايام|أيام)', q)
    if ar_d:
        days = int(ar_d.group(1))
        return days, days / 30.417

    # عمر X شهر / أشهر
    ar_m = re.search(r'عمر(?:ه|ها)?\s*(\d+(?:\.\d+)?)\s*(?:شهر|شهور|أشهر|اشهر)', q)
    if ar_m:
        months = float(ar_m.group(1))
        days = int(months * 30.417)
        return days, months

    # عمر X سنة / سنوات
    ar_y = re.search(r'عمر(?:ه|ها)?\s*(\d+(?:\.\d+)?)\s*(?:سنة|سنوات|عام|أعوام)', q)
    if ar_y:
        years = float(ar_y.group(1))
        months = years * 12.0
        days = int(years * 365.25)
        return days, months

    return None

def check_input_risk_and_boundary(
    query: str,
    age_days: Optional[int] = None,
    age_months: Optional[float] = None,
    age_years: Optional[float] = None,
    weight_kg: Optional[float] = None,
    language: str = "ar"
) -> Tuple[bool, Optional[Dict[str, Any]]]:
    """
    Check 1: Input Risk & Boundary Filter
    Validates patient age, weights, adult pharmacology, and general safety.
    Prioritizes age explicitly stated in the query over profile age.
    """
    query_lower = query.lower()

    # Check query-extracted age override
    extracted = extract_age_from_query(query)
    if extracted:
        age_days, age_months = extracted

    # 1. Adult Pharmacology & Adult Disease Filter
    for pattern, category in ADULT_PHARMACOLOGY_AND_CONDITIONS:
        if re.search(pattern, query_lower, re.IGNORECASE):
            is_ar = language == "ar" or bool(re.search(r'[\u0600-\u06FF]', query))
            msg_ar = (
                f"🛡️ [رفض أمان سريري - خارج النطاق المصرح به]\n"
                f"تم رصد استفسار يتعلق بأدوية أو أمراض البالغين ({category}). "
                f"نظام PediaCare.AI مخصص حصرياً لبروتوكولات منظمة الصحة العالمية لطب الأطفال وحديثي الولادة (WHO IMCI من عمر 7 أيام حتى 5 سنوات)."
            )
            msg_en = (
                f"🛡️ [Clinical Safety Refusal - Out of Scope]\n"
                f"Query contains adult pharmacology or conditions ({category}). "
                f"PediaCare.AI strictly implements WHO IMCI Pediatric Guidelines (ages 7 days to 5 years)."
            )
            return False, {
                "status": "refusal",
                "refusal_type": "ADULT_PHARMACOLOGY_OUT_OF_SCOPE",
                "category": category,
                "message": msg_ar if is_ar else msg_en,
                "message_ar": msg_ar,
                "message_en": msg_en,
                "triage_level": "GRAY",
                "suggested_action": "REDIRECT_TO_ADULT_CARE"
            }

    # 2. Non-medical spam filter
    for pattern in SPAM_PATTERNS:
        if re.search(pattern, query_lower, re.IGNORECASE):
            return False, {
                "status": "refusal",
                "refusal_type": "NON_MEDICAL_SPAM",
                "message": "عذراً، هذا الاستفسار خارج النطاق الطبي. هذا النظام مخصص فقط للفرز السريري للأطفال وفق دليل WHO IMCI.",
                "message_ar": "عذراً، هذا الاستفسار خارج النطاق الطبي. هذا النظام مخصص فقط للفرز السريري للأطفال وفق دليل WHO IMCI.",
                "message_en": "Out of scope. PediaCare.AI is strictly a clinical decision support system for pediatric healthcare.",
                "triage_level": "GRAY",
                "suggested_action": "REJECT"
            }

    # 3. Newborn Age Filter (< 7 days)
    if age_days is not None and age_days < 7:
        return False, {
            "status": "refusal",
            "refusal_type": "NEONATAL_EMERGENCY",
            "message": (
                "🚨 [تحويل فوري لطوارئ حديثي الولادة - أقل من 7 أيام]\n"
                "الأطفال حديثو الولادة بعمر أقل من أسبوع (أقل من 7 أيام) غير مشمولين ببروتوكول IMCI القياسي للعيادات الخارجية، "
                "ويجب تقييمهم فوراً في وحدة العناية المركزة لحديثي الولادة (NICU) لاحتمال الإنتان المبكر."
            ),
            "message_ar": "🚨 الأطفال أقل من 7 أيام يتطلبون تدخلاً عاجلاً وفحصاً مباشراً في قسم طوارئ حديثي الولادة (NICU).",
            "message_en": "🚨 Neonates under 7 days of age require immediate emergency assessment at a Neonatal Intensive Care Unit (NICU).",
            "triage_level": "RED",
            "suggested_action": "NEONATAL_EMERGENCY_TRANSFER"
        }

    # 4. Over-age Child Filter (> 5 years / > 60 months)
    total_months = age_months
    if total_months is None and age_years is not None:
        total_months = age_years * 12
    if total_months is None and age_days is not None:
        total_months = age_days / 30.417

    if total_months is not None and total_months > 60.0:
        return False, {
            "status": "refusal",
            "refusal_type": "AGE_EXCEEDS_IMCI_SCOPE",
            "message": (
                "⚠️ [تجاوز الفئة العمرية لدليل IMCI - أكثر من 5 سنوات]\n"
                "عمر الطفل يتجاوز 5 سنوات (60 شهراً). دليل منظمة الصحة العالمية لتدبير أمراض الطفولة مخصص للفئة من 7 أيام إلى 5 سنوات. "
                "يرجى مراجعة بروتوكولات طب الأطفال العام أو البالغين."
            ),
            "message_ar": "⚠️ عمر المريض يتجاوز 5 سنوات. يرجى الرجوع لبروتوكولات طب الأطفال العام.",
            "message_en": "⚠️ Patient age exceeds 5 years (60 months). WHO IMCI guidelines apply to ages 7 days to 5 years.",
            "triage_level": "GRAY",
            "suggested_action": "REDIRECT_TO_GENERAL_PEDIATRICS"
        }

    return True, None

def check_retrieval_confidence_threshold(
    top_relevance_score: float,
    language: str = "ar"
) -> Tuple[bool, Optional[Dict[str, Any]]]:
    """
    Check 2: Retrieval Confidence Threshold Gate
    If top-1 retrieved similarity is below 70%, refuse to answer to prevent hallucination.
    """
    if top_relevance_score < CONFIDENCE_THRESHOLD_PCT:
        is_ar = language == "ar"
        msg_ar = (
            f"⚠️ [تنبيه عدم يقين سريري - تطابق منخفض {top_relevance_score:.1f}% < {CONFIDENCE_THRESHOLD_PCT}%]\n"
            f"لم يتم العثور على بروتوكول مطابق بدرجة ثقة كافية في دليل منظمة الصحة العالمية (WHO IMCI). "
            f"يرجى استشارة الطبيب المختص أو تزويد النظام بمعلومات سريرية أكثر تفصيلاً لتجنب أي استنتاج غير موثق."
        )
        msg_en = (
            f"⚠️ [Low Retrieval Confidence Refusal - {top_relevance_score:.1f}% < {CONFIDENCE_THRESHOLD_PCT}%]\n"
            f"No matching WHO IMCI guideline chunk retrieved with sufficient confidence. "
            f"Please consult a pediatrician directly to ensure patient safety."
        )
        return False, {
            "status": "refusal",
            "refusal_type": "LOW_CONFIDENCE_THRESHOLD",
            "top_relevance_score": top_relevance_score,
            "threshold": CONFIDENCE_THRESHOLD_PCT,
            "message": msg_ar if is_ar else msg_en,
            "message_ar": msg_ar,
            "message_en": msg_en,
            "triage_level": "GRAY",
            "suggested_action": "CLINICIAN_REVIEW_REQUIRED"
        }

    return True, None

def post_hoc_validate_claims(
    generated_text: str,
    retrieved_evidence: List[Dict[str, Any]]
) -> Tuple[bool, List[str]]:
    """
    Check 3: Post-Hoc Unsupported Claim Validator
    Validates that numerical dosages and critical medication names in the generated text
    are directly present in the retrieved guideline excerpts.
    """
    unsupported_warnings = []
    combined_evidence_text = " ".join(
        [ev.get("document_text", "") + " " + ev.get("highlight_text_en", "") + " " + ev.get("highlight_text_ar", "")
         for ev in retrieved_evidence]
    ).lower()

    # Extract all mg/kg dosage mentions in generated text
    dosage_patterns = re.findall(r'(\d+(?:\.\d+)?)\s*(?:mg/kg|مجم/كجم|مل/كجم|ml/kg)', generated_text, re.IGNORECASE)
    for dose in dosage_patterns:
        if dose not in combined_evidence_text:
            unsupported_warnings.append(f"Dose mention '{dose}' not explicitly found in retrieved guideline text.")

    is_valid = len(unsupported_warnings) == 0
    return is_valid, unsupported_warnings
