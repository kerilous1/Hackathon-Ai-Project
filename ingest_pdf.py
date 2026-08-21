import pymupdf
import chromadb
from sentence_transformers import SentenceTransformer
import re

def clean_text(text):
    text = re.sub(r'\s+', ' ', text)
    return text.strip()

def ingest():
    print("Starting Day 1 Ingestion: WHO.pdf")
    doc = pymupdf.open("temp/WHO.pdf")
    
    chunks = []
    current_section = "General Guidelines"
    
    TARGET_WORDS = 400
    
    for page_num in range(len(doc)):
        page = doc[page_num]
        text_blocks = page.get_text("blocks")
        
        text_blocks.sort(key=lambda b: (b[1], b[0]))
        
        page_text = ""
        for b in text_blocks:
            text = b[4].strip()
            # Simple heuristic for section headers
            if len(text) > 0 and len(text) < 100 and ('\n' not in text) and text.isupper():
                current_section = text
            page_text += text + " "
        
        clean_page_text = clean_text(page_text)
        words = clean_page_text.split()
        
        overlap = int(TARGET_WORDS * 0.15)
        step = TARGET_WORDS - overlap
        
        if not words:
            continue
            
        for i in range(0, len(words), step):
            chunk_words = words[i:i + TARGET_WORDS]
            if len(chunk_words) < 50 and i > 0:
                continue
            chunk_text = " ".join(chunk_words)
            
            chunks.append({
                "text": chunk_text,
                "section": current_section,
                "page": page_num + 1
            })
            
    print(f"Extracted {len(chunks)} chunks.")
    
    chroma_client = chromadb.PersistentClient(path="./chroma_db")
    try:
        chroma_client.delete_collection("imci_clinical_guidelines")
    except Exception:
        pass
        
    collection = chroma_client.create_collection("imci_clinical_guidelines", metadata={"hnsw:space": "cosine"})
    
    print("Loading embedding model...")
    embed_model = SentenceTransformer("all-MiniLM-L6-v2")
    
    docs = [c["text"] for c in chunks]
    metas = [{"document_name": "WHO IMCI Guidelines", "section_title": c["section"], "page_number": c["page"]} for c in chunks]
    ids = [f"chunk_{i}" for i in range(len(chunks))]
    
    print("Encoding chunks...")
    embeddings = embed_model.encode(docs, show_progress_bar=True).tolist()
    
    print("Indexing into ChromaDB...")
    batch_size = 100
    for i in range(0, len(docs), batch_size):
        collection.add(
            ids=ids[i:i+batch_size],
            documents=docs[i:i+batch_size],
            embeddings=embeddings[i:i+batch_size],
            metadatas=metas[i:i+batch_size]
        )
    print("Day 1 Ingestion complete!")

if __name__ == "__main__":
    ingest()
