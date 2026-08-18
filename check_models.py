import os
from google import genai

API_KEY = os.getenv("GEMINI_API_KEY", "AQ.Ab8RN6LGKWbPXRtEzqNKqNbohrVXKTk961gYEv1eK5DnmAxiPg")
client = genai.Client(api_key=API_KEY)

print("🔍 فحص الموديلات المتاحة لمفتاحك...\n")
available = []
for model in client.models.list():
    available.append(model.name)
    print(f"✅ متاح: {model.name}")

# تجربة أول موديل متاح فوراً
if available:
    chosen = available[0]
    print(f"\n🧪 اختبار استجابة من الموديل: {chosen}")
    try:
        response = client.models.generate_content(
            model=chosen,
            contents="Say 'IMCI Ready' in 2 words."
        )
        print(f"🎉 رد النموذج بنجاح: {response.text}")
    except Exception as e:
        print(f"❌ خطأ: {e}")
        