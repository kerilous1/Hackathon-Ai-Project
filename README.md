# 🩺 PediaCare.AI — WHO IMCI Clinical Decision Support System

An evidence-based Clinical Decision Support System (CDSS) built with Retrieval-Augmented Generation (RAG) and zero-mock dynamic architecture. **PediaCare.AI** translates pediatric clinical presentations into grounded classifications, urgent pre-referral interventions, differential verification questions, and verifiable citations strictly adhering to the official **WHO Integrated Management of Childhood Illness (IMCI) Guidelines** (for children aged 0 to 5 years / 0 to 59 months).

---

## 🌟 Key Features

* **Authoritative WHO IMCI Grounding:** Generative inference is strictly restricted to retrieved WHO IMCI evidence blocks with verbatim citations and printed handbook page numbers.
* **Bilingual Arabic & English Clinical Parity:** Native support for Arabic and English medical inputs, clinical intent prioritization, and Arabic structured responses.
* **Calibrated Relevance Scores:** Nuanced cosine similarity metrics that accurately reflect semantic match percentages and ensure proper descending rank ordering.
* **Hardened Safety Boundaries & Out-of-Scope Safeguards:** Complete rejection of non-medical queries, random noise, keyboard mashing, general chit-chat, adult cardiology/geriatrics, and age > 5 years inquiries with zero hallucinated questions or evidence leaks.
* **FastAPI Backend & Dynamic Mobile UI:** Production-ready RESTful API connected directly to a Flutter mobile app powered by dynamic BLoC state management and local Hive persistence.

---

## 🏗️ System Architecture

```text
                  [ Clinician / Caregiver Input (AR / EN) ]
                                      │
                                      ▼
               [ Pre-Retrieval Multi-Layer Boundary Guardrail ]
               • Length & Noise Checks    • Keyboard Mash Filter
               • Adult Medicine & Age > 5 • Clinical Term Whitelist
                                      │ (Passed)
                                      ▼
               [ Clinical Intent Routing & Query Preparation ]
               (Solves bi-encoder negation blindness for 15 WHO protocols)
                                      │
                                      ▼
               [ ChromaDB Vector Search (all-MiniLM-L6-v2) ]
                                      │
                                      ▼
               [ Re-ranking & Score Calibration (Descending Order) ]
                                      │
                                      ▼
               [ Safety Gate (Confidence Threshold >= 43.5%) ]
                                      │ (Passed)
                                      ▼
               [ XML-Bounded Prompt Formulation ]
                                      │
                                      ▼
               [ Gemini Generative Inference + Resilient Fallback ]
                                      │
                                      ▼
  [ 4-Part Response: 📋 Triage (🔴/🟡/🟢) | 📖 Quotes | 🏷️ Citations | 🔎 Questions ]
```

---

## 📁 Project Directory Structure

```text
hac/
├── chroma_db/               # Persistent ChromaDB vector storage (pre-indexed)
├── docs/                    # Clinical guidelines & benchmark datasets
│   ├── imci_handbook.md     # WHO IMCI guidelines with semantic markdown headers
│   ├── WHO_IMCI_Clinical_Benchmark_Dataset.xlsx # 15-Case audited gold standard benchmark
│   ├── WHO_IMCI_Clinical_Benchmark_Dataset.csv  # CSV version of benchmark dataset
│   └── benchmark_evaluation_report.md           # Latest automated evaluation scorecard
├── tests/                   # Automated validation & benchmark suites
│   ├── test_comprehensive_suite.py     # End-to-end API & boundary safety tests (6 cases)
│   └── evaluate_benchmark_dataset.py   # Full 15-case WHO IMCI gold standard evaluation
├── ui/                      # Flutter mobile application (BLoC + Hive dynamic state)
│   ├── lib/                 # App source code, cubits, screens & repositories
│   └── test/                # Flutter widget tests
├── doctor_assistant.py      # Core RAG engine, retrieval logic & intent router
├── server.py                # Production FastAPI REST backend (`/api/v1/assess`, `/health`)
├── reindex_chromadb.py      # Vector store indexing script for WHO IMCI chunks
├── requirements.txt         # Python dependencies
├── .env.example             # Environment credentials template
└── README.md                # Technical documentation & usage guide
```

---

## 🚀 Installation & Setup

### 1. Prerequisites
* Python 3.10+
* Flutter SDK (for mobile UI)
* Google Gemini API Key

### 2. Clone & Install Backend Dependencies
```bash
git clone https://github.com/kerilous1/hac.git
cd hac
pip install -r requirements.txt
```

### 3. Environment Configuration
Create a `.env` file in the root directory based on `.env.example`:
```env
GEMINI_API_KEY=your_actual_gemini_api_key_here
PORT=8000
```

### 4. Vector Database Ingestion (Optional / Verification)
The local ChromaDB vector store is pre-indexed in `./chroma_db`. To re-index from the markdown handbook:
```bash
python reindex_chromadb.py
```

---

## 🏃 Running the Application

### 1. Launch FastAPI Backend
```bash
uvicorn server:app --host 0.0.0.0 --port 8000 --reload
```
API Documentation will be available at: `http://localhost:8000/docs`

### 2. Launch Flutter Mobile App
```bash
cd ui
flutter pub get
flutter run
```

---

## 🧪 Automated Testing & Evaluation

### 1. Run Comprehensive API & Boundary Test Suite
```bash
python tests/test_comprehensive_suite.py
```
*Evaluates adult conditions, non-medical noise, severe pneumonia, cold, and severe dehydration against the live FastAPI endpoint.*

### 2. Run 15-Case WHO IMCI Gold Standard Benchmark
```bash
python tests/evaluate_benchmark_dataset.py
```
*Evaluates all 15 clinical protocols across general danger signs, respiratory, diarrhoea/dehydration, dysentery, febrile/meningitis, measles, ear infections, severe malnutrition, neonatal sepsis, and dose safety limits.*

### 3. Run Flutter Mobile Tests
```bash
cd ui
flutter test
```

---

## 🛡️ Clinical Disclaimer

This software is designed solely for clinical decision support, academic evaluation, and triage assistance based on the WHO IMCI Guidelines. It is not a replacement for professional clinical diagnosis, emergency medical care, or physician oversight.
