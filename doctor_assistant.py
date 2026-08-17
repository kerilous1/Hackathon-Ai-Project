import os
import re
from dotenv import load_dotenv
import chromadb
from pinecone import Pinecone
from sentence_transformers import SentenceTransformer
from google import genai
from google.genai import types

# تحميل المتغيرات من .env
load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")

ai_client = genai.Client(api_key=GEMINI_API_KEY)
embed_model = SentenceTransformer("all-MiniLM-L6-v2")

# إعداد ChromaDB
chroma_client = chromadb.PersistentClient(path="./chroma_db")
chroma_collection = chroma_client.get_or_create_collection(name="imci_clinical_guidelines")

# إعداد Pinecone
pc = Pinecone(api_key=PINECONE_API_KEY)
pinecone_index = pc.Index("imci-clinical-guidelines")

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

MIN_SIMILARITY_THRESHOLD = 43.5


def execute_genai_call(prompt_text: str, is_translation: bool = False) -> str:
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
    if re.search(r'[\u0600-\u06FF]', user_query):
        print("🌐 جاري تحويل المصطلحات الطبية للبحث الدلالي بالإنجليزية...")
        prompt = f"Translate this clinical scenario into concise medical English search terms: '{user_query}'. Return ONLY the translation without quotes."
        search_query = execute_genai_call(prompt, is_translation=True).strip().replace('"', '')
        print(f"🔄 Search Query (EN): \"{search_query}\"")
        return search_query
    return user_query


def retrieve_from_chroma(query: str, n_results: int = 3):
    results = chroma_collection.query(
        query_texts=[query],
        n_results=n_results,
        include=["documents", "metadatas", "distances"]
    )
    if not results or not results["documents"] or not results["documents"][0]:
        return [], 0.0

    docs = results["documents"][0]
    metas = results["metadatas"][0]
    dists = results["distances"][0]
    
    top_cosine = 1.0 - (dists[0] / 2.0)
    top_pct = max(0.0, top_cosine * 100.0)

    extracted = []
    for doc, meta in zip(docs, metas):
        extracted.append({
            "text": doc,
            "page": meta.get("page_number", "N/A"),
            "section": meta.get("section_title", "General")
        })
    return extracted, top_pct


def retrieve_from_pinecone(query: str, n_results: int = 3):
    query_vector = embed_model.encode(query).tolist()
    results = pinecone_index.query(vector=query_vector, top_k=n_results, include_metadata=True)
    
    if not results.matches:
        return [], 0.0

    top_pct = max(0.0, results.matches[0].score * 100.0)

    extracted = []
    for match in results.matches:
        meta = match.metadata or {}
        extracted.append({
            "text": meta.get("text", ""),
            "page": meta.get("page_number", "N/A"),
            "section": meta.get("section_title", "General")
        })
    return extracted, top_pct


def ask_pedi_guide(doctor_query: str, db_backend: str = "chroma"):
    search_query = prepare_search_query(doctor_query)
    print(f"\n🔍 Searching [{db_backend.upper()}] for: \"{search_query}\"...")

    if db_backend == "pinecone":
        chunks, top_match_pct = retrieve_from_pinecone(search_query)
    else:
        chunks, top_match_pct = retrieve_from_chroma(search_query)

    if not chunks:
        return "⚠️ لم يتم العثور على أي بيانات سريرية مطابقة في قاعدة البيانات."

    # مصد الأمان
    if top_match_pct < MIN_SIMILARITY_THRESHOLD:
        return (
            f"🛡️ [Safeguard Rejection / Out of Scope]\n"
            f"عذراً، هذا الاستفسار خارج نطاق دليل منظمة الصحة العالمية لطب الأطفال (WHO IMCI Guidelines).\n"
            f"نسبة التطابق ({top_match_pct:.1f}%) أقل من الحد الأدنى المقبول ({MIN_SIMILARITY_THRESHOLD}%)."
        )

    context_blocks = []
    for i, item in enumerate(chunks):
        context_blocks.append(
            f"--- EVIDENCE CHUNK [{i+1}] (Page: {item['page']}, Section: {item['section']}) ---\n{item['text']}\n"
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
    print("🩺 PEDI-GUIDE AI - CLINICAL ASSISTANT (MULTI-VECTOR DB SUPPORT)")
    print("==================================================================")
    
    print("\nاختر قاعدة البيانات المتجهة للتشغيل:")
    print(" [1] 💾 ChromaDB (Local Embedded DB)")
    print(" [2] 🌲 Pinecone (Cloud Serverless DB)")
    choice = input("👉 الاختيار (1 أو 2 - الافتراضي 1): ").strip()
    
    db_backend = "pinecone" if choice == "2" else "chroma"
    print(f"✅ تم تفعيل: {db_backend.upper()}\n" + "-" * 66)

    while True:
        query = input("\n📝 أدخل الحالة السريرية (أو 'exit' للخروج): ").strip()
        if query.lower() in ["exit", "quit", "q"]:
            print("إغلاق المساعد الطبي. بالتوفيق!")
            break
        
        if query:
            answer = ask_pedi_guide(query, db_backend=db_backend)
            print("\n" + "=" * 66)
            print(f"📋 CLINICAL RESPONSE [{db_backend.upper()}]:")
            print("=" * 66)
            print(answer)
            print("=" * 66)


if __name__ == "__main__":
    main()