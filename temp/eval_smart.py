import chromadb
import re

client = chromadb.PersistentClient(path="./chroma_db")
collection = client.get_or_create_collection(name="imci_clinical_guidelines")

def detect_age_group(query):
    q_lower = query.lower()
    # حديثي الولادة حتى عمر شهرين
    if any(term in q_lower for term in ["2 week", "3 week", "1 week", "2 weeks", "3 weeks", "newborn", "neonate", "young infant", "1 month"]):
        return "YOUNG_INFANT"
    # الأطفال من شهرين حتى 5 سنوات
    elif any(term in q_lower for term in ["6 month", "month", "months", "year", "years", "toddler", "child"]):
        return "CHILD"
    return "GENERAL"

test_cases = [
    {
        "title": "1. Multi-Symptom Critical Case (طفل 6 أشهر - حمى وصلابة رقبة)",
        "query": "6 month old infant with high fever for 3 days, stiff neck, vomiting and drowsiness"
    },
    {
        "title": "2. Respiratory Distress & Feeding (سعال وضيق تنفس وعلامات خطورة)",
        "query": "baby coughing fast breathing blue lips unable to feed"
    },
    {
        "title": "3. Neonatal Jaundice (رضيع أسبوعين - صفراء في الجلد والعين)",
        "query": "young infant 2 weeks old yellow skin yellow eyes jaundice palms soles"
    },
    {
        "title": "4. Out of Scope Query (ضغط الدم للبالغين - خارج النطاق)",
        "query": "how to treat adult hypertension with captopril 50mg"
    },
    {
        "title": "5. what are the general danger signs in sick child",
        "query": "what are the general danger signs in sick child"
    },
]

DISTANCE_THRESHOLD = 1.10

print("==================================================================")
print("🧠 OPTIMIZED CLINICAL RETRIEVAL & ACCURACY BENCHMARK")
print("==================================================================\n")

for test in test_cases:
    query = test['query']
    age_group = detect_age_group(query)
    
    print(f"📌 {test['title']}")
    print(f"📝 Query: \"{query}\" | Age Bracket: [{age_group}]")
    
    # توجيه دلالي دقيق بناءً على الشريحة العمرية في كتاب IMCI
    if age_group == "YOUNG_INFANT":
        search_query = f"Young Infant Age 1 week up to 2 months: Assess, Classify and Treat {query}"
    elif age_group == "CHILD":
        search_query = f"Sick Child Age 2 months up to 5 years: Assess and Classify {query}"
    else:
        search_query = query
        
    results = collection.query(
        query_texts=[search_query],
        n_results=2,
        include=["documents", "metadatas", "distances"]
    )
    
    best_distance = results['distances'][0][0]
    
    if best_distance > DISTANCE_THRESHOLD:
        print(f"⚠️ STATUS: [REJECTED / OUT OF SCOPE] (Distance: {best_distance:.4f} > {DISTANCE_THRESHOLD})")
        print("   Safeguard: Query is out of pediatric IMCI guidelines bounds.\n")
    else:
        print(f"✅ STATUS: [MATCH FOUND] (Best Distance: {best_distance:.4f})")
        for i, (doc, meta, dist) in enumerate(zip(results['documents'][0], results['metadatas'][0], results['distances'][0])):
            print(f"   👉 Top [{i+1}] (Dist: {dist:.4f}) | Page: {meta.get('page_number')} | Section: {meta.get('section_title')}")
            # عرض جزء من النص السريري الداخلي
            clean_snippet = doc.replace("CLINICAL SECTION:", "").replace("CONTENT:", "").replace("\n", " ").strip()[:180]
            print(f"      Clinical Text: {clean_snippet}...")
        print()
    print("-" * 66)