import os
import re
import chromadb
from langchain_text_splitters import MarkdownHeaderTextSplitter

file_path = "imci_handbook.md"

if not os.path.exists(file_path):
    print(f"Error: '{file_path}' not found.")
    exit(1)

print("📖 Reading IMCI handbook markdown file...")
with open(file_path, "r", encoding="utf-8") as f:
    markdown_content = f.read()

total_len = len(markdown_content)
ESTIMATED_PAGE_LEN = max(1, total_len // 173)

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
print(f"Total raw sections extracted: {len(splits)}")

client = chromadb.PersistentClient(path="./chroma_db")

try:
    client.delete_collection(name="imci_clinical_guidelines")
except Exception:
    pass

collection = client.create_collection(name="imci_clinical_guidelines")

print("⚙️ Filtering out empty cover headers and indexing clinical content...")

current_char_count = 0
valid_chunks = 0

for i, chunk in enumerate(splits):
    content = chunk.page_content.strip()
    chunk_len = len(content)
    
    # حساب رقم الصفحة
    estimated_page = min(173, max(1, (current_char_count // ESTIMATED_PAGE_LEN) + 1))
    current_char_count += chunk_len
    
    # 🌟 استبعاد أغلفة الفصول والعناوين المجرّدة التي لا تحتوي على محتوى سريري مفيد
    # أي مقطع أقصر من 150 حرف أو عبارة عن مجرد "Part III" يتم تخطيه لتركيز البحث على الجداول
    if chunk_len < 150 and any(h in content.lower() for h in ["# part", "chapter", "contents"]):
        continue

    section_title = chunk.metadata.get("Header 2", chunk.metadata.get("Header 1", "General Clinical Guidelines"))
    h3_title = chunk.metadata.get("Header 3", "")
    full_context_title = f"{section_title} - {h3_title}" if h3_title else section_title
    
    # حشو السياق الكامل
    context_enhanced_text = f"CLINICAL SECTION: {full_context_title}\nCONTENT:\n{content}"

    metadata = {
        "document_name": "WHO IMCI Handbook 9241546441",
        "section_title": str(full_context_title),
        "source": "WHO-UNICEF IMCI Guidelines",
        "page_number": int(estimated_page)
    }

    collection.add(
        documents=[context_enhanced_text],
        metadatas=[metadata],
        ids=[f"imci-chunk-{i}"]
    )
    valid_chunks += 1

print(f"✅ Success! Indexed {valid_chunks} high-density clinical chunks with page mapping.")