import os
import re
import sys

# Ensure project root is in sys.path
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

import pandas as pd
from typing import Dict, List, Tuple
import doctor_assistant

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

def parse_expected_pages(page_str: str) -> List[int]:
    """Parse page ranges and individual numbers into a list of valid integer page numbers."""
    if not page_str or "N/A" in str(page_str):
        return []
    
    clean = str(page_str).replace("Page", "").replace("page", "").replace("ص", "").strip()
    pages = []
    
    # Split by comma or semicolon
    parts = re.split(r'[,;]', clean)
    for part in parts:
        part = part.strip()
        if "-" in part:
            range_parts = part.split("-")
            try:
                start_p = int(range_parts[0].strip())
                end_p = int(range_parts[1].strip())
                pages.extend(list(range(start_p, end_p + 1)))
            except ValueError:
                pass
        else:
            try:
                pages.append(int(part.strip()))
            except ValueError:
                pass
    return sorted(list(set(pages)))

def evaluate_test_case(row: pd.Series) -> Dict:
    cid = row["ID"]
    category = row["Category"]
    test_type = row["Test Type"]
    scenario_en = str(row["Clinical Scenario (English)"])
    scenario_ar = str(row["Clinical Scenario (Arabic)"])
    expected_triage_raw = str(row["Triage Level"])
    expected_section = str(row["Section Title"])
    expected_page_raw = str(row["Page Number"])

    # Determine expected standard triage code
    if "RED" in expected_triage_raw.upper() or "🔴" in expected_triage_raw:
        expected_triage = "RED"
    elif "YELLOW" in expected_triage_raw.upper() or "🟡" in expected_triage_raw:
        expected_triage = "YELLOW"
    elif "GREEN" in expected_triage_raw.upper() or "🟢" in expected_triage_raw:
        expected_triage = "GREEN"
    elif "REFUSAL" in expected_triage_raw.upper() or "🛡️" in expected_triage_raw:
        expected_triage = "REFUSAL"
    else:
        expected_triage = "UNKNOWN"

    valid_expected_pages = parse_expected_pages(expected_page_raw)

    # We evaluate using the Arabic clinical query (primary UI locale) and English query
    eval_query = scenario_ar if scenario_ar and scenario_ar != "nan" else scenario_en

    # Run clinical RAG query
    result = doctor_assistant.run_clinical_query(eval_query)

    actual_status = result.get("status")
    actual_triage = result.get("triage_level")
    chunks = result.get("chunks", [])

    # 1. Triage Match Validation
    triage_ok = (actual_triage == expected_triage)

    # 2. Page Retrieval Match Validation
    page_ok = False
    top_page = "N/A"
    top_section = "N/A"
    top_score = result.get("top_score", 0.0)

    if expected_triage == "REFUSAL":
        # Out-of-scope / Refusal should return 0 evidence chunks or refusal
        page_ok = (actual_status == "refusal" or len(chunks) == 0 or valid_expected_pages == [])
        top_page = "N/A (Refusal Guard)"
        top_section = "Safeguard / Out of Scope"
    else:
        if chunks:
            top_chunk = chunks[0]
            top_page_str = str(top_chunk.get("page", "N/A"))
            top_section = top_chunk.get("section", "N/A")
            top_score = top_chunk.get("score", top_score)
            
            try:
                top_page_int = int(top_page_str)
                top_page = str(top_page_int)
                page_ok = (top_page_int in valid_expected_pages)
            except ValueError:
                top_page = top_page_str
                page_ok = any(str(p) in top_page_str for p in valid_expected_pages)

    # Overall Pass/Fail
    overall_pass = triage_ok and page_ok

    return {
        "id": cid,
        "category": category,
        "test_type": test_type,
        "scenario": eval_query,
        "expected_triage": expected_triage,
        "actual_triage": actual_triage,
        "triage_ok": triage_ok,
        "expected_page": expected_page_raw,
        "actual_page": top_page,
        "page_ok": page_ok,
        "expected_section": expected_section,
        "actual_section": top_section,
        "top_score": top_score,
        "overall_pass": overall_pass,
        "evidence_count": len(chunks),
    }

def run_benchmark():
    dataset_candidates = [
        os.path.join(PROJECT_ROOT, "docs", "WHO_IMCI_Clinical_Benchmark_Dataset.xlsx"),
        os.path.join(PROJECT_ROOT, "WHO_IMCI_Clinical_Benchmark_Dataset.xlsx"),
        "docs/WHO_IMCI_Clinical_Benchmark_Dataset.xlsx",
        "WHO_IMCI_Clinical_Benchmark_Dataset.xlsx",
    ]
    dataset_path = None
    for candidate in dataset_candidates:
        if os.path.exists(candidate):
            dataset_path = candidate
            break

    if not dataset_path:
        print(f"Error: Could not find 'WHO_IMCI_Clinical_Benchmark_Dataset.xlsx' in {dataset_candidates}")
        sys.exit(1)

    df = pd.read_excel(dataset_path)
    print("=" * 90)
    print("🏥 PEDIACARE.AI — WHO IMCI 15-CASE BENCHMARK AUTOMATED EVALUATION SCORECARD")
    print("=" * 90)

    results = []
    for idx, row in df.iterrows():
        res = evaluate_test_case(row)
        results.append(res)

        status_emoji = "✅ PASS" if res["overall_pass"] else "❌ FAIL"
        print(f"\n▶️ [{res['id']}] Domain: {res['category']} | Type: {res['test_type']}")
        print(f"   📝 Scenario: \"{res['scenario'][:85]}...\"")
        print(f"   🎯 Expected: Triage=[{res['expected_triage']}], Page=[{res['expected_page']}]")
        print(f"   🔍 Actual:   Triage=[{res['actual_triage']}], Page=[{res['actual_page']}], Score=[{res['top_score']:.1f}%]")
        print(f"   📚 Section:  \"{res['actual_section'][:60]}\"")
        print(f"   📊 Verdict:  {status_emoji} (Triage: {'OK' if res['triage_ok'] else 'FAIL'}, Page: {'OK' if res['page_ok'] else 'FAIL'})")
        print("-" * 90)

    passed = sum(1 for r in results if r["overall_pass"])
    total = len(results)
    pct = (passed / total) * 100.0

    print("\n" + "=" * 90)
    print(f"🎯 BENCHMARK FINAL SUMMARY: {passed}/{total} Tests Passed ({pct:.1f}% Precision)")
    print("=" * 90)

    if passed == total:
        print("🌟 100.0% BENCHMARK PRECISION ACHIEVED ACROSS ALL WHO IMCI PROTOCOLS!")
    else:
        print(f"⚠️ {total - passed} test cases need fine-tuning.")

    # Save structured Markdown evaluation report in docs/
    report_md = ["# 📊 WHO IMCI Clinical Benchmark Dataset — Automated Evaluation Scorecard\n\n",
                 f"**Evaluation Date:** {pd.Timestamp.now().strftime('%Y-%m-%d %H:%M:%S')}  \n",
                 f"**Final Score:** **{passed}/{total} ({pct:.1f}%) Passed**  \n\n",
                 "| ID | Domain | Expected Triage | Actual Triage | Expected Page | Top Page | Match Score | Verdict |\n",
                 "| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |\n"]

    for r in results:
        v_str = "✅ PASS" if r["overall_pass"] else "❌ FAIL"
        report_md.append(f"| **{r['id']}** | {r['category']} | `{r['expected_triage']}` | `{r['actual_triage']}` | {r['expected_page']} | {r['actual_page']} | {r['top_score']:.1f}% | {v_str} |\n")

    report_out = os.path.join(PROJECT_ROOT, "docs", "benchmark_evaluation_report.md")
    with open(report_out, "w", encoding="utf-8") as f:
        f.writelines(report_md)
    print(f"📁 Saved detailed scorecard to '{report_out}'")

    assert passed == total, f"Benchmark failed with {total - passed} failures."

if __name__ == "__main__":
    run_benchmark()
