# 🩺 Pedi-Guide AI: WHO IMCI Clinical Decision Support System

An evidence-based Clinical Decision Support System (CDSS) built with Retrieval-Augmented Generation (RAG). **Pedi-Guide AI** assists healthcare professionals by converting complex pediatric clinical presentations into grounded classifications, urgent pre-referral interventions, and verifiable citations strictly referenced from the official **WHO Integrated Management of Childhood Illness (IMCI) Guidelines**.

---

## 🌟 Key Features

* **Strict Clinical Grounding & Citations:** Restricts generative inference to retrieved WHO IMCI evidence blocks, citing exact printed handbook page numbers and hierarchical section titles to eliminate hallucinations.
* **Dual Vector Database Architecture:** Full dual-backend support allowing seamless switching between **ChromaDB** (embedded local vector storage) and **Pinecone Serverless** (managed cloud vector index).
* **Cross-Lingual Clinical Translation:** Native multi-language support (Arabic & English). Automatically converts vernacular Arabic clinical complaints into standardized medical English queries for high-precision semantic retrieval while returning structured responses in the clinician's language.
* **Out-of-Scope Safeguard Gate:** Employs exact Cosine Similarity metric filtering ($43.5\%$ threshold) to automatically detect and reject adult or non-pediatric clinical inquiries.
* **Zero-Downtime Multi-Model Fallback:** Dynamic client-side failover across `gemini-3.5-flash`, `gemini-3.7-flash`, and `gemini-3.1-flash-lite` to mitigate API pressure spikes (`503 UNAVAILABLE` or `429 Rate Limit`).

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
       [ Grounded Response: Triage / Actions / Citations ]
