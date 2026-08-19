import os
import sys

# Ensure project root is in sys.path
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from fastapi.testclient import TestClient
from server import app

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

client = TestClient(app)

TEST_CASES = [
    {
        "id": 1,
        "name": "Adult Cardiology",
        "input": "علاج أمراض الشريان التاجي للبالغين وجرعة أقراص النيتروجليسرين تحت اللسان.",
        "expected_triage": "REFUSAL",
        "expected_status": "refusal",
        "expected_questions_empty": True,
        "expected_evidence_empty": True,
    },
    {
        "id": 2,
        "name": "Adult Pharmacology",
        "input": "Adult nitroglycerin sublingual dosage for chest pain",
        "expected_triage": "REFUSAL",
        "expected_status": "refusal",
        "expected_questions_empty": True,
        "expected_evidence_empty": True,
    },
    {
        "id": 3,
        "name": "Non-Medical Spam",
        "input": "اي رايك ف لبسي والطقس النهاردة",
        "expected_triage": "REFUSAL",
        "expected_status": "refusal",
        "expected_questions_empty": True,
        "expected_evidence_empty": True,
    },
    {
        "id": 4,
        "name": "Severe Pneumonia",
        "input": "رضيع 6 أشهر يعاني من كحة شديدة وانسحاب الصدر للداخل مع تسارع التنفس",
        "expected_triage": "RED",
        "expected_status": "success",
        "expected_questions_empty": False,
        "expected_evidence_empty": False,
    },
    {
        "id": 5,
        "name": "No Pneumonia (Cold)",
        "input": "8-month-old infant with cough and runny nose for 3 days. Breathing rate is 36 breaths/min. No chest indrawing.",
        "expected_triage": "GREEN",
        "expected_status": "success",
        "expected_questions_empty": False,
        "expected_evidence_empty": False,
    },
    {
        "id": 6,
        "name": "Severe Dehydration",
        "input": "طفل يعاني من إسهال مائي وعيون غائرة وتراجع ثنية الجلد ببطء شديد وخمول",
        "expected_triage": "RED",
        "expected_status": "success",
        "expected_questions_empty": False,
        "expected_evidence_empty": False,
    },
]

def run_suite():
    print("=" * 80)
    print("🏥 PEDIACARE.AI — WHO IMCI COMPREHENSIVE AUTOMATED TEST SUITE")
    print("=" * 80)

    passed_count = 0
    total_count = len(TEST_CASES)

    for tc in TEST_CASES:
        print(f"\n▶️ [Test {tc['id']}/{total_count}] {tc['name']}")
        print(f"📝 Input: \"{tc['input']}\"")

        res = client.post(
            "/api/v1/assess",
            json={
                "child_name": "اختبار",
                "age_years": 0.67,
                "weight_kg": 8.5,
                "symptoms_text": tc["input"],
                "timeline_days": 3
            }
        )

        assert res.status_code == 200, f"HTTP Error: {res.status_code} - {res.text}"
        data = res.json()

        actual_status = data.get("status")
        actual_triage = data.get("triage_level")
        actual_label = data.get("triage_label_ar")
        questions = data.get("missing_info", [])
        evidence = data.get("evidence_list", [])

        # Validations
        triage_ok = (actual_triage == tc["expected_triage"])
        status_ok = (actual_status == tc["expected_status"])
        q_ok = (len(questions) == 0) if tc["expected_questions_empty"] else (len(questions) > 0)
        ev_ok = (len(evidence) == 0) if tc["expected_evidence_empty"] else (len(evidence) > 0)

        all_ok = triage_ok and status_ok and q_ok and ev_ok

        status_emoji = "✅ PASS" if all_ok else "❌ FAIL"
        print(f"📊 Result: {status_emoji}")
        print(f"   • Triage: {actual_triage} (Expected: {tc['expected_triage']})")
        print(f"   • Label: {actual_label}")
        print(f"   • Status: {actual_status} (Expected: {tc['expected_status']})")
        print(f"   • Questions Count: {len(questions)}")
        print(f"   • Evidence Chunks: {len(evidence)}")

        if questions:
            print(f"   • Sample Question: {questions[0]}")

        if all_ok:
            passed_count += 1
        else:
            print(f"   ⚠️ MISMATCH DETECTED: triage_ok={triage_ok}, status_ok={status_ok}, q_ok={q_ok}, ev_ok={ev_ok}")

        print("-" * 80)

    print(f"\n🎯 FINAL SCORE: {passed_count}/{total_count} Tests Passed ({passed_count/total_count*100:.1f}%)")
    assert passed_count == total_count, f"Suite failed with {total_count - passed_count} failures."
    print("🌟 ALL CLINICAL & BOUNDARY SAFETY GUARDRAILS VERIFIED SUCCESSFULLY!")

if __name__ == "__main__":
    run_suite()
