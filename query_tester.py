import os
import time
from dotenv import load_dotenv
import chromadb
from pinecone import Pinecone
from sentence_transformers import SentenceTransformer
from tabulate import tabulate

# تحميل المفاتيح من ملف .env
load_dotenv()

# 1. إعداد ChromaDB (Local Embedded DB)
chroma_client = chromadb.PersistentClient(path="./chroma_db")
chroma_collection = chroma_client.get_or_create_collection(name="imci_clinical_guidelines")

# 2. إعداد Pinecone (Cloud Serverless DB)
PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")
pc = Pinecone(api_key=PINECONE_API_KEY)
pinecone_index = pc.Index("imci-clinical-guidelines")

# 3. نموذج التضمين المشترك
print("🧠 Loading Embedding Model (all-MiniLM-L6-v2)...")
embed_model = SentenceTransformer("all-MiniLM-L6-v2")

MIN_SIMILARITY_THRESHOLD = 43.5  # حد الأمان لنسبة التطابق

test_queries = [
    {
        "id": "TC-01",
        "case": "General Danger Signs",
        "query": "child general danger signs not able to drink vomiting everything convulsions lethargic"
    },
    {
        "id": "TC-02",
        "case": "Severe Pneumonia",
        "query": "child with cough fast breathing and chest indrawing stridor"
    },
    {
        "id": "TC-03",
        "case": "Neonatal Jaundice",
        "query": "young infant with jaundice yellow skin palms and soles"
    },
    {
        "id": "TC-04",
        "case": "Out of Scope (Cardiology)",
        "query": "adult coronary artery disease and nitroglycerin dosage"
    },
    {
        "id": "TC-05",
        "case": "Jaundice Symptoms",
        "query": "symptoms of jaundice"
    }
]


def clean_text_snippet(raw_text: str, max_chars: int = 160) -> str:
    cleaned = (
        raw_text.replace("CLINICAL SECTION:", "")
        .replace("CONTENT:", "")
        .replace("#", "")
        .replace("\n", " ")
        .strip()
    )
    return f"{cleaned[:max_chars]}..." if len(cleaned) > max_chars else cleaned


def run_chroma_query(query_text: str):
    start_time = time.perf_counter()
    results = chroma_collection.query(
        query_texts=[query_text],
        n_results=3,
        include=["documents", "metadatas", "distances"]
    )
    latency_ms = (time.perf_counter() - start_time) * 1000

    if not results or not results["documents"] or not results["documents"][0]:
        return [], 0.0, 0.0, latency_ms

    docs = results["documents"][0]
    metas = results["metadatas"][0]
    dists = results["distances"][0]

    cosine_sims = [1.0 - (d / 2.0) for d in dists]
    match_pcts = [max(0.0, c * 100.0) for c in cosine_sims]

    extracted = []
    for doc, meta, c_sim, pct in zip(docs, metas, cosine_sims, match_pcts):
        extracted.append({
            "text": doc,
            "page": meta.get("page_number", "N/A"),
            "section": meta.get("section_title", "N/A"),
            "cosine_sim": c_sim,
            "match_pct": pct
        })

    best_pct = match_pcts[0]
    avg_pct = sum(match_pcts) / len(match_pcts)
    return extracted, best_pct, avg_pct, latency_ms


def run_pinecone_query(query_text: str):
    start_time = time.perf_counter()
    q_vec = embed_model.encode(query_text).tolist()
    results = pinecone_index.query(vector=q_vec, top_k=3, include_metadata=True)
    latency_ms = (time.perf_counter() - start_time) * 1000

    if not results.matches:
        return [], 0.0, 0.0, latency_ms

    extracted = []
    scores = []
    for match in results.matches:
        score = match.score
        pct = max(0.0, score * 100.0)
        scores.append(pct)
        meta = match.metadata or {}
        extracted.append({
            "text": meta.get("text", ""),
            "page": meta.get("page_number", "N/A"),
            "section": meta.get("section_title", "N/A"),
            "cosine_sim": score,
            "match_pct": pct
        })

    best_pct = scores[0]
    avg_pct = sum(scores) / len(scores)
    return extracted, best_pct, avg_pct, latency_ms


def main_benchmark():
    summary_table = []
    chroma_total_lat, pinecone_total_lat = [], []
    chroma_valid_acc, pinecone_valid_acc = [], []

    print("\n" + "=" * 98)
    print("⚔️ CLINICAL RAG BENCHMARK: ChromaDB (Local) VS Pinecone (Cloud)")
    print(f"📊 Safeguard Threshold: {MIN_SIMILARITY_THRESHOLD}%")
    print("=" * 98)

    for item in test_queries:
        tc_id = item["id"]
        case_name = item["case"]
        query = item["query"]

        print(f"\n{'━' * 98}")
        print(f"📌 [{tc_id}] {case_name}")
        print(f"🔍 Query: \"{query}\"")
        print(f"{'━' * 98}")

        # 1. تشغيل ChromaDB
        c_results, c_best, c_avg, c_lat = run_chroma_query(query)
        c_status = "MATCH" if c_best >= MIN_SIMILARITY_THRESHOLD else "REJECT"
        c_top_page = c_results[0]["page"] if c_results else "N/A"
        chroma_total_lat.append(c_lat)

        print(f"\n💾 [1] ChromaDB (Local):")
        print(f"   ⏱️ Latency: {c_lat:.2f} ms | 📈 Avg Match: {c_avg:.2f}% | 🎯 Top: {c_best:.2f}% | [{c_status}]")
        if c_best >= MIN_SIMILARITY_THRESHOLD:
            for rank, r in enumerate(c_results, start=1):
                snip = clean_text_snippet(r["text"])
                print(f"   👉 Rank [{rank}] | Match: {r['match_pct']:.1f}% | Page: {r['page']} | {snip}")
        else:
            print("   ⛔ Excluded by safety threshold.")

        # 2. تشغيل Pinecone
        p_results, p_best, p_avg, p_lat = run_pinecone_query(query)
        p_status = "MATCH" if p_best >= MIN_SIMILARITY_THRESHOLD else "REJECT"
        p_top_page = p_results[0]["page"] if p_results else "N/A"
        pinecone_total_lat.append(p_lat)

        print(f"\n🌲 [2] Pinecone (Cloud):")
        print(f"   ⏱️ Latency: {p_lat:.2f} ms | 📈 Avg Match: {p_avg:.2f}% | 🎯 Top: {p_best:.2f}% | [{p_status}]")
        if p_best >= MIN_SIMILARITY_THRESHOLD:
            for rank, r in enumerate(p_results, start=1):
                snip = clean_text_snippet(r["text"])
                print(f"   👉 Rank [{rank}] | Match: {r['match_pct']:.1f}% | Page: {r['page']} | {snip}")
        else:
            print("   ⛔ Excluded by safety threshold.")

        # مقارنة الدقة بناءً على المتوسط (Average Match %)
        if abs(c_avg - p_avg) < 0.05:
            acc_winner = "Tie (=)"
        elif c_avg > p_avg:
            acc_winner = "ChromaDB"
        else:
            acc_winner = "Pinecone"

        # مقارنة السرعة
        speed_winner = "ChromaDB" if c_lat < p_lat else "Pinecone"

        if c_best >= MIN_SIMILARITY_THRESHOLD:
            chroma_valid_acc.append(c_avg)
        if p_best >= MIN_SIMILARITY_THRESHOLD:
            pinecone_valid_acc.append(p_avg)

        # إضافة السطر للجدول مع التركيز على المتوسط (Average)
        summary_table.append([
            tc_id,
            case_name,
            f"{c_avg:.2f}%",
            f"{c_lat:.1f} ms",
            f"P.{c_top_page}",
            f"{p_avg:.2f}%",
            f"{p_lat:.1f} ms",
            f"P.{p_top_page}",
            acc_winner,
            speed_winner
        ])

    # طباعة الجدول النهائي
    print("\n" + "=" * 110)
    print("📋 BENCHMARK FINAL SUMMARY (EVALUATION BY AVERAGE MATCH %)")
    print("=" * 110)
    headers = [
        "ID", "Case Name",
        "Chroma Avg", "Chroma Lat", "C.Page",
        "Pinecone Avg", "Pinecone Lat", "P.Page",
        "Avg Winner", "Speed Winner"
    ]
    try:
        print(tabulate(summary_table, headers=headers, tablefmt="rounded_grid"))
    except Exception:
        for row in summary_table:
            print(" | ".join(str(x) for x in row))

    # الإحصائيات العامة
    avg_c_lat = sum(chroma_total_lat) / len(chroma_total_lat)
    avg_p_lat = sum(pinecone_total_lat) / len(pinecone_total_lat)
    avg_c_acc = sum(chroma_valid_acc) / len(chroma_valid_acc) if chroma_valid_acc else 0
    avg_p_acc = sum(pinecone_valid_acc) / len(pinecone_valid_acc) if pinecone_valid_acc else 0

    print("\n" + "─" * 110)
    print(f"📊 Overall Average Latency : 💾 ChromaDB = {avg_c_lat:.1f} ms  |  🌲 Pinecone = {avg_p_lat:.1f} ms")
    print(f"🎯 Overall Average Accuracy: 💾 ChromaDB = {avg_c_acc:.2f}%  |  🌲 Pinecone = {avg_p_acc:.2f}%")
    print("=" * 110 + "\n")


if __name__ == "__main__":
    main_benchmark()