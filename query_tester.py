import os
import time
import chromadb
from pinecone import Pinecone
from sentence_transformers import SentenceTransformer
from tabulate import tabulate

# 1. إعداد ChromaDB (Local Embedded DB)
chroma_client = chromadb.PersistentClient(path="./chroma_db")
chroma_collection = chroma_client.get_or_create_collection(name="imci_clinical_guidelines")

# 2. إعداد Pinecone (Cloud Serverless DB)
PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")
pc = Pinecone(api_key=PINECONE_API_KEY)
pinecone_index = pc.Index("imci-clinical-guidelines")

# 3. نموذج التضمين المشترك
print("🧠 تحميل نموذج التضمين (all-MiniLM-L6-v2)...")
embed_model = SentenceTransformer("all-MiniLM-L6-v2")

MIN_SIMILARITY_THRESHOLD = 43.5  # حد الأمان لنسبة التطابق

test_queries = [
    {
        "id": "TC-01",
        "case": "General Danger Signs (علامات الخطورة العامة)",
        "query": "child general danger signs not able to drink vomiting everything convulsions lethargic"
    },
    {
        "id": "TC-02",
        "case": "Severe Pneumonia (التهاب رئوي وصعوبة تنفس)",
        "query": "child with cough fast breathing and chest indrawing stridor"
    },
    {
        "id": "TC-03",
        "case": "Neonatal Jaundice (الصفراء وحديثي الولادة)",
        "query": "young infant with jaundice yellow skin palms and soles"
    },
    {
        "id": "TC-04",
        "case": "Out of Scope (سؤال خارج التخصص - أمراض قلب)",
        "query": "adult coronary artery disease and nitroglycerin dosage"
    },
    {
        "id": "TC-05",
        "case": "Jaundice Symptoms (أعراض الصفراء العامة)",
        "query": "symptoms of jaundice"
    }
]


def clean_text_snippet(raw_text: str, max_chars: int = 180) -> str:
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

    # تحويل مسافة L2 Squared إلى Cosine Similarity ونسبة مئوية
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
    # توليد التضمين + الاستعلام السحابي
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
        c_status = "✅ MATCHED" if c_best >= MIN_SIMILARITY_THRESHOLD else "🛡️ REJECTED"
        c_top_page = c_results[0]["page"] if c_results else "N/A"
        chroma_total_lat.append(c_lat)

        print(f"\n💾 [1] ChromaDB (Local):")
        print(f"   ⏱️ Latency: {c_lat:.2f} ms | 🎯 Top Match: {c_best:.1f}% | 📈 Avg: {c_avg:.1f}% | {c_status}")
        if c_best >= MIN_SIMILARITY_THRESHOLD:
            for rank, r in enumerate(c_results, start=1):
                snip = clean_text_snippet(r["text"])
                print(f"   👉 Rank [{rank}] | Match: {r['match_pct']:.1f}% (Sim: {r['cosine_sim']:.4f}) | Page: {r['page']}")
                print(f"      Section: {r['section']}")
                print(f"      Snippet: \"{snip}\"")
        else:
            print("   ⛔ مستبعد بمصد الأمان لخروجه عن نطاق طب الأطفال.")

        # 2. تشغيل Pinecone
        p_results, p_best, p_avg, p_lat = run_pinecone_query(query)
        p_status = "✅ MATCHED" if p_best >= MIN_SIMILARITY_THRESHOLD else "🛡️ REJECTED"
        p_top_page = p_results[0]["page"] if p_results else "N/A"
        pinecone_total_lat.append(p_lat)

        print(f"\n🌲 [2] Pinecone (Cloud):")
        print(f"   ⏱️ Latency: {p_lat:.2f} ms | 🎯 Top Match: {p_best:.1f}% | 📈 Avg: {p_avg:.1f}% | {p_status}")
        if p_best >= MIN_SIMILARITY_THRESHOLD:
            for rank, r in enumerate(p_results, start=1):
                snip = clean_text_snippet(r["text"])
                print(f"   👉 Rank [{rank}] | Match: {r['match_pct']:.1f}% (Sim: {r['cosine_sim']:.4f}) | Page: {r['page']}")
                print(f"      Section: {r['section']}")
                print(f"      Snippet: \"{snip}\"")
        else:
            print("   ⛔ مستبعد بمصد الأمان لخروجه عن نطاق طب الأطفال.")

        # مقارنة سريعة للحالة الحالية
        speed_diff = abs(c_lat - p_lat)
        faster = "ChromaDB" if c_lat < p_lat else "Pinecone"
        page_agree = "✅ متطابق" if c_top_page == p_top_page else "⚠️ مختلف"
        print(f"\n⚖️ مقارنة الحالة [{tc_id}]: الأسرع هو {faster} بفارق ({speed_diff:.1f} ms) | رقم الصفحة المسترجعة: {page_agree} (P.{c_top_page} vs P.{p_top_page})")

        if c_best >= MIN_SIMILARITY_THRESHOLD:
            chroma_valid_acc.append(c_avg)
        if p_best >= MIN_SIMILARITY_THRESHOLD:
            pinecone_valid_acc.append(p_avg)

        # إضافة البيانات للجدول النهائي
        summary_table.append([
            tc_id,
            case_name[:24],
            f"{c_best:.1f}%",
            f"{c_lat:.1f} ms",
            f"P.{c_top_page}",
            f"{p_best:.1f}%",
            f"{p_lat:.1f} ms",
            f"P.{p_top_page}",
            faster
        ])

    # طباعة الجدول النهائي الشامل
    print("\n" + "=" * 105)
    print("📋 BENCHMARK FINAL SUMMARY: HEAD-TO-HEAD COMPARISON")
    print("=" * 105)
    headers = [
        "ID", "Case Name",
        "Chroma Match", "Chroma Latency", "Chroma Page",
        "Pinecone Match", "Pinecone Latency", "Pinecone Page",
        "Speed Winner"
    ]
    try:
        print(tabulate(summary_table, headers=headers, tablefmt="rounded_grid"))
    except Exception:
        for row in summary_table:
            print(" | ".join(str(x) for x in row))

    # طباعة الإحصائيات الختامية
    avg_c_lat = sum(chroma_total_lat) / len(chroma_total_lat)
    avg_p_lat = sum(pinecone_total_lat) / len(pinecone_total_lat)
    avg_c_acc = sum(chroma_valid_acc) / len(chroma_valid_acc) if chroma_valid_acc else 0
    avg_p_acc = sum(pinecone_valid_acc) / len(pinecone_valid_acc) if pinecone_valid_acc else 0

    print("\n" + "─" * 105)
    print(f"📊 Overall Average Latency : 💾 ChromaDB = {avg_c_lat:.1f} ms  |  🌲 Pinecone = {avg_p_lat:.1f} ms")
    print(f"🎯 Overall Valid Accuracy : 💾 ChromaDB = {avg_c_acc:.2f}%  |  🌲 Pinecone = {avg_p_acc:.2f}%")
    print("=" * 105 + "\n")


if __name__ == "__main__":
    main_benchmark()