import chromadb

# 1. الاتصال بقاعدة البيانات المحلية
client = chromadb.PersistentClient(path="./chroma_db")
collection = client.get_or_create_collection(name="imci_clinical_guidelines")

# 2. استعلام تجريبي لحالة سريرية
query_text = "how to assess child with diarrhea and dehydration"
print(f"🔍 Searching clinical guidelines for: '{query_text}'...\n")

# 3. استرجاع أفضل النتائج
results = collection.query(
    query_texts=[query_text],
    n_results=2
)

# 4. عرض النتيجة متضمنة رقم الصفحة والتوثيق الكامل
for i, (doc, metadata) in enumerate(zip(results['documents'][0], results['metadatas'][0])):
    print(f"==================== Result [{i+1}] ====================")
    print(f"📄 Document   : {metadata.get('document_name')}")
    print(f"📌 Section    : {metadata.get('section_title')}")
    print(f"📖 Page Number: {metadata.get('page_number')}")
    print(f"📚 Source     : {metadata.get('source')}")
    print(f"---------------- Content Preview ----------------")
    print(f"{doc[:300]}...\n")