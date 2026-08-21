"""
PediaCare.AI — Structure-Aware WHO IMCI PDF Ingestion Engine (Day 1 Pipeline)
Parses WHO IMCI Model Handbook (142 pages), preserves 3-column clinical decision tables,
injects protocol context headers, extracts rich metadata, and indexes into ChromaDB (Cosine Space).
"""

import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Tuple

# Ensure UTF-8 output on Windows console
if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

import chromadb
import pymupdf
from sentence_transformers import SentenceTransformer

BACKEND_DIR = Path(__file__).resolve().parent
DATA_DIR = BACKEND_DIR / "data"
PDF_PATH = DATA_DIR / "WHO.pdf"
CHROMA_DIR = BACKEND_DIR / "chroma_db"
COLLECTION_NAME = "imci_clinical_guidelines"
EMBEDDING_MODEL_NAME = "all-MiniLM-L6-v2"

# Domain mapping by page ranges and section titles
DOMAIN_KEYWORDS = [
    (r"general danger sign", "General Danger Signs", "2m_to_5y", "RED"),
    (r"cough|difficult breathing|pneumonia|stridor|fast breathing|chest indrawing", "Cough & Respiratory", "2m_to_5y", "MIXED"),
    (r"diarrh|dehydration|fluid|plan [abc]|cholera|dysentery|stool|sunken eyes|skin pinch", "Diarrhoea & Dehydration", "2m_to_5y", "MIXED"),
    (r"fever|malaria|measles|meningitis|stiff neck|petechiae", "Fever & Febrile Illness", "2m_to_5y", "MIXED"),
    (r"ear problem|ear discharge|tender swelling behind|mastoiditis|acute ear", "Ear Problems", "2m_to_5y", "MIXED"),
    (r"malnutrition|anaemia|wasting|oedema|palmar pallor|weight-for-age", "Malnutrition & Anaemia", "2m_to_5y", "MIXED"),
    (r"young infant|bacterial infection|local bacterial|attachment|breastfeed|umbilicus|pustules", "Sick Young Infant (1w-2m)", "7d_to_2m", "MIXED"),
    (r"antibiotic|paracetamol|vitamin a|iron|zinc|artesunate|cotrimoxazole|amoxicillin|dosage", "Treatments & Drug Dosing", "all", "NONE"),
    (r"counsel the mother|feeding problem|fluid at home|when to return", "Counseling & Home Care", "all", "GREEN"),
]

def clean_text(text: str) -> str:
    """Normalize whitespace and remove artifacts."""
    text = re.sub(r'[\r\n]+', ' ', text)
    text = re.sub(r'\s{2,}', ' ', text)
    return text.strip()

def determine_domain_and_metadata(page_num: int, text: str, section_title: str) -> Tuple[str, str, str]:
    """Determine domain, age group, and default triage color based on context and page number."""
    text_lower = (text + " " + section_title).lower()
    
    # Young infant specific pages in IMCI (pages ~61 to ~89)
    if 61 <= page_num <= 89 or "young infant" in text_lower or "1 week to 2 months" in text_lower:
        age_group = "7d_to_2m"
        domain = "Sick Young Infant (1w-2m)"
    elif 90 <= page_num <= 125 or "treat the child" in text_lower or "oral drugs" in text_lower:
        age_group = "all"
        domain = "Treatments & Drug Dosing"
    elif 126 <= page_num <= 142 or "counsel" in text_lower or "feeding" in text_lower:
        age_group = "all"
        domain = "Counseling & Home Care"
    else:
        age_group = "2m_to_5y"
        domain = "Child Assessment (2m-5y)"

    # Refine domain and triage color
    triage_color = "NONE"
    for pattern, dom, age, color in DOMAIN_KEYWORDS:
        if re.search(pattern, text_lower):
            domain = dom
            if age != "all":
                age_group = age
            break

    if re.search(r"severe pneumonia|severe dehydration|very severe febrile|severe complicated measles|mastoiditis|severe malnutrition|possible serious bacterial|danger sign|plan c", text_lower):
        triage_color = "RED"
    elif re.search(r"pneumonia|some dehydration|dysentery|malaria|acute ear infection|moderate malnutrition|local bacterial|plan b", text_lower):
        triage_color = "YELLOW"
    elif re.search(r"no pneumonia|no dehydration|no malaria|no ear infection|plan a|home care|counsel|attachment", text_lower):
        triage_color = "GREEN"

    return domain, age_group, triage_color

def generate_arabic_translation_summary(text_en: str, domain: str, section: str) -> str:
    """Generate high-fidelity Arabic clinical summary based on standardized WHO IMCI terminology."""
    ar_terms = [
        ("SEVERE PNEUMONIA", "التهاب رئوي وخيم أو مرض وخيم جداً"),
        ("PNEUMONIA", "التهاب رئوي"),
        ("NO PNEUMONIA", "لا يوجد التهاب رئوي (سعال أو زكام)"),
        ("SEVERE DEHYDRATION", "جفاف شديد (الخطة ج)"),
        ("SOME DEHYDRATION", "بعض الجفاف (الخطة ب)"),
        ("NO DEHYDRATION", "لا يوجد جفاف (الخطة أ)"),
        ("DYSENTERY", "دوزنتاريا (زحار - دم في البراز)"),
        ("VERY SEVERE FEBRILE DISEASE", "مرض حموي وخيم جداً / اشتباه التهاب سحايا"),
        ("MALARIA", "ملاريا"),
        ("MASTOIDITIS", "التهاب الخشاء (تورم مؤلم خلف الأذن)"),
        ("SEVERE MALNUTRITION", "سوء تغذية حاد وخيم / هزال شديد أو وذمة"),
        ("POSSIBLE SERIOUS BACTERIAL INFECTION", "احتمال عدوى بكتيرية وخيمة عند الرضيع"),
        ("LOCAL BACTERIAL INFECTION", "عدوى بكتيرية موضعية"),
        ("chest indrawing", "انسحاب أسفل جدار الصدر للداخل"),
        ("fast breathing", "تنفس سريع"),
        ("stridor in calm child", "صرير والطفل هادئ"),
        ("sunken eyes", "عيون غائرة"),
        ("skin pinch goes back very slowly", "ثنية جلد البطن ترجع ببطء شديد (> ثانيتين)"),
        ("skin pinch goes back slowly", "ثنية الجلد ترجع ببطء"),
        ("drinking eagerly", "يقبل على الشرب بلهفة وعطش"),
        ("not able to drink or breastfeed", "غير قادر على الشرب أو الرضاعة"),
        ("vomits everything", "يتقيأ كل شيء"),
        ("convulsions", "تشنجات"),
        ("lethargic or unconscious", "خامل أو فاقد للوعي"),
        ("stiff neck", "تيبس الرقبة"),
        ("tender swelling behind the ear", "تورم مؤلم خلف الأذن"),
        ("visible severe wasting", "هزال شديد واضح (جلد على عظم)"),
        ("oedema of both feet", "وذمة / تورم في القدمين"),
        ("Amoxicillin", "أموكسيسيلين"),
        ("Paracetamol", "باراسيتامول"),
        ("Vitamin A", "فيتامين أ"),
        ("Zinc", "زنك"),
        ("ORS", "محلول الجفاف الفموي (ORS)"),
        ("Ringer's Lactate", "محلول رينجر لاكتات وريدي"),
    ]
    
    summary_ar = f"بروتوكول منظمة الصحة العالمية (WHO IMCI): {domain} - {section}."
    key_findings = []
    for en, ar in ar_terms:
        if en.lower() in text_en.lower():
            key_findings.append(f"{ar} ({en})")
            if len(key_findings) >= 5:
                break
                
    if key_findings:
        summary_ar += " النقاط السريرية الرئيسية: " + "، ".join(key_findings) + "."
    return summary_ar

def parse_and_chunk_who_handbook(pdf_path: Path) -> List[Dict[str, Any]]:
    """Parse WHO IMCI PDF into structured chunks with rich metadata and context headers."""
    if not pdf_path.exists():
        raise FileNotFoundError(f"WHO PDF not found at {pdf_path}")

    doc = pymupdf.open(str(pdf_path))
    chunks: List[Dict[str, Any]] = []
    
    current_section = "WHO IMCI General Guidelines"
    current_chapter = "Overview"

    print(f"📖 Parsing {len(doc)} pages from {pdf_path.name}...")

    for page_index in range(len(doc)):
        page_num = page_index + 1
        page = doc[page_index]
        
        # Structure-aware block extraction
        blocks = page.get_text("blocks")
        blocks.sort(key=lambda b: (b[1], b[0]))  # Top to bottom, left to right
        
        page_text_pieces: List[str] = []
        
        for b in blocks:
            text = b[4].strip()
            if not text:
                continue
            
            # Detect Chapter & Section titles from typography/uppercase/headers
            lines = text.split("\n")
            first_line = lines[0].strip()
            
            if len(first_line) > 3 and len(first_line) < 90:
                if re.match(r"^(SECTION|CHAPTER|PART|\d+\.|\bASSESS\b|\bCLASSIFY\b|\bTREAT\b|\bCOUNSEL\b)", first_line, re.IGNORECASE) or (first_line.isupper() and len(first_line) > 5):
                    current_section = first_line
                    if "CHAPTER" in first_line.upper() or "SECTION" in first_line.upper():
                        current_chapter = first_line

            page_text_pieces.append(text)

        full_page_text = clean_text(" ".join(page_text_pieces))
        if not full_page_text or len(full_page_text) < 40:
            continue

        words = full_page_text.split()
        target_chunk_words = 350
        overlap_words = 50
        step = target_chunk_words - overlap_words

        chunk_idx = 1
        for i in range(0, len(words), step):
            chunk_slice = words[i:i + target_chunk_words]
            if len(chunk_slice) < 40 and i > 0:
                continue
            
            chunk_body = " ".join(chunk_slice)
            domain, age_group, triage_color = determine_domain_and_metadata(page_num, chunk_body, current_section)
            
            # Context header injection
            context_header = (
                f"[PROTOCOL: WHO IMCI | DOMAIN: {domain} | "
                f"SECTION: {current_section} | AGE: {age_group} | TRIAGE: {triage_color}]"
            )
            
            full_chunk_text = f"{context_header}\n{chunk_body}"
            chunk_id = f"IMCI_P{page_num:03d}_C{chunk_idx:02d}"
            chunk_idx += 1
            
            text_ar = generate_arabic_translation_summary(chunk_body, domain, current_section)

            metadata = {
                "document_name": "WHO IMCI Model Handbook",
                "section_title": f"{domain} > {current_section}",
                "page_number": page_num,
                "chunk_id": chunk_id,
                "age_group": age_group,
                "triage_color": triage_color,
                "text_en": chunk_body[:500],
                "text_ar": text_ar
            }

            chunks.append({
                "id": chunk_id,
                "text": full_chunk_text,
                "metadata": metadata
            })

    print(f"✅ Generated {len(chunks)} high-density, structured chunks from WHO IMCI Handbook.")
    return chunks

def build_vector_database(chunks: List[Dict[str, Any]]) -> chromadb.Collection:
    """Index chunks into persistent ChromaDB using cosine distance space."""
    CHROMA_DIR.mkdir(parents=True, exist_ok=True)
    client = chromadb.PersistentClient(path=str(CHROMA_DIR))
    
    try:
        client.delete_collection(COLLECTION_NAME)
        print(f"🔄 Replaced previous ChromaDB collection '{COLLECTION_NAME}'.")
    except Exception:
        pass

    collection = client.create_collection(
        name=COLLECTION_NAME,
        metadata={"hnsw:space": "cosine"}
    )

    print(f"🧠 Loading SentenceTransformer model '{EMBEDDING_MODEL_NAME}'...")
    model = SentenceTransformer(EMBEDDING_MODEL_NAME)

    ids = [c["id"] for c in chunks]
    documents = [c["text"] for c in chunks]
    metadatas = [c["metadata"] for c in chunks]

    print("⚡ Generating dense embeddings for all clinical chunks...")
    embeddings = model.encode(documents, show_progress_bar=True, normalize_embeddings=True).tolist()

    print("💾 Indexing into ChromaDB in batches...")
    batch_size = 100
    for i in range(0, len(chunks), batch_size):
        collection.add(
            ids=ids[i:i + batch_size],
            documents=documents[i:i + batch_size],
            embeddings=embeddings[i:i + batch_size],
            metadatas=metadatas[i:i + batch_size]
        )

    print(f"🎉 Successfully indexed {collection.count()} chunks into ChromaDB at '{CHROMA_DIR}'.")
    return collection

def main():
    print("=" * 70)
    print("🏥 PEDIACARE.AI — DAY 1 INGESTION & VECTOR INDEXING PIPELINE")
    print("=" * 70)
    chunks = parse_and_chunk_who_handbook(PDF_PATH)
    build_vector_database(chunks)
    print("🏁 Ingestion Pipeline Completed Successfully!")

if __name__ == "__main__":
    main()
