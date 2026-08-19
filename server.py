import os
import re
from typing import List, Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv

load_dotenv()

# Import the hardened RAG pipeline and out-of-scope guard from doctor_assistant
try:
    from doctor_assistant import run_clinical_query, is_out_of_scope_query, prepare_search_query, sanitize_clinical_text, sanitize_section_title
except Exception as e:
    run_clinical_query = None
    is_out_of_scope_query = None
    prepare_search_query = None
    sanitize_clinical_text = lambda x: x
    sanitize_section_title = lambda x: x
    print(f"⚠️ Warning: Could not import from doctor_assistant: {e}")

app = FastAPI(
    title="PediaCare.AI Clinical Backend",
    description="WHO IMCI Clinical Decision Support System REST API",
    version="3.3.0"
)

# Enable CORS for Mobile Emulators, Web & Local Clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ClinicalAssessmentRequest(BaseModel):
    child_name: str
    age_years: float  # Fractional years: 0.17 ≈ 2 months, 0.67 ≈ 8 months, 4.0 = 4 years
    weight_kg: float
    symptoms_text: str
    timeline_days: Optional[int] = 1
    backend: Optional[str] = "chroma"

class EvidenceItem(BaseModel):
    source_title: str
    section: str
    page: str
    relevance_score: float
    highlight_text: str

class DifferentialDiagnosis(BaseModel):
    name: str
    probability: int

class ClinicalAssessmentResponse(BaseModel):
    status: str                         # "success" | "refusal" | "error"
    triage_level: str                   # "RED" | "YELLOW" | "GREEN" | "REFUSAL"
    triage_label_ar: str                # Arabic localized triage string
    summary_found: List[str]            # Identified symptoms list
    missing_info: List[str]             # Differential check questions
    full_recommendation: str            # Verbatim actionable recommendation
    evidence_list: List[EvidenceItem]   # Genuine retrieved WHO IMCI evidence chunks
    differential_diagnoses: List[DifferentialDiagnosis] # Probable conditions

@app.get("/")
def health_check():
    return {
        "status": "online",
        "service": "PediaCare.AI WHO IMCI Clinical API",
        "guideline_standard": "WHO Integrated Management of Childhood Illness (0-5 Years)",
        "version": "3.3.0"
    }

@app.post("/api/v1/assess", response_model=ClinicalAssessmentResponse)
def assess_patient(req: ClinicalAssessmentRequest):
    # Strict WHO IMCI Protocol Age Guardrail (0 to 5 years / 0 to 59 months)
    if req.age_years < 0 or req.age_years > 5.0:
        raise HTTPException(
            status_code=400,
            detail="بروتوكول منظمة الصحة العالمية (IMCI) مخصص حصراً للأطفال من عمر يوم حتى 5 سنوات فقط."
        )

    if req.weight_kg < 2.0 or req.weight_kg > 35.0:
        raise HTTPException(
            status_code=400,
            detail="الوزن يجب أن يكون في النطاق السريري المعتمد للأطفال (من 2.0 كجم إلى 35.0 كجم)."
        )

    # ── 1. HARD PRE-RETRIEVAL OUT-OF-SCOPE & NOISE GUARDRAIL ON RAW SYMPTOMS ──
    raw_symptoms = req.symptoms_text.strip()
    is_invalid_or_oos = (
        (is_out_of_scope_query and is_out_of_scope_query(raw_symptoms))
        or (prepare_search_query and prepare_search_query(raw_symptoms) == "NON_MEDICAL")
    )
    if is_invalid_or_oos:
        return ClinicalAssessmentResponse(
            status="refusal",
            triage_level="REFUSAL",
            triage_label_ar="خارج نطاق التقييم السريري 🛡️",
            summary_found=["الاستفسار المدخل غير طبي، أو يخص أمراض البالغين، أو خارج نطاق بروتوكول الأطفال IMCI."],
            missing_info=[],
            full_recommendation="هذا النظام مخصص حصراً للأعراض السريرية لطب الأطفال وفق دليل منظمة الصحة العالمية (WHO IMCI). يرجى التأكد من إدخال أعراض مرضية واضحة للطفل (أقل من 5 سنوات).",
            evidence_list=[],
            differential_diagnoses=[]
        )

    try:
        combined_query = (
            f"Child: {req.child_name}, Age: {req.age_years} years, Weight: {req.weight_kg} kg. "
            f"Symptoms duration: {req.timeline_days} days. Symptoms and clinical presentation: {req.symptoms_text}"
        )

        raw_result = None
        if run_clinical_query is not None:
            raw_result = run_clinical_query(
                doctor_query=combined_query,
                backend=req.backend or "chroma",
                top_k=4
            )
        else:
            raise HTTPException(status_code=503, detail="RAG system not initialized")

        status = raw_result.get("status", "success")
        triage = raw_result.get("triage_level", "YELLOW")

        # ── 2. POST-RETRIEVAL REFUSAL HANDLING ──
        if triage == "REFUSAL" or status == "refusal":
            refusal_text = raw_result.get("response_text", "")
            if not refusal_text or "STANDARD_REFUSAL" in refusal_text:
                refusal_text = (
                    "لم يتم العثور على معلومات كافية في الدليل الإرشادي المعتمد للإجابة على هذا الاستفسار. "
                    "هذا النظام مخصص فقط للأعراض السريرية لطب الأطفال وفق بروتوكول منظمة الصحة العالمية (WHO IMCI)."
                )

            return ClinicalAssessmentResponse(
                status="refusal",
                triage_level="REFUSAL",
                triage_label_ar="خارج نطاق التقييم السريري 🛡️",
                summary_found=["الاستفسار المدخل غير طبي أو خارج نطاق بروتوكول طب الأطفال IMCI."],
                missing_info=[],
                full_recommendation=refusal_text,
                evidence_list=[],
                differential_diagnoses=[]
            )

        ar_labels = {
            "RED": "خطر عاجل - تحويل فوري للمستشفى 🔴",
            "YELLOW": "يحتاج إلى تقييم طبي (استشارة طبيب) 🟡",
            "GREEN": "لا توجد علامات خطر (رعاية منزلية آمنة) 🟢",
        }

        # ── 3. DYNAMIC WHO IMCI EVIDENCE CHUNKS ──
        evidences: List[EvidenceItem] = []
        for c in raw_result.get("chunks", []):
            score_val = float(c.get("score", 0.0))
            score_pct = max(0.0, min(100.0, score_val))
            clean_sec = sanitize_section_title(c.get("section", "WHO IMCI Guidelines"))
            clean_hl = sanitize_clinical_text(c.get("text", ""))
            evidences.append(EvidenceItem(
                source_title="إرشادات منظمة الصحة العالمية (WHO IMCI)",
                section=f"قسم: {clean_sec}",
                page=f"ص {c.get('page', 'N/A')} من 142",
                relevance_score=round(score_pct, 1),
                highlight_text=clean_hl
            ))

        # Ensure evidence list is strictly sorted descending by numeric relevance score
        evidences.sort(key=lambda e: float(e.relevance_score), reverse=True)

        # ── 4. CLEAN SYMPTOMS SUMMARY (NO BROKEN ARABIC WORD SPLITTING) ──
        found_symptoms = [
            f"مدة الأعراض: {req.timeline_days} أيام" if req.timeline_days and req.timeline_days > 1 else "الأعراض بدأت حديثاً (أقل من 24 ساعة)",
            req.symptoms_text.strip()
        ]

        # ── 5. CONTEXT-AWARE DIFFERENTIAL VERIFICATION QUESTIONS ──
        raw_missing = raw_result.get("differential_questions", [])
        missing_info = [q for q in raw_missing if q.strip()]

        if not missing_info:
            symptoms_lower = req.symptoms_text.lower()
            if "إسهال" in symptoms_lower or "diarrhea" in symptoms_lower:
                missing_info = [
                    "هل يعود ثني جلد البطن ببطء شديد عند الضغط عليه (علامة الجفاف)؟",
                    "هل تبدو عينا الطفل غائرتين أو يشرب الماء بلهفة شديدة؟",
                    "هل يوجد دم أو مخاط ظاهر في البراز؟"
                ]
            elif "كحة" in symptoms_lower or "cough" in symptoms_lower or "تنفس" in symptoms_lower or "breathing" in symptoms_lower or "runny nose" in symptoms_lower or "رشح" in symptoms_lower:
                if triage == "GREEN":
                    missing_info = [
                        "هل يستطيع الطفل الشرب أو الرضاعة بشكل طبيعي دون صعوبة؟",
                        "هل استمرت الكحة أو الرشح لأكثر من 14 يوماً؟",
                        "هل يعاني الطفل من ارتفاع مفاجئ في درجة الحرارة؟"
                    ]
                else:
                    missing_info = [
                        "هل يعاني الطفل من انسحاب أو انغماس جدار الصدر للداخل أثناء التنفس؟",
                        "ما هو معدل التنفس في الدقيقة أثناء هدوء الطفل أو نومه؟",
                        "هل يُسمع صوت صرير (Stridor) أثناء التنفس وهو هادئ؟"
                    ]
            elif "حرارة" in symptoms_lower or "fever" in symptoms_lower:
                missing_info = [
                    "ما هي أعلى درجة حرارة مسجلة للطفل بمقياس الحرارة؟",
                    "هل يعاني الطفل من تيبس بالرقبة أو طفح جلدي نقطي؟",
                    "هل يستطيع الطفل الشرب أو الرضاعة بشكل طبيعي دون قيء مستمر؟"
                ]
            else:
                missing_info = [
                    "هل يستطيع الطفل الشرب أو الرضاعة بشكل طبيعي؟",
                    "هل يوجد خمول غير معتاد أو صعوبة في إيقاظ الطفل؟"
                ]

        # ── 6. DYNAMIC CONDITION-SPECIFIC DIFFERENTIAL DIAGNOSES ──
        symptoms_lower = req.symptoms_text.lower()
        is_danger_sign_case = (
            bool(re.search(r'\b(convulsion|convulsions|convulsing|vomit\s+everything|vomiting\s+everything|not\s+able\s+to\s+drink|lethargic|unconscious)\b', symptoms_lower))
            or any(w in req.symptoms_text for w in ["تشنج", "تشنجات", "يتقيأ كل شيء", "ترجيع كل شيء", "لا يستطيع الشرب", "فاقد للوعي", "خامل جداً"])
        )

        if is_danger_sign_case or (triage == "RED" and not any(w in symptoms_lower for w in ["diarrhea", "إسهال", "cough", "كحة", "تنفس", "breathing"])):
            diff_diag = [
                DifferentialDiagnosis(name="علامات خطورة عامة تستدعي التحويل الفوري (General Danger Signs)", probability=75),
                DifferentialDiagnosis(name="عدوى بكتيرية جهازية شديدة أو التهاب سحائي محتمل", probability=20),
                DifferentialDiagnosis(name="اضطراب شديد في الوعي / نقص سكر الدم", probability=5)
            ]
        elif bool(re.search(r'\b(diarrhea|diarrhoea|stool|stools|dehydration)\b', symptoms_lower)) or "إسهال" in symptoms_lower:
            if triage == "RED":
                diff_diag = [
                    DifferentialDiagnosis(name="جفاف شديد ناتج عن الإسهال (يحتاج سوائل وريدية IV)", probability=75),
                    DifferentialDiagnosis(name="نزلة معوية بكتيرية حادة أو دوسنتاريا", probability=20),
                    DifferentialDiagnosis(name="إنتان معوي حاد", probability=5)
                ]
            elif triage == "YELLOW":
                diff_diag = [
                    DifferentialDiagnosis(name="نزلة معوية مع جفاف متوسط (خطة ب - ORS)", probability=70),
                    DifferentialDiagnosis(name="عدوى فيروسية معوية حادة (Rotavirus)", probability=20),
                    DifferentialDiagnosis(name="عدم تحمل مؤقت لللاكتوز", probability=10)
                ]
            else:
                diff_diag = [
                    DifferentialDiagnosis(name="إسهال بدون جفاف (خطة أ - رعاية منزلية وسوائل)", probability=85),
                    DifferentialDiagnosis(name="تغير غذائي عابر", probability=15)
                ]
        elif bool(re.search(r'\b(cough|breathing|indrawing|stridor|runny\s+nose|cold|pneumonia)\b', symptoms_lower)) or any(w in symptoms_lower for w in ["كحة", "تنفس", "رشح", "زكام", "التهاب رئوي"]):
            if triage == "RED":
                diff_diag = [
                    DifferentialDiagnosis(name="التهاب رئوي حاد وخيم (Severe Pneumonia)", probability=75),
                    DifferentialDiagnosis(name="انسداد مجرى الهواء أو صرير حاد", probability=20),
                    DifferentialDiagnosis(name="أزمة ربو شعبية حادة", probability=5)
                ]
            elif triage == "YELLOW":
                diff_diag = [
                    DifferentialDiagnosis(name="التهاب رئوي يحتاج مضاد حيوي فموي وفحص سريري", probability=60),
                    DifferentialDiagnosis(name="التهاب شعيبات هوائية حاد (Bronchiolitis)", probability=25),
                    DifferentialDiagnosis(name="التهاب الشعب الهوائية الحاد", probability=15)
                ]
            else:
                diff_diag = [
                    DifferentialDiagnosis(name="نزلة برد وسعال خفيف / لا يوجد التهاب رئوي (رعاية منزلية)", probability=85),
                    DifferentialDiagnosis(name="عدوى فيروسية تنفسية بسيطة", probability=15)
                ]
        elif bool(re.search(r'\b(ear|ears|mastoid|otitis)\b', symptoms_lower)) or "أذن" in symptoms_lower:
            diff_diag = [
                DifferentialDiagnosis(name="التهاب الأذن الوسطى الحاد (Acute Otitis Media)", probability=75),
                DifferentialDiagnosis(name="التهاب الأذن الوسطى مع إفرازات صديدية", probability=20),
                DifferentialDiagnosis(name="ألم أذن انعكاسي نتيجة التهاب الحلق", probability=5)
            ]
        else:
            if triage == "RED":
                diff_diag = [
                    DifferentialDiagnosis(name="علامات خطورة عامة تستدعي التحويل الفوري", probability=75),
                    DifferentialDiagnosis(name="عدوى بكتيرية جهازية شديدة", probability=20),
                    DifferentialDiagnosis(name="جفاف شديد أو اضطراب بالوعي", probability=5)
                ]
            elif triage == "GREEN":
                diff_diag = [
                    DifferentialDiagnosis(name="حالة مستقرة / رعاية منزلية مع المتابعة", probability=85),
                    DifferentialDiagnosis(name="أعراض عابرة غير مهددة", probability=15)
                ]
            else:
                diff_diag = [
                    DifferentialDiagnosis(name="عدوى فيروسية شائعة تتطلب فحصاً طبياً", probability=65),
                    DifferentialDiagnosis(name="اشتباه التهاب حلق أو أذن وسطى", probability=20),
                    DifferentialDiagnosis(name="بداية عدوى بكتيرية تحتاج استشارة طبيب", probability=15)
                ]

        return ClinicalAssessmentResponse(
            status=status,
            triage_level=triage,
            triage_label_ar=ar_labels.get(triage, "يحتاج إلى تقييم طبي"),
            summary_found=found_symptoms,
            missing_info=missing_info,
            full_recommendation=raw_result.get("response_text", ""),
            evidence_list=evidences,
            differential_diagnoses=diff_diag
        )
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Server assessment error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("server:app", host="0.0.0.0", port=8000, reload=False)