"""
PediaCare.AI — FastAPI Production REST Server
Clinical Decision Support System strictly aligned with WHO IMCI Guidelines.
Provides endpoints for Triage Assessment, Explainability Retrieval,
Weight-Band Dosage Calculations, and Plan C IV Fluid Resuscitation.
"""

import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

# Ensure project root is in sys.path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

# Ensure UTF-8 output on Windows console
if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from backend.generator import generate_grounded_assessment
from backend.guardrails import (
    check_input_risk_and_boundary,
    check_retrieval_confidence_threshold,
    post_hoc_validate_claims,
)
from backend.retriever import (
    get_chroma_collection,
    retrieve_guideline_evidence,
)

app = FastAPI(
    title="PediaCare.AI — WHO IMCI Pediatric CDSS API",
    description="Production Clinical Decision Support Engine strictly grounded in WHO IMCI Model Handbook.",
    version="1.0.0",
)

# Enable CORS for Flutter Mobile, Web, and Desktop Clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- REQUEST & RESPONSE SCHEMAS ---

class AssessRequest(BaseModel):
    query: str = Field(..., description="Clinical scenario or symptoms described by caregiver/doctor")
    child_name: Optional[str] = Field(None, description="Child name")
    age_days: Optional[int] = Field(None, description="Age in days")
    age_months: Optional[float] = Field(None, description="Age in months")
    age_years: Optional[float] = Field(None, description="Age in years")
    weight_kg: Optional[float] = Field(None, description="Weight in kilograms")
    gender: Optional[str] = Field("male", description="Gender (male/female)")
    language: Optional[str] = Field("ar", description="Preferred output language (ar/en)")
    api_key: Optional[str] = Field(None, description="Optional custom Gemini API Key")

class RetrieveRequest(BaseModel):
    query: str = Field(..., description="Clinical search terms or symptom query")
    top_k: int = Field(4, description="Number of evidence chunks to retrieve")

class DosageRequest(BaseModel):
    medication: str = Field(..., description="amoxicillin, paracetamol, zinc, vitamin_a, cotrimoxazole")
    weight_kg: float = Field(..., description="Child weight in kg")
    age_months: Optional[float] = Field(None, description="Child age in months")

class IVFluidsRequest(BaseModel):
    weight_kg: float = Field(..., description="Child weight in kg")
    age_months: float = Field(..., description="Child age in months")

# --- ENDPOINTS ---

@app.get("/api/v1/health")
async def health_check():
    """Health check and index statistics."""
    try:
        col = get_chroma_collection()
        chunk_count = col.count()
    except Exception:
        chunk_count = 0

    return {
        "status": "healthy",
        "service": "PediaCare.AI WHO IMCI CDSS Engine",
        "version": "1.0.0",
        "indexed_chunks": chunk_count,
        "supported_age_range": "7 days to 5.0 years",
        "guideline": "WHO IMCI Model Handbook (142 pages)"
    }

@app.post("/api/v1/triage/retrieve")
async def retrieve_evidence_endpoint(payload: RetrieveRequest):
    """Retrieve top-k relevant WHO IMCI evidence chunks with Cosine similarity scores."""
    is_safe, refusal_data = check_input_risk_and_boundary(query=payload.query)
    if not is_safe and refusal_data:
        return {
            "query": payload.query,
            "top_relevance_score": 0.0,
            "evidence_count": 0,
            "evidence": [],
            "refusal": refusal_data
        }

    evidence, top_score = retrieve_guideline_evidence(payload.query, top_k=payload.top_k)
    return {
        "query": payload.query,
        "top_relevance_score": top_score,
        "evidence_count": len(evidence),
        "evidence": evidence
    }

@app.post("/api/v1/triage/assess")
async def assess_clinical_scenario(payload: AssessRequest):
    """
    Full Clinical Assessment Pipeline:
    1. Input Risk & Boundary Filter (Check 1)
    2. Hybrid Retrieval with Cosine Similarity (k=4)
    3. Retrieval Confidence Threshold Gate (Check 2, score >= 70%)
    4. Grounded Generation with Recommendation-Excerpt-Citation Triad
    5. Post-Hoc Claim Validation (Check 3)
    """
    # Check 1: Input Risk & Boundary Filter
    is_safe, refusal_data = check_input_risk_and_boundary(
        query=payload.query,
        age_days=payload.age_days,
        age_months=payload.age_months,
        age_years=payload.age_years,
        weight_kg=payload.weight_kg,
        language=payload.language or "ar"
    )
    if not is_safe and refusal_data:
        return refusal_data

    # Step 2: Evidence Retrieval
    evidence, top_relevance = retrieve_guideline_evidence(payload.query, top_k=4)

    # Check 2: Retrieval Confidence Threshold Gate
    passes_conf, conf_refusal = check_retrieval_confidence_threshold(
        top_relevance_score=top_relevance,
        language=payload.language or "ar"
    )
    if not passes_conf and conf_refusal:
        return conf_refusal

    # Step 3: Grounded Generation
    patient_context = {
        "name": payload.child_name,
        "age": f"{payload.age_months}m" if payload.age_months else (f"{payload.age_days}d" if payload.age_days else "N/A"),
        "weight_kg": payload.weight_kg,
        "gender": payload.gender
    }

    assessment = generate_grounded_assessment(
        clinical_query=payload.query,
        retrieved_evidence=evidence,
        patient_context=patient_context,
        api_key=payload.api_key
    )

    # Check 3: Post-Hoc Claim Validation
    is_valid, validation_warnings = post_hoc_validate_claims(
        generated_text=assessment.get("full_recommendation", ""),
        retrieved_evidence=evidence
    )
    assessment["safety_validation"] = {
        "is_valid": is_valid,
        "warnings": validation_warnings
    }

    return assessment

@app.post("/api/v1/calculator/dosage")
async def calculate_medication_dosage(payload: DosageRequest):
    """
    Discrete Weight-Band Dosing Calculator strictly aligned with WHO IMCI Tables.
    """
    med = payload.medication.lower().strip()
    w = payload.weight_kg
    m = payload.age_months

    if med == "amoxicillin":
        if w < 4.0:
            return {
                "status": "warning",
                "medication": "Amoxicillin Oral Suspension (125mg / 5ml)",
                "weight_kg": w,
                "dosage_bracket": "Below 4 kg bracket",
                "recommendation": "الوزن أقل من 4 كجم. يمنع إعطاء المضادات الحيوية الفموية بدون إشراف. يطبق بروتوكول الرضع الصغار (حقن عضلية Ampicillin + Gentamicin).",
                "volume_ml": 0.0,
                "frequency": "N/A",
                "duration_days": 0
            }
        elif w < 10.0:  # 4 - <10 kg (2m - 11m)
            return {
                "status": "success",
                "medication": "Amoxicillin Oral Suspension (125mg / 5ml)",
                "weight_kg": w,
                "dosage_bracket": "4 to <10 kg (approx 2–11 months)",
                "dose_mg": 125,
                "volume_ml": 5.0,
                "frequency": "مرتان يومياً (كل 12 ساعة) / Twice daily",
                "duration_days": 5,
                "instructions_ar": "أعط 5 مل مرتين يومياً لمدة 5 أيام.",
                "instructions_en": "Give 5.0 ml twice daily for 5 days.",
                "citation": "WHO IMCI Model Handbook, Section 21.1, Page 91"
            }
        else:  # 10 - 19 kg (12m - 5y)
            return {
                "status": "success",
                "medication": "Amoxicillin Oral Suspension (125mg / 5ml)",
                "weight_kg": w,
                "dosage_bracket": "10 to 19 kg (approx 12 months to 5 years)",
                "dose_mg": 250,
                "volume_ml": 10.0,
                "frequency": "مرتان يومياً (كل 12 ساعة) / Twice daily",
                "duration_days": 5,
                "instructions_ar": "أعط 10 مل مرتين يومياً لمدة 5 أيام.",
                "instructions_en": "Give 10.0 ml twice daily for 5 days.",
                "citation": "WHO IMCI Model Handbook, Section 21.1, Page 91"
            }

    elif med == "paracetamol":
        if w < 4.0:
            vol = 1.25
            dose = 30
            bracket = "< 4 kg"
        elif w < 6.0:
            vol = 2.5
            dose = 60
            bracket = "4 to <6 kg (2–5 months)"
        elif w < 10.0:
            vol = 5.0
            dose = 120
            bracket = "6 to <10 kg (6–11 months)"
        elif w < 14.0:
            vol = 7.5
            dose = 180
            bracket = "10 to <14 kg (1–2 years)"
        else:
            vol = 10.0
            dose = 240
            bracket = "14 to 19 kg (3–5 years)"

        return {
            "status": "success",
            "medication": "Paracetamol Syrup (120mg / 5ml)",
            "weight_kg": w,
            "dosage_bracket": bracket,
            "dose_mg": dose,
            "volume_ml": vol,
            "frequency": "كل 6 ساعات عند اللزوم (بحد أقصى 4 مرات يومياً)",
            "instructions_ar": f"أعط {vol} مل كل 6 ساعات عند ارتفاع الحرارة فوق 38.5 درجة مئوية أو لتسكين الألم.",
            "instructions_en": f"Give {vol} ml every 6 hours as needed for high fever (>=38.5C) or pain.",
            "citation": "WHO IMCI Model Handbook, Section 21.2, Page 93"
        }

    elif med == "zinc":
        is_under_6m = (m is not None and m < 6.0) or (w < 6.0)
        dose = 10 if is_under_6m else 20
        bracket = "< 6 months (10mg)" if is_under_6m else ">= 6 months to 5y (20mg)"

        return {
            "status": "success",
            "medication": "Zinc Supplementation (20mg Dispersible Tablet)",
            "weight_kg": w,
            "dosage_bracket": bracket,
            "dose_mg": dose,
            "tablets_per_day": 0.5 if is_under_6m else 1.0,
            "duration_days": 14,
            "instructions_ar": f"أعط {dose} مجم يومياً (قرص {'نصف' if is_under_6m else 'كامل'} يذاب في ماء أو حليب أم) لمدة 14 يوماً متواصلة.",
            "instructions_en": f"Give {dose} mg daily ({'1/2' if is_under_6m else '1'} tablet dissolved in breastmilk/water) for 14 continuous days.",
            "citation": "WHO IMCI Model Handbook, Section 21.4, Page 99"
        }

    elif med == "vitamin_a":
        if m is not None and m < 6.0:
            units = 50000
            bracket = "< 6 months"
        elif m is not None and m < 12.0:
            units = 100000
            bracket = "6 to 11 months"
        else:
            units = 200000
            bracket = "12 months to 5 years"

        return {
            "status": "success",
            "medication": "Vitamin A High-Dose Capsule",
            "weight_kg": w,
            "dosage_bracket": bracket,
            "dose_iu": units,
            "instructions_ar": f"جرعة واحدة فورية بالفم بمقدار {units:,} وحدة دولية.",
            "instructions_en": f"Single oral dose of {units:,} IU.",
            "citation": "WHO IMCI Model Handbook, Section 21.3, Page 95"
        }

    raise HTTPException(status_code=400, detail=f"Unsupported medication: '{med}'. Supported: amoxicillin, paracetamol, zinc, vitamin_a")

@app.post("/api/v1/calculator/iv-fluids")
async def calculate_plan_c_iv_fluids(payload: IVFluidsRequest):
    """
    WHO IMCI Plan C Severe Dehydration IV Fluid Calculator (Ringer's Lactate 100 ml/kg).
    """
    w = payload.weight_kg
    m = payload.age_months

    total_fluid_ml = round(w * 100.0, 1)
    stage1_ml = round(w * 30.0, 1)
    stage2_ml = round(w * 70.0, 1)

    if m < 12.0:
        stage1_time_hours = 1.0
        stage2_time_hours = 5.0
        total_time_hours = 6.0
        stage1_desc = "30 ml/kg in 1 hour"
        stage2_desc = "70 ml/kg in 5 hours"
        reassess_stage1_min = 60
    else:
        stage1_time_hours = 0.5
        stage2_time_hours = 2.5
        total_time_hours = 3.0
        stage1_desc = "30 ml/kg in 30 minutes"
        stage2_desc = "70 ml/kg in 2.5 hours"
        reassess_stage1_min = 30

    # Calculate drip rates (drops/min) using standard IV giving set (20 drops/ml) and Microdrip (60 drops/ml)
    # Stage 1 drops/min: (volume_ml * drops_per_ml) / (time_in_minutes)
    stage1_min = stage1_time_hours * 60.0
    stage1_gtt_20 = round((stage1_ml * 20.0) / stage1_min)
    stage1_gtt_60 = round((stage1_ml * 60.0) / stage1_min)

    stage2_min = stage2_time_hours * 60.0
    stage2_gtt_20 = round((stage2_ml * 20.0) / stage2_min)
    stage2_gtt_60 = round((stage2_ml * 60.0) / stage2_min)

    return {
        "status": "success",
        "protocol": "WHO IMCI Plan C (Severe Dehydration IV Resuscitation)",
        "fluid_type": "Ringer's Lactate Solution (or Normal Saline 0.9% if RL unavailable)",
        "weight_kg": w,
        "age_months": m,
        "age_bracket": "Infant < 12 months (Total 6 hours)" if m < 12.0 else "Child >= 12 months (Total 3 hours)",
        "total_volume_ml": total_fluid_ml,
        "total_duration_hours": total_time_hours,
        "stage_1": {
            "description": stage1_desc,
            "volume_ml": stage1_ml,
            "duration_hours": stage1_time_hours,
            "drip_rate_standard_20gtt": f"{stage1_gtt_20} قطرة/دقيقة (drops/min)",
            "drip_rate_microdrip_60gtt": f"{stage1_gtt_60} نقطة ميكرو/دقيقة",
            "action_ar": f"أعط {stage1_ml} مل من رينجر لاكتات خلال {int(stage1_min)} دقيقة، ثم افحص النبض وتروية الأطراف.",
            "reassess_after_minutes": reassess_stage1_min
        },
        "stage_2": {
            "description": stage2_desc,
            "volume_ml": stage2_ml,
            "duration_hours": stage2_time_hours,
            "drip_rate_standard_20gtt": f"{stage2_gtt_20} قطرة/دقيقة (drops/min)",
            "drip_rate_microdrip_60gtt": f"{stage2_gtt_60} نقطة ميكرو/دقيقة",
            "action_ar": f"أعط {stage2_ml} مل من رينجر لاكتات خلال {stage2_time_hours} ساعات. افحص الطفل كل 1-2 ساعة.",
            "reassess_interval_hours": 1.0 if m < 12.0 else 1.0
        },
        "critical_notes_ar": "إذا كان النبض ضعيفاً جداً أو غير محسوس، كرر إعطاء المرحلة الأولى (30 مل/كجم) بسرعة. أعط محلول ORS بالملعقة (5 مل/كجم/ساعة) بمجرد أن يستطيع الطفل الشرب.",
        "citation": "WHO IMCI Model Handbook, Plan C: Treat Severe Dehydration Quickly, Page 28, 143"
    }

if __name__ == "__main__":
    import uvicorn
    print("🚀 Launching PediaCare.AI Backend REST Server on port 8000...")
    uvicorn.run("backend.server:app", host="0.0.0.0", port=8000, reload=False)
