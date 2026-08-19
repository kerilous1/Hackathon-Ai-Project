"""
Re-indexes ChromaDB with structured contextual headers for the WHO IMCI Guidelines.
Solves negation blindness by embedding explicit clinical protocol headers, positive triggers, and negation criteria.
"""

import os
import re
import chromadb
from sentence_transformers import SentenceTransformer
from langchain_text_splitters import MarkdownHeaderTextSplitter

def build_structured_clinical_chunks():
    """Authoritative structured clinical decision tree chunks with contextual metadata."""
    return [
        {
            "id": "structured-danger-signs-01",
            "section": "General danger signs > CHECK FOR GENERAL DANGER SIGNS",
            "page": "16",
            "text": """[PROTOCOL: WHO IMCI | DOMAIN: GENERAL DANGER SIGNS | TRIAGE: 🔴 RED / EMERGENCY]
- Section: General danger signs > CHECK FOR GENERAL DANGER SIGNS
- Positive Trigger Signs (Check for ANY of the following):
  * Child NOT able to drink or breastfeed
  * Child VOMITS EVERYTHING (cannot keep anything down at all)
  * Child has had CONVULSIONS during current illness
  * Child is LETHARGIC OR UNCONSCIOUS (drowsy, abnormally sleepy, cannot wake)
- Classification: GENERAL DANGER SIGNS PRESENT / SEVERE DISEASE.
- Target Clinical Actions: Complete the assessment immediately. Give urgent pre-referral treatment (treat to prevent low blood sugar with breast milk or sugar water, give first dose of appropriate antibiotic if indicated). Refer URGENTLY to hospital."""
        },
        {
            "id": "structured-severe-pneumonia-02",
            "section": "Cough or difficult breathing > SEVERE PNEUMONIA OR VERY SEVERE DISEASE",
            "page": "20",
            "text": """[PROTOCOL: WHO IMCI | DOMAIN: COUGH & DIFFICULT BREATHING | TRIAGE: 🔴 RED / SEVERE PNEUMONIA]
- Section: Cough or difficult breathing > SEVERE PNEUMONIA OR VERY SEVERE DISEASE
- Positive Trigger Signs (Any of the following in a child with cough or difficult breathing):
  * ANY General Danger Sign (not able to drink, vomiting everything, convulsions, lethargic/unconscious)
  * CHEST INDRAWING (lower chest wall indrawing / subcostal indrawing when calm)
  * STRIDOR in a calm child
  * Fast breathing with severe respiratory distress
- Classification: SEVERE PNEUMONIA OR VERY SEVERE DISEASE.
- Target Clinical Actions: Give first dose of an appropriate antibiotic. Provide oxygen if available and severe distress. Refer URGENTLY to hospital."""
        },
        {
            "id": "structured-pneumonia-03",
            "section": "Cough or difficult breathing > PNEUMONIA",
            "page": "20",
            "text": """[PROTOCOL: WHO IMCI | DOMAIN: COUGH & DIFFICULT BREATHING | TRIAGE: 🟡 YELLOW / PNEUMONIA]
- Section: Cough or difficult breathing > PNEUMONIA
- Positive Trigger Signs:
  * Fast breathing (Cutoff: ≥50 breaths/min for infant 2 months up to 11 months; ≥40 breaths/min for child 12 months up to 5 years)
  * AND NO chest indrawing
  * AND NO stridor in a calm child
  * AND NO general danger signs
- Classification: PNEUMONIA.
- Target Clinical Actions: Give an appropriate oral antibiotic (Amoxicillin or Cotrimoxazole) for 5 days. Soothe throat and relieve cough with a safe remedy. Advise mother when to return immediately. Follow-up in 2 days."""
        },
        {
            "id": "structured-no-pneumonia-04",
            "section": "Cough or difficult breathing > NO PNEUMONIA: COUGH OR COLD",
            "page": "20",
            "text": """[PROTOCOL: WHO IMCI | DOMAIN: COUGH & DIFFICULT BREATHING | TRIAGE: 🟢 GREEN / NO PNEUMONIA]
- Section: Cough or difficult breathing > NO PNEUMONIA: COUGH OR COLD
- Inclusion Criteria:
  * NO fast breathing (e.g. respiratory rate < 50 bpm for infant 2–11m; respiratory rate < 40 bpm for child 12m–5y; e.g. 36 bpm is normal)
  * AND NO chest indrawing (chest wall expands normally)
  * AND NO stridor
  * AND NO general danger signs
- Classification: NO PNEUMONIA: COUGH OR COLD.
- Target Clinical Actions: No antibiotics needed (antibiotics do not relieve viral cough or cold). Continue feeding and breastfeeding, increase fluids, soothe throat with safe remedy. Advise mother to return in 5 days if not improving, or immediately if fast breathing or chest indrawing develops."""
        },
        {
            "id": "structured-severe-dehydration-05",
            "section": "Diarrhoea > SEVERE DEHYDRATION (Plan C)",
            "page": "28",
            "text": """[PROTOCOL: WHO IMCI | DOMAIN: DIARRHOEA & DEHYDRATION | TRIAGE: 🔴 RED / SEVERE DEHYDRATION]
- Section: Diarrhoea > SEVERE DEHYDRATION (Plan C)
- Positive Trigger Signs (Two or more of the following):
  * Lethargic or unconscious
  * Sunken eyes
  * Not able to drink or drinking poorly
  * Skin pinch goes back very slowly (> 2 seconds)
- Classification: SEVERE DEHYDRATION.
- Target Clinical Actions: Start IV fluids immediately (Plan C: Ringer's Lactate 100 ml/kg: 30 ml/kg in 1 hr for <12m or 30 min for ≥12m, then 70 ml/kg in 5 hr for <12m or 2.5 hr for ≥12m) or refer urgently with ORS solution. Give Zinc supplements for 14 days once child can drink."""
        },
        {
            "id": "structured-some-dehydration-06",
            "section": "Diarrhoea > SOME DEHYDRATION (Plan B)",
            "page": "28",
            "text": """[PROTOCOL: WHO IMCI | DOMAIN: DIARRHOEA & DEHYDRATION | TRIAGE: 🟡 YELLOW / SOME DEHYDRATION]
- Section: Diarrhoea > SOME DEHYDRATION (Plan B)
- Positive Trigger Signs (Two or more of the following):
  * Restless, irritable
  * Sunken eyes
  * Drinks eagerly, thirsty
  * Skin pinch goes back slowly
- Classification: SOME DEHYDRATION.
- Target Clinical Actions: Treat with ORS solution in clinic over 4 hours (Plan B: approx. 75 ml/kg). Reassess child after 4 hours and classify dehydration. Give Zinc supplements for 14 days (10 mg/day for <6m, 20 mg/day for ≥6m). Continue breastfeeding. Advise mother when to return immediately."""
        },
        {
            "id": "structured-dysentery-07",
            "section": "Diarrhoea > DYSENTERY",
            "page": "26",
            "text": """[PROTOCOL: WHO IMCI | DOMAIN: DIARRHOEA & DYSENTERY | TRIAGE: 🟡 YELLOW / DYSENTERY]
- Section: Diarrhoea > DYSENTERY
- Positive Trigger Signs: Diarrhoea with visible fresh blood in the stool.
- Classification: DYSENTERY.
- Target Clinical Actions: Treat for 5 days with an oral antibiotic recommended for Shigella in your area (e.g. Ciprofloxacin). Give Zinc supplements for 14 days. Prevent dehydration with fluids and continued feeding (Plan A). Follow-up in 2 days."""
        },
        {
            "id": "structured-fever-meningitis-08",
            "section": "Fever > VERY SEVERE FEBRILE DISEASE",
            "page": "35",
            "text": """[PROTOCOL: WHO IMCI | DOMAIN: FEVER & MENINGITIS | TRIAGE: 🔴 RED / VERY SEVERE FEBRILE DISEASE]
- Section: Fever > VERY SEVERE FEBRILE DISEASE
- Positive Trigger Signs (In a child with fever):
  * ANY General Danger Sign OR
  * STIFF NECK (resistance or pain when bending child's head forward towards chest - suspect meningitis)
- Classification: VERY SEVERE FEBRILE DISEASE / MALARIA.
- Target Clinical Actions: Give first dose of an appropriate IM/IV antibiotic (Chloramphenicol/Ampicillin or Ceftriaxone). Give single dose of Paracetamol in clinic for high fever (≥38.5°C). Treat to prevent low blood sugar. Refer URGENTLY to hospital."""
        },
        {
            "id": "structured-measles-09",
            "section": "Fever > SEVERE COMPLICATED MEASLES",
            "page": "36",
            "text": """[PROTOCOL: WHO IMCI | DOMAIN: FEVER & MEASLES | TRIAGE: 🔴 RED / SEVERE COMPLICATED MEASLES]
- Section: Fever > SEVERE COMPLICATED MEASLES
- Positive Trigger Signs (Child with measles rash and fever plus any of):
  * ANY General Danger Sign OR
  * CLOUDING OF THE CORNEA (hazy or opaque cornea) OR
  * DEEP OR EXTENSIVE MOUTH ULCERS
- Classification: SEVERE COMPLICATED MEASLES.
- Target Clinical Actions: Give therapeutic Vitamin A immediately (Day 1 dose and Day 2 dose). If clouding of cornea or pus draining from eye, apply Tetracycline eye ointment. Give first dose of an appropriate antibiotic. Refer URGENTLY to hospital."""
        },
        {
            "id": "structured-mastoiditis-10",
            "section": "Ear problem > MASTOIDITIS",
            "page": "44",
            "text": """[PROTOCOL: WHO IMCI | DOMAIN: EAR PROBLEM | TRIAGE: 🔴 RED / MASTOIDITIS]
- Section: Ear problem > MASTOIDITIS
- Positive Trigger Signs: Ear pain, discharge for less than 14 days, and TENDER SWELLING BEHIND THE EAR over the mastoid bone.
- Classification: MASTOIDITIS.
- Target Clinical Actions: Give first dose of an appropriate antibiotic (injectable/oral). Give first dose of Paracetamol for pain. Refer URGENTLY to hospital."""
        },
        {
            "id": "structured-malnutrition-11",
            "section": "Malnutrition and anaemia > SEVERE MALNUTRITION",
            "page": "48",
            "text": """[PROTOCOL: WHO IMCI | DOMAIN: MALNUTRITION & ANAEMIA | TRIAGE: 🔴 RED / SEVERE MALNUTRITION]
- Section: Malnutrition and anaemia > SEVERE MALNUTRITION
- Positive Trigger Signs:
  * Visible severe wasting (skin and bones / marasmus) OR
  * Severe palmar pallor OR
  * Oedema of both feet (pitting edema / kwashiorkor)
- Classification: SEVERE MALNUTRITION OR SEVERE ANAEMIA.
- Target Clinical Actions: Give Vitamin A. Treat to prevent low blood sugar. Keep child warm on the way to hospital. Refer URGENTLY to hospital for specialized inpatient nutritional management."""
        },
        {
            "id": "structured-young-infant-sepsis-12",
            "section": "Sick Young Infant (1 week–2m) > POSSIBLE SERIOUS BACTERIAL INFECTION",
            "page": "61",
            "text": """[PROTOCOL: WHO IMCI | DOMAIN: SICK YOUNG INFANT (1 WEEK UP TO 2 MONTHS) | TRIAGE: 🔴 RED / POSSIBLE SERIOUS BACTERIAL INFECTION]
- Section: Sick Young Infant (1 week up to 2 months) > POSSIBLE SERIOUS BACTERIAL INFECTION
- Positive Trigger Signs (Check for ANY of the following):
  * Fast breathing (≥ 60 breaths/min on repeat count)
  * Severe chest indrawing
  * Nasal flaring or Expiratory grunting
  * Axillary temperature < 35.5°C (hypothermia) or ≥ 37.5°C (fever)
  * Convulsions or Lethargic / unconscious
  * Umbilicus red or draining pus
- Classification: POSSIBLE SERIOUS BACTERIAL INFECTION (PSBI).
- Target Clinical Actions: Give first dose of intramuscular antibiotics (Ampicillin/Benzylpenicillin + Gentamicin). Treat to prevent low blood sugar (breast milk / sugar water). Advise mother how to keep infant warm on the way to hospital. Refer URGENTLY to hospital."""
        },
        {
            "id": "structured-breastfeeding-attachment-13",
            "section": "Sick Young Infant > Assess breastfeeding (Attachment)",
            "page": "68",
            "text": """[PROTOCOL: WHO IMCI | DOMAIN: SICK YOUNG INFANT (1 WEEK UP TO 2 MONTHS) | TRIAGE: 🟢 GREEN / BREASTFEEDING ATTACHMENT]
- Section: Sick Young Infant > Assess breastfeeding (Attachment)
- Four Signs of Good Attachment during breastfeeding:
  1. Chin touching breast (or very close)
  2. Mouth wide open
  3. Lower lip turned outward
  4. More areola visible above than below the mouth
- Classification: GOOD ATTACHMENT / COUNSELING.
- Target Clinical Actions: Praise the mother. Advise on continued exclusive on-demand breastfeeding day and night."""
        },
        {
            "id": "structured-dosage-limits-14",
            "section": "Appropriate oral drugs > 21.1 Oral antibiotics",
            "page": "23",
            "text": """[PROTOCOL: WHO IMCI | DOMAIN: APPROPRIATE ORAL DRUGS | TRIAGE: 🛡️ REFUSAL / DOSAGE PARAMETER LIMITS]
- Section: Appropriate oral drugs > 21.1 Oral antibiotics
- Oral Antibiotic Weight Brackets:
  * Minimum weight bracket: 4 kg up to <10 kg (Age: 2 months up to 12 months).
  * Children weighing < 4 kg or aged < 2 months fall strictly under the Young Infant Protocol.
  * WARNING: Do NOT extrapolate or guess mathematical milligram doses for infants < 4 kg from oral antibiotic tables. Refer to young infant injectable antibiotic protocols and hospital referral if severe."""
        }
    ]

def reindex():
    print("Starting ChromaDB Re-indexing with Structured Contextual Decision Trees...")
    embed_model = SentenceTransformer("all-MiniLM-L6-v2")
    
    chroma_client = chromadb.PersistentClient(path="./chroma_db")
    try:
        chroma_client.delete_collection("imci_clinical_guidelines")
        print("Deleted previous collection.")
    except Exception:
        pass
        
    collection = chroma_client.create_collection(
        "imci_clinical_guidelines",
        metadata={"hnsw:space": "cosine"}
    )
    
    # 1. Ingest general chunks from imci_handbook.md
    handbook_candidates = ["docs/imci_handbook.md", "imci_handbook.md"]
    handbook_path = next((p for p in handbook_candidates if os.path.exists(p)), None)
    if handbook_path:
        with open(handbook_path, "r", encoding="utf-8") as f:
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
        print(f"Split {len(splits)} general markdown chunks...")
        
        docs, metas, ids = [], [], []
        current_page = 1
        for i, chunk in enumerate(splits):
            content = chunk.page_content.strip()
            if len(content) < 70:
                continue
                
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
            parts = [p for p in [h1, h2, h3] if p]
            section = " > ".join(parts) if parts else "WHO IMCI Clinical Guidelines"
            
            docs.append(content)
            metas.append({
                "document_name": "WHO IMCI Handbook",
                "section_title": section,
                "source": "WHO-UNICEF IMCI Guidelines",
                "page_number": int(current_page)
            })
            ids.append(f"general-chunk-{i}")
            
        if docs:
            embeddings = embed_model.encode(docs).tolist()
            batch_size = 50
            for b in range(0, len(docs), batch_size):
                collection.add(
                    ids=ids[b:b+batch_size],
                    documents=docs[b:b+batch_size],
                    embeddings=embeddings[b:b+batch_size],
                    metadatas=metas[b:b+batch_size]
                )
            print(f"Ingested {len(docs)} general chunks.")
            
    # 2. Ingest High-Precision Structured Contextual Blocks
    structured_blocks = build_structured_clinical_chunks()
    s_docs = [b["text"] for b in structured_blocks]
    s_ids = [b["id"] for b in structured_blocks]
    s_metas = [{
        "document_name": "WHO IMCI Structured Decision Trees",
        "section_title": b["section"],
        "source": "WHO IMCI Model Handbook",
        "page_number": int(b["page"])
    } for b in structured_blocks]
    
    s_embeddings = embed_model.encode(s_docs).tolist()
    collection.add(
        ids=s_ids,
        documents=s_docs,
        embeddings=s_embeddings,
        metadatas=s_metas
    )
    print(f"Ingested {len(structured_blocks)} structured clinical decision tree blocks!")
    print(f"Total ChromaDB documents: {collection.count()}")

if __name__ == "__main__":
    reindex()
