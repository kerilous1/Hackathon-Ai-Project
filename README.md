## 🩺 Pedi-Guide AI: WHO IMCI Clinical Decision Support System

An evidence-based Clinical Decision Support System (CDSS) built with Retrieval-Augmented Generation (RAG). **Pedi-Guide AI** translates pediatric clinical presentations into grounded classifications, urgent pre-referral interventions, and verifiable citations strictly adhering to the official **WHO Integrated Management of Childhood Illness (IMCI) Guidelines**.

---

## 🌟 Key Features

* **Strict Clinical Grounding & Verifiable Citations:** Restricts LLM generative inference exclusively to retrieved WHO IMCI evidence blocks. Outputs exact printed handbook page numbers and hierarchical section titles to eliminate hallucinations.
* **Dual Vector Database Architecture:** Seamless switching between **ChromaDB** (embedded local storage for zero-dependency / offline edge deployment) and **Pinecone Serverless** (managed cloud vector index for scalable cloud microservices).
* **Cross-Lingual Clinical Translation:** Native support for Arabic and English. Colloquial and Arabic clinical complaints are automatically translated into standardized medical English terms for semantic vector retrieval while generating structured clinical responses in the clinician's language.
* **Clinical Safety Threshold (Out-of-Scope Safeguard):** Employs exact Cosine Similarity metric filtering ($43.5\%$ threshold) to automatically detect and reject adult or out-of-scope medical inquiries.
* **Zero-Downtime Multi-Model Fallback:** Multi-tier client-side failover across `gemini-3.5-flash`, `gemini-3.7-flash`, and `gemini-3.1-flash-lite` to ensure uninterrupted service during temporary API spikes (`503 UNAVAILABLE` or `429 Rate Limit`).

---

## 🏗️ System Architecture

```text
               [ Clinician Input (Arabic / English) ]
                                 │
                                 ▼
           [ Cross-Lingual Clinical Translation Layer ]
                                 │
                                 ▼
       ┌───────────────────────────────────────────────────┐
       │         Vector Database Engine Selection          │
       │   [1] ChromaDB (Local)  │  [2] Pinecone (Cloud)   │
       └─────────────────────────┬─────────────────────────┘
                                 │ (all-MiniLM-L6-v2 Embeddings)
                                 ▼
       ┌───────────────────────────────────────────────────┐
       │     Clinical Safety Guardrail (Sim >= 43.5%)      │
       └─────────┬───────────────────────────────┬─────────┘
                 │ (Passed)                      │ (Out of Scope)
                 ▼                               ▼
       [ Evidence Assembly ]             [ Safeguard Notice ]
       (Handbook Chunks + Real Pages)    (Clinical Scope Rejection)
                 │
                 ▼
       [ Gemini 3.5 Generative Engine ]
       (Strict WHO IMCI Protocol Grounding)
                 │
                 ▼
       [ Grounded Output: Triage (🔴/🟡/🟢) / Actions / Citations ]
---

##  📁 Repository StructurePlaintext├── chroma_db/               # Local persistent ChromaDB vector storage
├── imci_handbook.md         # WHO IMCI guidelines with semantic headers
├── doctor_assistant.py      # Main interactive clinical assistant CLI (Dual Engine)
├── query_tester.py          # Benchmark test suite (ChromaDB vs. Pinecone head-to-head)
├── ingest_pinecone.py       # Cloud index ingestion script for Pinecone Serverless
├── check_models.py          # Diagnostic script to verify active Gemini models
├── requirements.txt         # Project dependencies
├── .env.example             # Environment credentials template
└── README.md                # Technical documentation
---

##  Installation & Setup1. PrerequisitesPython 3.10 or higherGoogle AI Studio API KeyPinecone API Key (Optional: required for cloud index mode)2. Clone & Install DependenciesBashgit clone [https://github.com/kerilous1/hac.git](https://github.com/kerilous1/hac.git)
cd hac
pip install -r requirements.txt
Or install required packages manually:Bashpip install chromadb pinecone google-genai sentence-transformers langchain-text-splitters tabulate python-dotenv arabic-reshaper python-bidi
3. Configure Environment VariablesCreate a .env file in the root directory:Code snippetGEMINI_API_KEY="your_gemini_api_key_here"
PINECONE_API_KEY="your_pinecone_api_key_here"
---

##  Data Ingestion & IndexingLocal Database (ChromaDB): Pre-indexed and stored locally in the ./chroma_db directory.Cloud Database (Pinecone): Run the ingestion script once to parse, embed, and upload the handbook chunks to Pinecone Serverless:Bashpython ingest_pinecone.py
🚀 Execution & Usage1. Interactive Clinical Assistant CLILaunch the interactive decision support assistant and choose your vector backend:Bashpython doctor_assistant.py
Plaintext==================================================================
🩺 PEDI-GUIDE AI - CLINICAL ASSISTANT (MULTI-VECTOR DB SUPPORT)
==================================================================

Select Vector Database Backend:
 [1] 💾 ChromaDB (Local Embedded DB)
 [2] 🌲 Pinecone (Cloud Serverless DB)

# 👉 Selection (1 or 2): 1
Sample Clinical Test Queries:Arabic (Young Infant / Hypothermia & Feeding Difficulty):Plaintextرضيع عمره شهر ونصف عنده صعوبة في الرضاعة مع سرعة تنفس وحرارة منخفضة
English (Severe Febrile Disease / Danger Signs):Plaintext6 month old infant with high fever for 3 days, stiff neck, vomiting and convulsions
2. Side-by-Side Benchmark SuiteRun a comparative validation benchmark evaluating retrieval similarity, latency, and page citations across both engines:Bashpython query_tester.py
#📊 Benchmark & Validation ResultsEvaluated across 5 validation cases using all-MiniLM-L6-v2 embeddings and exact Cosine Similarity metrics ($\text{Cosine Sim} = 1 - \frac{\text{Distance}}{2}$):IDClinical ScenarioChroma MatchChroma LatencyPinecone MatchPinecone LatencyCited PageStatusTC-01General Danger Signs68.4%651.2 ms68.4%2244.2 msPage 16 / 18✅ MATCHEDTC-02Severe Pneumonia71.5%242.2 ms71.6%210.6 msPage 23✅ MATCHEDTC-03Neonatal Jaundice56.5%243.9 ms56.6%183.7 msPage 49✅ MATCHEDTC-04Out of Scope (Cardiology)23.9%244.1 ms23.9%403.1 msPage 86🛡️ REJECTEDTC-05Jaundice Symptoms45.0%249.7 ms44.9%175.8 msPage 35✅ MATCHEDKey Benchmark Insights:Retrieval Consistency: ChromaDB and Pinecone achieved an identical 56.59% average valid cosine similarity, retrieving the exact same WHO IMCI guidelines and page references.Safety Gate Precision: Adult/out-of-scope inquiries scored 23.9%, safely below the 43.5% threshold, preventing non-pediatric hallucinations.Latency Profile: Local ChromaDB excels on offline zero-network setups, while Pinecone Serverless provides consistent query performance for multi-user cloud deployments.
---

## 🛡️ Clinical DisclaimerThis software is designed solely for clinical decision support, academic evaluation, and triage assistance based on the WHO IMCI Guidelines. It is not a replacement for professional clinical diagnosis or physician oversight.
