import chromadb

# 1. الاتصال بقاعدة بيانات ChromaDB المحلية
client = chromadb.PersistentClient(path="./chroma_db")

# 2. استرجاع الـ Collection بالنموذج الافتراضي (نفس ما تم استخدامه في app.py)
collection = client.get_or_create_collection(name="imci_clinical_guidelines")

# حد الأمان للأسئلة الخارجة عن التخصص (Safeguard Threshold)
DISTANCE_THRESHOLD = 1.13

test_queries = [
    {
        "case": "1. General Danger Signs (علامات الخطورة العامة)",
        "query": "child general danger signs not able to drink vomiting everything convulsions lethargic"
    },
    {
        "case": "2. Severe Pneumonia (التهاب رئوي وصعوبة تنفس)",
        "query": "child with cough fast breathing and chest indrawing stridor"
    },
    {
        "case": "3. Jaundice / Yellow skin (الصفراء وحديثي الولادة)",
        "query": "young infant with jaundice yellow skin palms and soles"
    },
    {
        "case": "4. Out of Scope (سؤال خارج التخصص)",
        "query": "adult coronary artery disease and nitroglycerin dosage"
    },
    {
        "case": "5. symptoms of jaundice",
        "query": "symptoms of jaundice"
    }
]

print("==================================================================")
print("🩺 CLINICAL RAG EVALUATION - FULL METADATA & EVIDENCE RETRIEVAL")
print("==================================================================")

# عرض عدد المقاطع المخزنة في قاعدة البيانات للتأكد من القراءة
print(f"📊 Total Chunks in DB: {collection.count()}\n" + "=" * 66)

for item in test_queries:
    query = item["query"]
    print(f"\n📌 Case: {item['case']}")
    print(f"🔍 Search Query: \"{query}\"")
    
    results = collection.query(
        query_texts=[query],
        n_results=3,
        include=["documents", "metadatas", "distances"]
    )
    
    if not results or not results["documents"] or not results["documents"][0]:
        print("⚠️ No matching guidelines found in database.\n" + "=" * 66)
        continue

    best_dist = results['distances'][0][0]
    
    if best_dist > DISTANCE_THRESHOLD:
        print(f"⚠️ [REJECTED / OUT OF SCOPE] Distance: {best_dist:.4f} > {DISTANCE_THRESHOLD}")
        print("   Safeguard: Query does not match pediatric guidelines.\n")
    else:
        print(f"✅ [MATCH FOUND] Best Distance: {best_dist:.4f}")
        for i, (doc, meta, dist) in enumerate(zip(results['documents'][0], results['metadatas'][0], results['distances'][0])):
            print(f"\n   👉 Result [{i+1}] (Distance: {dist:.4f})")
            print(f"   📄 Document   : {meta.get('document_name', 'WHO IMCI Handbook 9241546441')}")
            print(f"   📌 Section    : {meta.get('section_title', 'General Clinical Section')}")
            print(f"   📖 Page Number: Page {meta.get('page_number', 'N/A')}")
            print(f"   📚 Source     : {meta.get('source', 'WHO-UNICEF IMCI Guidelines')}")
            print("   ------------------------------------------------------------")
            
            clean_snippet = (
                doc.replace("CLINICAL SECTION:", "")
                .replace("CONTENT:", "")
                .replace("\n", " ")
                .strip()
            )
            print(f"   💬 DETAILED CLINICAL TEXT:\n   \"{clean_snippet[:400]}...\"")
            print("   ------------------------------------------------------------")
        print()
    print("=" * 66)