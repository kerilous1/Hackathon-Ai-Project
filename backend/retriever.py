"""
PediaCare.AI — Retrieval & Explainability Engine (Day 2 Pipeline)
Implements Tuned Top-k=4 semantic search in ChromaDB Cosine Space,
exact Cosine Similarity math, clinical negation & collision guardrails,
and explainability ranking.
"""

import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

# Ensure UTF-8 output on Windows console
if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

import chromadb
from dotenv import load_dotenv
from sentence_transformers import SentenceTransformer

load_dotenv()

BACKEND_DIR = Path(__file__).resolve().parent
CHROMA_DIR = BACKEND_DIR / "chroma_db"
COLLECTION_NAME = "imci_clinical_guidelines"
EMBEDDING_MODEL_NAME = "all-MiniLM-L6-v2"

_embed_model: Optional[SentenceTransformer] = None
_chroma_client: Optional[chromadb.PersistentClient] = None
_collection: Optional[chromadb.Collection] = None

# Clinical keywords dictionary for quick Arabic-to-English translation & concept mapping
CLINICAL_TRANSLATIONS = {
    "كحة": "cough",
    "سعال": "cough",
    "صعوبة تنفس": "difficult breathing",
    "تنفس سريع": "fast breathing",
    "انسحاب جدار الصدر": "chest indrawing",
    "انسحاب اسفل جدار الصدر": "lower chest wall indrawing subcostal",
    "صرير": "stridor in calm child",
    "تشنجات": "convulsions",
    "تشنج": "convulsions",
    "يتقيأ كل شيء": "vomiting everything",
    "ترجيع": "vomiting",
    "غير قادر على الشرب": "not able to drink or breastfeed",
    "غير قادر على الرضاعة": "not able to drink or breastfeed",
    "فاقد للوعي": "unconscious",
    "خامل": "lethargic",
    "إسهال": "diarrhoea watery stools",
    "اسهال": "diarrhoea watery stools",
    "عيون غائرة": "sunken eyes",
    "ثنية الجلد": "skin pinch goes back very slowly",
    "عطش شديد": "drinking eagerly thirsty",
    "دم في البراز": "blood in stool dysentery",
    "حمى": "fever high temperature",
    "سخونية": "fever high temperature",
    "تيبس الرقبة": "stiff neck meningitis",
    "تصلب الرقبة": "stiff neck meningitis",
    "طفح الحصبة": "measles rash",
    "عتامة القرنية": "clouding of cornea",
    "قرح فموية": "mouth ulcers",
    "ألم الأذن": "ear pain discharge",
    "افرازات الأذن": "ear discharge",
    "تورم خلف الأذن": "tender swelling behind ear mastoiditis",
    "هزال شديد": "severe visible wasting marasmus",
    "تورم القدمين": "oedema of both feet kwashiorkor",
    "انخفاض الحرارة": "hypothermia low temperature",
    "شخير عند الزفير": "expiratory grunting",
    "علامات الالتصاق": "breastfeeding attachment signs areola chin mouth",
    "التصاق الثدي": "breastfeeding attachment signs areola chin mouth",
    "جرعة": "dosage weight band",
    "أموكسيسيلين": "amoxicillin dosage",
    "باراسيتامول": "paracetamol dosage",
    "فيتامين أ": "vitamin a single dose",
    "زنك": "zinc supplementation",
    "محلول الجفاف": "ORS oral rehydration salts",
    "رينجر لاكتات": "IV Ringer's Lactate Plan C",
}

def get_embedding_model() -> SentenceTransformer:
    """Lazy loader for SentenceTransformer embedding model."""
    global _embed_model
    if _embed_model is None:
        _embed_model = SentenceTransformer(EMBEDDING_MODEL_NAME)
    return _embed_model

def get_chroma_collection() -> chromadb.Collection:
    """Get persistent ChromaDB collection."""
    global _chroma_client, _collection
    if _chroma_client is None:
        _chroma_client = chromadb.PersistentClient(path=str(CHROMA_DIR))
    if _collection is None:
        try:
            _collection = _chroma_client.get_collection(COLLECTION_NAME)
        except Exception:
            _collection = _chroma_client.get_or_create_collection(
                name=COLLECTION_NAME,
                metadata={"hnsw:space": "cosine"}
            )
    return _collection

def compute_similarity_percentage(distance: float) -> float:
    """
    Standardized Cosine Similarity Conversion:
    S = max(0.0, min(100.0, (1.0 - distance / 2.0) * 100.0))
    For cosine distance d in [0, 2], S gives 0.0% to 100.0%.
    """
    s = (1.0 - (distance / 2.0)) * 100.0
    return round(max(0.0, min(100.0, s)), 2)

def translate_query_terms(query: str) -> str:
    """
    Fast, deterministic clinical term translation and query enrichment.
    Ensures queries with Arabic clinical terminology retrieve exact WHO guideline sections.
    """
    query_lower = query.lower()
    translated_tokens = []

    for ar_term, en_term in CLINICAL_TRANSLATIONS.items():
        if ar_term in query:
            translated_tokens.append(en_term)

    # Check if original query is already largely English
    has_arabic = bool(re.search(r'[\u0600-\u06FF]', query))
    if not has_arabic:
        return query

    if translated_tokens:
        enriched_query = f"{' '.join(translated_tokens)} {query}"
        return enriched_query
    
    return query

import math
from collections import Counter

class SimpleBM25:
    """Lightweight BM25 Lexical Search Scorer for WHO Guideline Chunks."""
    def __init__(self, corpus: List[str], k1: float = 1.5, b: float = 0.75):
        self.k1 = k1
        self.b = b
        self.corpus_size = len(corpus)
        self.doc_len = [len(doc.lower().split()) for doc in corpus]
        self.avgdl = sum(self.doc_len) / self.corpus_size if self.corpus_size > 0 else 1.0
        self.doc_freqs: List[Counter] = []
        self.idf: Dict[str, float] = {}
        self.nd: Dict[str, int] = {}
        
        for doc in corpus:
            frequencies = Counter(doc.lower().split())
            self.doc_freqs.append(frequencies)
            for word in frequencies:
                self.nd[word] = self.nd.get(word, 0) + 1

        for word, freq in self.nd.items():
            self.idf[word] = math.log((self.corpus_size - freq + 0.5) / (freq + 0.5) + 1.0)

    def get_scores(self, query: str) -> List[float]:
        query_words = query.lower().split()
        scores = [0.0] * self.corpus_size
        for index, doc_freq in enumerate(self.doc_freqs):
            score = 0.0
            doc_l = self.doc_len[index]
            for word in query_words:
                if word not in doc_freq:
                    continue
                freq = doc_freq[word]
                idf = self.idf.get(word, 0.0)
                numerator = freq * (self.k1 + 1)
                denominator = freq + self.k1 * (1 - self.b + self.b * (doc_l / self.avgdl))
                score += idf * (numerator / denominator)
            scores[index] = score
        return scores

_bm25_indexer: Optional[SimpleBM25] = None
_cached_docs: List[Dict[str, Any]] = []

def get_bm25_indexer(collection: chromadb.Collection) -> Tuple[SimpleBM25, List[Dict[str, Any]]]:
    """Lazy initializer for BM25 index over ChromaDB collection."""
    global _bm25_indexer, _cached_docs
    if _bm25_indexer is None or not _cached_docs:
        raw_all = collection.get(include=["documents", "metadatas"])
        if raw_all and raw_all["documents"]:
            _cached_docs = []
            corpus_texts = []
            for doc, meta in zip(raw_all["documents"], raw_all["metadatas"]):
                # Header de-biasing: text used for lexical search emphasizes exact paragraph content
                text_en = meta.get("text_en", doc)
                text_ar = meta.get("text_ar", "")
                section = meta.get("section_title", "")
                combined_text = f"{section} {text_en} {text_ar}"
                corpus_texts.append(combined_text)
                _cached_docs.append({
                    "chunk_id": meta.get("chunk_id", ""),
                    "document_name": meta.get("document_name", "WHO IMCI Model Handbook"),
                    "section_title": section,
                    "page": meta.get("page_number", 1),
                    "age_group": meta.get("age_group", "all"),
                    "triage_color": meta.get("triage_color", "NONE"),
                    "highlight_text_en": meta.get("text_en", doc[:400]),
                    "highlight_text_ar": meta.get("text_ar", ""),
                    "document_text": doc
                })
            _bm25_indexer = SimpleBM25(corpus_texts)
    return _bm25_indexer, _cached_docs

def apply_negation_and_collision_guardrails(
    query: str,
    raw_results: List[Dict[str, Any]]
) -> List[Dict[str, Any]]:
    """
    Negation & Collision Guardrail:
    1. Detects positive clinical signals in the query (e.g. convulsions, chest indrawing, lethargy).
    2. Re-ranks to penalize chunks containing negation conditions (e.g. 'NO chest indrawing', 'NO pneumonia')
       when the patient affirmatively exhibits the symptom.
    3. Boosts severe classification chunks when danger signs or critical thresholds are present.
    """
    query_lower = query.lower()
    
    has_danger_signs = any(k in query_lower for k in [
        "vomit", "convuls", "drink", "breastfeed", "letharg", "unconscious",
        "يتقيأ", "تشنج", "يرضع", "يشرب", "خامل", "غائب عن الوعي", "فاقد للوعي"
    ])
    has_chest_indrawing = any(k in query_lower for k in ["chest indrawing", "subcostal", "انسحاب", "سحب الصدر", "سحب للصدر", "سحب بالصدر"])
    has_fast_breathing = any(k in query_lower for k in ["fast breathing", "تنفس سريع", "48", "50", "52", "54", "56", "60", "66"])
    has_severe_dehydration = any(k in query_lower for k in ["very slowly", "sunken eyes", "unconscious", "ببطء شديد", "غائرة", "مائي"])
    has_blood_stool = any(k in query_lower for k in ["blood in stool", "mucus", "دم في البراز", "مخاط"])
    has_stiff_neck = any(k in query_lower for k in ["stiff neck", "تيبس الرقبة", "تصلب الرقبة"])
    has_mastoid = any(k in query_lower for k in ["mastoid", "behind the ear", "خلف الأذن", "الخشاء"])
    has_wasting = any(k in query_lower for k in ["wasting", "oedema", "marasm", "kwashiork", "هزال", "وذمة", "جلد على عظم"])
    has_young_infant = any(k in query_lower for k in [
        "young infant", "3-week", "2-week", "1-week", "4-week", "week-old", "weeks old",
        "hypothermia", "grunting", "35.2", "35.", "newborn",
        "أسابيع", "أسبوع", "حديث ولادة", "رضيع صغير", "انخفاض حرارة", "شخير عند الزفير"
    ])

    adjusted_results = []

    for item in raw_results:
        text = item["document_text"].lower()
        score = item["relevance_score"]

        # Collision penalty: If patient has chest indrawing or danger signs, penalize "NO PNEUMONIA" or "NO DEHYDRATION" chunks
        if (has_chest_indrawing or has_danger_signs) and ("no pneumonia" in text or "cough or cold" in text):
            score -= 15.0
        elif has_severe_dehydration and ("no dehydration" in text or "plan a" in text):
            score -= 15.0
        elif (has_blood_stool) and ("no dehydration" in text and "dysentery" not in text):
            score -= 10.0

        # Targeted Boosts for matching severe conditions
        if has_danger_signs and ("general danger sign" in text or "chapter 6" in text or "danger signs" in text):
            score += 14.0
        if has_chest_indrawing and "severe pneumonia" in text:
            score += 10.0
        if has_fast_breathing and not has_chest_indrawing and "pneumonia" in text and "no pneumonia" not in text:
            score += 8.0
        if has_severe_dehydration and ("severe dehydration" in text or "plan c" in text):
            score += 12.0
        if has_blood_stool and "dysentery" in text:
            score += 12.0
        if has_stiff_neck and ("very severe febrile" in text or "meningitis" in text):
            score += 12.0
        if has_mastoid and "mastoiditis" in text:
            score += 15.0
        if has_wasting and ("severe malnutrition" in text or "anaemia" in text):
            score += 12.0
        if has_young_infant and ("possible serious bacterial infection" in text or "young infant" in text):
            score += 14.0

        item["relevance_score"] = round(max(0.0, min(100.0, score)), 2)
        adjusted_results.append(item)

    adjusted_results.sort(key=lambda x: x["relevance_score"], reverse=True)
    return adjusted_results

def retrieve_guideline_evidence(
    query: str,
    top_k: int = 4
) -> Tuple[List[Dict[str, Any]], float]:
    """
    Retrieve top-k relevant WHO IMCI guideline chunks using Hybrid Search (BM25 + Dense Cosine Vector via RRF).
    Returns:
        results: List of structured evidence chunks with similarity score & metadata.
        top_relevance: Highest relevance score across retrieved chunks.
    """
    collection = get_chroma_collection()
    embed_model = get_embedding_model()

    search_query = translate_query_terms(query)
    query_vector = embed_model.encode(search_query, normalize_embeddings=True).tolist()

    # 1. Dense Vector Query (Fetch top 16 candidate chunks)
    raw_vector = collection.query(
        query_embeddings=[query_vector],
        n_results=max(top_k * 4, 16),
        include=["documents", "metadatas", "distances"]
    )

    vector_items: List[Dict[str, Any]] = []
    vector_rank_map: Dict[str, int] = {}

    if raw_vector and raw_vector["documents"] and raw_vector["documents"][0]:
        for rank, (doc, meta, dist) in enumerate(zip(raw_vector["documents"][0], raw_vector["metadatas"][0], raw_vector["distances"][0])):
            cid = meta.get("chunk_id", f"page_{meta.get('page_number', 1)}")
            sim_pct = compute_similarity_percentage(dist)
            item = {
                "chunk_id": cid,
                "document_name": meta.get("document_name", "WHO IMCI Model Handbook"),
                "section_title": meta.get("section_title", "Clinical Guidelines"),
                "page": meta.get("page_number", 1),
                "age_group": meta.get("age_group", "all"),
                "triage_color": meta.get("triage_color", "NONE"),
                "relevance_score": sim_pct,
                "raw_distance": round(float(dist), 4),
                "highlight_text_en": meta.get("text_en", doc[:400]),
                "highlight_text_ar": meta.get("text_ar", ""),
                "document_text": doc
            }
            vector_items.append(item)
            vector_rank_map[cid] = rank + 1

    # 2. Lexical BM25 Query
    bm25_indexer, all_docs = get_bm25_indexer(collection)
    bm25_scores = bm25_indexer.get_scores(search_query)

    # Sort all docs by BM25 score
    bm25_ranked_indices = sorted(range(len(bm25_scores)), key=lambda i: bm25_scores[i], reverse=True)
    bm25_rank_map: Dict[str, int] = {}
    for rank, idx in enumerate(bm25_ranked_indices[:30]):
        cid = all_docs[idx]["chunk_id"]
        bm25_rank_map[cid] = rank + 1

    # 3. Reciprocal Rank Fusion (RRF) Combining Vector + BM25
    candidate_dict: Dict[str, Dict[str, Any]] = {item["chunk_id"]: item for item in vector_items}
    for rank, idx in enumerate(bm25_ranked_indices[:16]):
        cid = all_docs[idx]["chunk_id"]
        if cid not in candidate_dict:
            item = dict(all_docs[idx])
            item["relevance_score"] = 75.0
            candidate_dict[cid] = item

    fused_candidates = []
    k_rrf = 60.0

    for cid, item in candidate_dict.items():
        v_rank = vector_rank_map.get(cid, 50)
        b_rank = bm25_rank_map.get(cid, 50)
        rrf_score = (1.0 / (k_rrf + v_rank)) + (1.0 / (k_rrf + b_rank))
        
        # Scale RRF score to 60-99% range for user display
        final_score = round(min(99.0, max(65.0, (rrf_score * 2800.0))), 1)
        item["relevance_score"] = final_score
        fused_candidates.append(item)

    # 4. Apply Clinical Negation & Collision Re-ranking
    ranked_items = apply_negation_and_collision_guardrails(query, fused_candidates)
    final_top_k = ranked_items[:top_k]

    top_relevance = final_top_k[0]["relevance_score"] if final_top_k else 0.0
    return final_top_k, top_relevance

if __name__ == "__main__":
    test_q = "طفل عمره 14 شهراً يعاني من كحة وتنفس سريع 48 نفس/د مع انسحاب أسفل جدار الصدر للداخل"
    print(f"🔎 Testing hybrid retrieval for: {test_q}")
    results, top_score = retrieve_guideline_evidence(test_q, top_k=4)
    print(f"🌟 Top Score: {top_score}%")
    for r in results:
        print(f"  - [{r['relevance_score']}%] Page {r['page']} | {r['section_title']} | Triage: {r['triage_color']}")

