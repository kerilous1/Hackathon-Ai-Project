import sys
from pathlib import Path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from fastapi.testclient import TestClient
from backend.server import app

client = TestClient(app)

print("🧪 1. Testing /api/v1/health endpoint...")
r_health = client.get("/api/v1/health")
print("Health Status:", r_health.status_code, r_health.json())
assert r_health.status_code == 200

print("\n🧪 2. Testing /api/v1/calculator/dosage (Amoxicillin 7.5kg)...")
r_dose = client.post("/api/v1/calculator/dosage", json={"medication": "amoxicillin", "weight_kg": 7.5})
print("Dosage Response:", r_dose.status_code, r_dose.json())
assert r_dose.status_code == 200
assert r_dose.json()["volume_ml"] == 5.0

print("\n🧪 3. Testing /api/v1/calculator/iv-fluids (Plan C, 10kg, 14m)...")
r_iv = client.post("/api/v1/calculator/iv-fluids", json={"weight_kg": 10.0, "age_months": 14.0})
print("IV Response:", r_iv.status_code, r_iv.json()["stage_1"])
assert r_iv.status_code == 200
assert r_iv.json()["total_volume_ml"] == 1000.0

print("\n🧪 4. Testing Adult Pharmacology Boundary Filter (Nitroglycerin)...")
r_refusal = client.post("/api/v1/triage/assess", json={"query": "Adult coronary artery disease and sublingual nitroglycerin"})
print("Refusal Status:", r_refusal.status_code, r_refusal.json()["status"], r_refusal.json().get("refusal_type"))
assert r_refusal.json()["status"] == "refusal"

print("\n🧪 5. Testing Clinical Triage Assessment (Severe Pneumonia)...")
r_assess = client.post("/api/v1/triage/assess", json={
    "query": "طفل عمره 14 شهراً يعاني من كحة وتنفس سريع 48 نفس/د مع انسحاب أسفل جدار الصدر للداخل",
    "age_months": 14.0,
    "weight_kg": 9.5
})
print("Assess Status:", r_assess.status_code, "Triage:", r_assess.json().get("triage_level"))
assert r_assess.status_code == 200
assert r_assess.json().get("triage_level") == "RED"

print("\n🎉 ALL FASTAPI SERVER ENDPOINTS VERIFIED AND PASSING!")
