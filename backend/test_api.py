import os
from dotenv import load_dotenv
from google import genai

load_dotenv()
api_key = os.getenv("GEMINI_API_KEY")
client = genai.Client(api_key=api_key)

models_to_test = [
    "gemini-3.6-flash",
    "gemini-3.7-flash",
    "gemini-3.5-flash",
    "gemini-flash-latest",
    "gemini-2.5-flash-lite",
    "gemini-3.1-flash-lite"
]

for m in models_to_test:
    try:
        resp = client.models.generate_content(
            model=m,
            contents="Respond in 2 words: IMCI Verified"
        )
        print(f"✅ Model {m} works! Response: {resp.text.strip()}")
        break
    except Exception as e:
        print(f"❌ Model {m} failed: {e}")
