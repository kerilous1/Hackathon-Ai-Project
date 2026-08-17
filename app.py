import os
import re
import chromadb
from google import genai
from google.genai import types

# 1. إعداد مفتاح API والعميل
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "AQ.Ab8RN6Lm0MpBXDCzIUT1cuOELwTWL52DJh1CW-ARPujPRU74Rg")
ai_client = genai.Client(api_key=GEMINI_API_KEY)

# قائمة الموديلات المتاحة بالترتيب لضمان التبديل التلقائي عند الضغط (503/429 Fallback)
FALLBACK_MODELS = [
    "gemini-3.5-flash",
    "gemini-3.7-flash",
    "gemini-3.1-flash-lite",
    "gemini-flash-latest"
]

SYSTEM_INSTRUCTION = """
You are an expert WHO IMCI (Integrated Management of Childhood Illness) Clinical Decision Support Assistant.
Your job is to assist healthcare workers by providing STRICTLY GROUNDED clinical classifications, treatments, and assessment steps based ONLY on the provided IMCI context.

Rules:
1. Grounding: Rely strictly on the retrieved text. Do NOT hallucinate or provide medical advice outside the given context.
2. Triage Classification: Clearly state the IMCI color-coded triage level if applicable:
   - 🔴 RED: Urgent pre-referral treatment and immediate hospital referral.
   - 🟡 YELLOW: Specific medical treatment at clinic and home care advice.
   - 🟢 GREEN: Supportive home care, feeding, and fluids.
3. Structure your response clearly:
   - 📋 Clinical Classification & Severity
   - 🚨 Immediate Clinical Actions / Pre-referral Treatments
   - 💊 Specific Dosages / Home Care Instructions (if present in context)
   - 📖 Citations: Reference exact Page numbers and Section titles from the context.
4. Language Requirement: 
   - If the user asks in Arabic, you MUST formulate your entire response in clear, professional Arabic, keeping medical terms in English where appropriate.
   - If the user asks in English, reply in English.
"""

# 2. الاتصال بقاعدة بيانات ChromaDB المحلية
client = chromadb.PersistentClient(path="./chroma_db")
collection = client.get_or_create_collection(name="imci_clinical_guidelines")

DISTANCE_THRESHOLD = 1.15


def execute_genai_call(prompt_text: str, is_translation: bool = False) -> str:
    """تنفيذ استدعاء الذكاء الاصطناعي مع التبديل التلقائي بين الموديلات في حال حدوث 503 أو ضغط"""
    last_err = ""
    for model_name in FALLBACK_MODELS:
        try:
            cfg = None
            if not is_translation:
                cfg = types.GenerateContentConfig(
                    system_instruction=SYSTEM_INSTRUCTION,
                    temperature=0.2,
                )
            
            response = ai_client.models.generate_content(
                model=model_name,
                contents=prompt_text,
                config=cfg
            )
            return response.text
        except Exception as e:
            last_err = str(e)
            if "503" in last_err or "429" in last_err or "UNAVAILABLE" in last_err:
                print(f"⚠️ ضغط على موديل ({model_name})، جاري التبديل للموديل التالي...")
                continue
            else:
                return f"❌ خطأ تقني: {last_err}"
                
    return f"❌ تعذر الاتصال بجميع الموديلات بسبب الضغط المؤقت: {last_err}"


def prepare_search_query(user_query: str) -> str:
    """تحويل الاستفسار العربي إلى مصطلحات طبية إنجليزية للبحث داخل قاعدة البيانات"""
    if re.search(r'[\u0600-\u06FF]', user_query):
        print("🌐 جاري تحويل المصطلحات الطبية للبحث الدلالي بالإنجليزية...")
        prompt = f"Translate this clinical scenario into concise medical English search terms: '{user_query}'. Return ONLY the translation without quotes."
        search_query = execute_genai_call(prompt, is_translation=True).strip().replace('"', '')
        print(f"🔄 Search Query (EN): \"{search_query}\"")
        return search_query
    return user_query


def ask_pedi_guide(doctor_query: str):
    search_query = prepare_search_query(doctor_query)
    
    print(f"\n🔍 Searching IMCI Handbook for: \"{search_query}\"...")

    results = collection.query(
        query_texts=[search_query],
        n_results=3,
        include=["documents", "metadatas", "distances"]
    )

    if not results or not results["documents"] or not results["documents"][0]:
        return "⚠️ لم يتم العثور على أي بيانات سريرية مطابقة في قاعدة البيانات."

    best_dist = results['distances'][0][0]

    # مصد الأمان
    if best_dist > DISTANCE_THRESHOLD:
        return (
            f"🛡️ [Safeguard Rejection / Out of Scope]\n"
            f"عذراً، هذا الاستفسار خارج نطاق دليل منظمة الصحة العالمية لطب الأطفال (WHO IMCI Guidelines).\n"
            f"هذا النظام مخصص فقط لحالات الأطفال وحديثي الولادة (Distance: {best_dist:.4f} > {DISTANCE_THRESHOLD})."
        )

    # تجهيز السياق الطبي وتنسيقه مع أرقام الصفحات
    context_blocks = []
    for i, (doc, meta) in enumerate(zip(results["documents"][0], results["metadatas"][0])):
        page = meta.get("page_number", "N/A")
        section = meta.get("section_title", "General")
        context_blocks.append(
            f"--- EVIDENCE CHUNK [{i+1}] (Page: {page}, Section: {section}) ---\n{doc}\n"
        )

    full_context = "\n".join(context_blocks)

    prompt = f"""
Clinical Question from Doctor:
"{doctor_query}"

Retrieved Official IMCI Evidence Context:
{full_context}

Provide a structured, accurate clinical response with citations based solely on the evidence above. Respond in the same language as the Doctor's Question.
"""

    print("🤖 Generating grounded clinical decision support...\n")
    return execute_genai_call(prompt, is_translation=False)


def main():
    print("=" * 66)
    print("🩺 PEDI-GUIDE AI - CLINICAL ASSISTANT (END-TO-END RAG)")
    print("==================================================================")
    
    while True:
        query = input("\n📝 أدخل الحالة السريرية (أو 'exit' للخروج): ").strip()
        if query.lower() in ["exit", "quit", "q"]:
            print("إغلاق المساعد الطبي. بالتوفيق!")
            break
        
        if query:
            answer = ask_pedi_guide(query)
            print("\n" + "=" * 66)
            print("📋 CLINICAL RESPONSE:")
            print("=" * 66)
            print(answer)
            print("=" * 66)


if __name__ == "__main__":
    main()