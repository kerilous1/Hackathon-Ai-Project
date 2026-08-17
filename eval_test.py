import chromadb

client = chromadb.PersistentClient(path="./chroma_db")
collection = client.get_or_create_collection(name="imci_clinical_guidelines")

test_cases = [
    {
        "title": "1. Multi-Symptom Critical Case (حمى وصلابة رقبة)",
        "query": "6 month old infant with high fever for 3 days, stiff neck, vomiting and drowsiness"
    },
    {
        "title": "2. Respiratory Distress & Feeding (سعال وضيق تنفس وصعوبة رضاعة)",
        "query": "baby coughing fast breathing blue lips unable to feed"
    },
    {
        "title": "3. Neonatal Jaundice (صفراء في الحديث الولادة)",
        "query": "young infant 2 weeks old yellow skin yellow eyes jaundice"
    },
    {
        "title": "4. Out of Scope Query (مرض بالغين خارج التخصص)",
        "query": "how to treat adult hypertension with captopril 50mg"
    }
]

# حد الأمان الصارم للرفض
DISTANCE_THRESHOLD = 1.10

print("==================================================================")
print("🧪 ACCURACY & PAGE CORRECTION EVALUATION TEST")
print("==================================================================\n")

for test in test_cases:
    print(f"📌 {test['title']}")
    print(f"📝 Query: \"{test['query']}\"")
    
    results = collection.query(
        query_texts=[test['query']],
        n_results=2,
        include=["documents", "metadatas", "distances"]
    )
    
    best_distance = results['distances'][0][0]
    
    if best_distance > DISTANCE_THRESHOLD:
        print(f"⚠️ STATUS: [REJECTED / OUT OF SCOPE] (Distance: {best_distance:.4f})")
        print("   Safeguard triggered: Query outside pediatric IMCI bounds.\n")
    else:
        print(f"✅ STATUS: [MATCH FOUND] (Best Distance: {best_distance:.4f})")
        for i, (doc, meta, dist) in enumerate(zip(results['documents'][0], results['metadatas'][0], results['distances'][0])):
            print(f"   👉 Top [{i+1}] (Dist: {dist:.4f}) | Page: {meta.get('page_number')} | Section: {meta.get('section_title')}")
            snippet = doc.replace("\n", " ")[:150]
            print(f"      Snippet: {snippet}...")
        print()
    print("-" * 66)