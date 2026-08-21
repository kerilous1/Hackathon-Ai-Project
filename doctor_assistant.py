"""
DOCTOR ASSISTANT — Strict Grounded WHO IMCI RAG System
"""

import os
import re
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import chromadb
from dotenv import load_dotenv
from google import genai
from google.genai import types

load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "").strip()
ai_client = genai.Client(api_key=GEMINI_API_KEY)

_embed_model: Optional[Any] = None

def get_embedding_model() -> Any:
    global _embed_model
    if _embed_model is None:
        from sentence_transformers import SentenceTransformer
        _embed_model = SentenceTransformer("all-MiniLM-L6-v2")
    return _embed_model

PROJECT_ROOT = Path(__file__).resolve().parent
chroma_client = chromadb.PersistentClient(path=str(PROJECT_ROOT / "chroma_db"))
try:
    chroma_collection = chroma_client.get_collection(name="imci_clinical_guidelines")
except Exception:
    chroma_collection = chroma_client.create_collection(name="imci_clinical_guidelines")

CONFIDENCE_THRESHOLD = 0.35  # Threshold for refusal

STRICT_SYSTEM_INSTRUCTION = """\
You are an expert WHO IMCI (Integrated Management of Childhood Illness) Clinical Decision Support Engine.
Your primary rule: Answer ONLY based on the text provided inside <retrieved_evidence>. Do NOT use outside medical knowledge. Do NOT guess.

Format your response strictly in Arabic using these 4 sections exactly:
1. 📋 التوصية السريرية (Recommendation): A clear clinical recommendation based ONLY on the evidence. Use 🔴, 🟡, or 🟢 to indicate triage level.
2. 📖 الأدلة المقتبسة (Excerpt): Exact verbatim quote or summary of the supporting retrieved text.
3. 🏷️ التوثيق (Citation): Must be in the format [Document Name, Section X, Page N]. Use the metadata provided in the chunks.
4. 🔎 أسئلة التحقق (Verification Questions): 1-2 questions to ask the user if the context is ambiguous or insufficient. Each starting with "• هل ". If the case is perfectly clear, still provide a follow-up question related to the evidence.
"""

STANDARD_REFUSAL = (
    "لم أتمكن من العثور على معلومات كافية في الأدلة الإرشادية (WHO IMCI) للإجابة بثقة على هذا الاستفسار. "
    "يرجى استشارة طبيب أو إعادة صياغة السؤال بمزيد من التفاصيل."
)

def execute_llm_call(prompt_text: str, is_translation: bool = False, api_key: Optional[str] = None) -> str:
    client = ai_client
    if api_key and api_key.strip():
        client = genai.Client(api_key=api_key.strip())

    try:
        cfg = None
        if not is_translation:
            cfg = types.GenerateContentConfig(
                system_instruction=STRICT_SYSTEM_INSTRUCTION,
                temperature=0.0,
            )
        else:
            cfg = types.GenerateContentConfig(temperature=0.0)
            
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt_text,
            config=cfg,
        )
        return response.text if response and response.text else STANDARD_REFUSAL
    except Exception as e:
        return f"❌ Model error: {str(e)}"

def translate_query_to_english(query: str) -> str:
    """Translate Arabic query to English for semantic search in the English PDF."""
    if not re.search(r'[\u0600-\u06FF]', query):
        return query
    prompt = f"Translate the following pediatric medical query from Arabic to English to be used for a semantic search engine. Return ONLY the English translation without any extra words: '{query}'"
    res = execute_llm_call(prompt, is_translation=True).strip()
    # Strip any markdown or quotes
    res = re.sub(r'^[\'"]|[\'"]$', '', res)
    return res

def retrieve_evidence(
    query: str,
    top_k: int = 4
) -> Tuple[List[Dict[str, Any]], float]:
    """Pure Cosine Similarity Semantic Search (Day 2)"""
    english_query = translate_query_to_english(query)
    
    embed_model = get_embedding_model()
    q_vec = embed_model.encode(english_query).tolist()

    res = chroma_collection.query(
        query_embeddings=[q_vec],
        n_results=top_k,
        include=["documents", "metadatas", "distances"],
    )
    if not res or not res["documents"] or not res["documents"][0]:
        return [], 0.0

    docs = res["documents"][0]
    metas = res["metadatas"][0]
    dists = res["distances"][0]

    final_chunks = []
    top_score = 0.0
    
    for doc, meta, dist in zip(docs, metas, dists):
        # Exact Cosine similarity percentage: S = max(0.0, min(100.0, (1.0 - (d / 2.0)) * 100.0))
        dist_val = float(dist)
        sim_pct = max(0.0, min(100.0, (1.0 - (dist_val / 2.0)) * 100.0))
        sim_norm = sim_pct / 100.0
        if sim_norm > top_score:
            top_score = sim_norm
        
        final_chunks.append({
            "text": doc,
            "page": meta.get("page_number", "N/A"),
            "section": meta.get("section_title", "General"),
            "document_name": meta.get("document_name", "WHO IMCI Guidelines"),
            "score": round(sim_norm, 3),
            "score_pct": round(sim_pct, 1)
        })
        
    return final_chunks, top_score

def ask_doctor_assistant(user_query: str) -> Dict[str, Any]:
    """Main pipeline combining Day 2 Retrieval, Day 4 Safety, Day 3 Generation."""
    # Day 4: Guardrails
    chunks, top_score = retrieve_evidence(user_query, top_k=4)
    
    result = {
        "status": "success",
        "triage_level": "YELLOW", # Default triage
        "response_text": "",
        "chunks": chunks,
        "top_score": top_score,
        "confidence": "HIGH" if top_score >= 0.50 else ("MEDIUM" if top_score >= 0.35 else "LOW"),
        "search_query": user_query,
        "cited_pages": [],
        "differential_questions": []
    }
    
    if top_score < CONFIDENCE_THRESHOLD:
        result["status"] = "refusal"
        result["triage_level"] = "REFUSAL"
        result["response_text"] = STANDARD_REFUSAL
        return result
        
    evidence_text = ""
    for c in chunks:
        evidence_text += f"\n--- Document: {c['document_name']} | Section: {c['section']} | Page: {c['page']} ---\n{c['text']}\n"

    prompt = f"""
User Query: {user_query}

<retrieved_evidence>
{evidence_text}
</retrieved_evidence>

Answer the user query based ONLY on the evidence above in Arabic. If the evidence does not answer the query, say you don't know and refuse to answer.
"""
    response_text = execute_llm_call(prompt)
    
    result["response_text"] = response_text
    
    # Extract cited pages
    matches = re.findall(r"(?:Page|page|ص|صفحة)[\s:]*(\d+)", response_text)
    pages = [int(m) for m in set(matches)]
    result["cited_pages"] = pages
    
    # Extract triage level
    if "🔴" in response_text:
        result["triage_level"] = "RED"
    elif "🟢" in response_text:
        result["triage_level"] = "GREEN"
    elif "🟡" in response_text:
        result["triage_level"] = "YELLOW"
    
    # Extract verification questions
    questions = []
    lines = response_text.split('\n')
    for line in lines:
        if line.strip().startswith('• هل') or line.strip().startswith('- هل'):
            clean_q = re.sub(r'^[•\-\*]\s*', '', line.strip())
            questions.append(clean_q)
            
    result["differential_questions"] = questions
    
    return result

if __name__ == "__main__":
    q = "ما هي علامات الجفاف الشديد وكيف نعالجه؟"
    res = ask_doctor_assistant(q)
    print(res["response_text"])
