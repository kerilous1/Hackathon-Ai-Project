import os
import re
import time
from langchain_text_splitters import MarkdownHeaderTextSplitter
from sentence_transformers import SentenceTransformer
from pinecone import Pinecone, ServerlessSpec

# 1. إعداد مفتاح Pinecone والاتصال
PINECONE_API_KEY = os.getenv("PINECONE_API_KEY", "pcsk_JRHKF_4eVpbyHrnkHe2xy9sh48UYXnMjrEdQxUHR2Ka6modGzkZfpjoyzV7ssBjMaWzV6")
pc = Pinecone(api_key=PINECONE_API_KEY)

INDEX_NAME = "imci-clinical-guidelines"
DIMENSION = 384  # البُعد المتجهي لنموذج all-MiniLM-L6-v2

# إنشاء الـ Index السحابي إذا لم يكن موجوداً
existing_indexes = [idx.name for idx in pc.list_indexes()]
if INDEX_NAME not in existing_indexes:
    print(f"🌲 جاري إنشاء الفهرس السحابي في Pinecone: '{INDEX_NAME}'...")
    pc.create_index(
        name=INDEX_NAME,
        dimension=DIMENSION,
        metric="cosine",
        spec=ServerlessSpec(cloud="aws", region="us-east-1")
    )
    time.sleep(5)

index = pc.Index(INDEX_NAME)

# 2. تحميل نموذج التضمين (نفس المستخدم محلياً لضمان العدالة في المقارنة)
print("🧠 تحميل نموذج التضمين (all-MiniLM-L6-v2)...")
embed_model = SentenceTransformer("all-MiniLM-L6-v2")

# 3. قراءة وتقطيع كتاب IMCI
file_path = "imci_handbook.md"
if not os.path.exists(file_path):
    print(f"❌ خطأ: لم يتم العثور على الملف '{file_path}'.")
    exit(1)

with open(file_path, "r", encoding="utf-8") as f:
    markdown_content = f.read()

headers_to_split_on = [
    ("#", "Header 1"),
    ("##", "Header 2"),
    ("###", "Header 3"),
]

markdown_splitter = MarkdownHeaderTextSplitter(
    headers_to_split_on=headers_to_split_on,
    strip_headers=False
)
splits = markdown_splitter.split_text(markdown_content)

print(f"📖 تم استخراج {len(splits)} مقطعاً سريرياً...")

vectors_to_upsert = []
current_page = 1

for i, chunk in enumerate(splits):
    content = chunk.page_content.strip()
    if len(content) < 80:
        continue

    # استخراج رقم الصفحة الحقيقي
    page_match = re.search(r'(\d+)\s*▼|▼\s*(\d+)', content)
    if page_match:
        found_num = page_match.group(1) or page_match.group(2)
        try:
            page_val = int(found_num)
            if 1 <= page_val <= 173:
                current_page = page_val
        except ValueError:
            pass

    h1 = chunk.metadata.get("Header 1", "")
    h2 = chunk.metadata.get("Header 2", "")
    h3 = chunk.metadata.get("Header 3", "")
    section_parts = [p for p in [h1, h2, h3] if p]
    full_section = " > ".join(section_parts) if section_parts else "IMCI Clinical Section"

    # حساب الـ Vector Embedding
    vector = embed_model.encode(content).tolist()

    metadata = {
        "text": content,
        "document_name": "WHO IMCI Handbook 9241546441",
        "section_title": str(full_section),
        "source": "WHO-UNICEF IMCI Guidelines",
        "page_number": int(current_page)
    }

    vectors_to_upsert.append((f"imci-chunk-{i}", vector, metadata))

# 4. الرفع إلى Pinecone على دفعات (Batch Upsert)
print(f"🚀 جاري رفع {len(vectors_to_upsert)} مقطع إلى Pinecone...")
batch_size = 50
for b in range(0, len(vectors_to_upsert), batch_size):
    batch = vectors_to_upsert[b:b + batch_size]
    index.upsert(vectors=batch)
    print(f"   تم رفع {min(b + batch_size, len(vectors_to_upsert))}/{len(vectors_to_upsert)} مقطع...")

print("✅ اكتملت عملية الفهرسة على Pinecone بنجاح!")