# 📱 PediaCare.AI — 10-Screen Flutter CDSS Application Walkthrough

## 🌟 Overview
PediaCare.AI is a pediatric clinical decision support system fully conforming to the official **WHO Integrated Management of Childhood Illness (IMCI) Model Handbook** (142 pages).

Built with **BLoC/Cubit Architecture**, deterministic on-device offline clinical decision trees, AES-256 encrypted Hive local medical record storage, and seamless REST integration with the Phase 1 FastAPI & ChromaDB clinical RAG engine.

---

## 🎨 Theme & Clinical Design Tokens
- **Slate Navy (`#0A192F`, `#0F172A`)**: Clinical dashboard background, deep app headers.
- **Medical Teal (`#0D9488`, `#14B8A6`)**: Primary interactive controls, buttons, and active indicators.
- **Cyber Cyan (`#06B6D4`)**: Fluid level accents, breath counter target, glowing pulse badges.
- **Emergency Red (`#DC2626`, `#EF4444`)**: 🔴 RED Triage (Urgent Pre-referral Treatment & Hospital Referral).
- **Clinical Amber (`#D97706`, `#F59E0B`)**: 🟡 YELLOW Triage (Specific Clinic Treatment & Follow-up).
- **Safe Emerald (`#059669`, `#10B981`)**: 🟢 GREEN Triage (Safe Home Care & Danger Signs Counseling).
- **Typography**: Google Fonts **Cairo** for Arabic clinical scripts and **Inter** for Latin metrics, numbers, and citations.

---

## 📱 10 Complete Production Screens

| Screen # | Screen File | Key Clinical Features |
| :--- | :--- | :--- |
| **01** | `01_role_selection_screen.dart` | Animated pulsing stethoscope brand logo, 3 role selection cards (Parent, Pediatrician, Clinic), interactive legal & medical disclaimer dialog. |
| **02** | `02_child_selection_screen.dart` | Hero active child card, saved profiles list, "Add Child" modal with real-time age (7d–5y) and weight (2–35kg) safety guardrails. Zero-mock start. |
| **03** | `03_smart_chat_screen.dart` | Interactive chat stream, symptom quick-chips, duration selector, 60s interactive chest-tap respiratory counter dialog, voice note simulator, offline indicator. |
| **04** | `04_assessment_result_screen.dart` | Hero triage badge (🔴/🟡/🟢), summary findings cards, and **0ms instant verification recalculation** with interactive Yes/No question buttons. |
| **05** | `05_evidence_sources_screen.dart` | Retrieved WHO IMCI evidence cards with page badges (e.g. `ص 20 من 142`), relevance score meters, and **1-tap Arabic/English toggle** with LTR English excerpts. |
| **06** | `06_doctor_summary_screen.dart` | Structured SBAR handoff note (Situation, Background, Assessment, Recommendation), primary complaint matrix, and system share sheet export. |
| **07** | `07_doctor_workstation_screen.dart` | Differential diagnosis probability bars, 8 IMCI rapid checklists, discrete weight-band dosing calculator with interactive syringe visualizer, Plan C IV resuscitation calculator, and encrypted SBAR QR code. |
| **08** | `08_symptom_timeline_screen.dart` | Chronological daily symptom evolution tracker (Temperature °C, cough status, diarrhea frequency, feeding status) with add-log modal. |
| **09** | `09_child_profile_screen.dart` | Complete health record (allergies, chronic conditions, regular medications, clinician notes, edit & delete profile). |
| **10** | `10_consultation_history_screen.dart` | Searchable past consultation log color-coded by triage level (🔴/🟡/🟢) with quick re-open action and FAB for new consults. |

---

## ⚡ Core Technical Highlights

### 1. 0ms Instant Verification Recalculation
- Handled locally in `ui/lib/utils/offline_imci_engine.dart` and `ui/lib/cubit/assessment_cubit.dart`.
- When a clinician or parent toggles a missing clinical sign (e.g., *Chest Indrawing* or *Stridor*) on Screen 04, the triage level instantly recalculates from 🟢/🟡 to 🔴 in **0.00 seconds** without waiting for network I/O.

### 2. Encrypted Local Storage (Zero Mock Data)
- `ui/lib/services/storage_service.dart` initializes Hive with **256-bit AES encryption** (`HiveAesCipher`).
- Clean initial state: No fake/placeholder names; child profiles and consultation logs persist securely on the user's device.

### 3. Automated Test Suite (100% Passed)
- **Engine Tests**: 7 deterministic clinical test cases covering Severe Pneumonia (RED), Pneumonia (YELLOW), Cold/No Pneumonia (GREEN), Plan C Dehydration (RED), Dysentery (YELLOW), Young Infant PSBI (RED), and Dynamic Escalation.
- **Widget Tests**: TriageBadgeWidget rendering and App initialization boot test.
- **Result**: `00:01 +9: All tests passed!`

---

## 🚀 Execution & Running Instructions

### 1. Start Backend Server (Phase 1):
```bash
python backend/server.py
# Running at http://127.0.0.1:8000
```

### 2. Run Flutter App (Phase 2):
```bash
cd ui
flutter run
```

### 3. Run Automated Tests:
```bash
# Backend evaluation suite
python backend/evaluate_suite.py

# Frontend widget & engine test suite
cd ui && flutter test
```
