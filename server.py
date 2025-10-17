from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import google.generativeai as genai
import base64
import io
from PIL import Image
import os
from dotenv import load_dotenv

# -------------------------------------------------
# ✅ Load environment variables
# -------------------------------------------------
load_dotenv()

app = FastAPI(title="AfiyahMed API", version="1.0")

# ✅ CORS (for Flutter mobile/web)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # You can restrict later if needed
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -------------------------------------------------
# ✅ Load Gemini API key
# -------------------------------------------------
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if not GEMINI_API_KEY:
    raise ValueError("❌ GEMINI_API_KEY is missing! Please set it in environment variables.")
else:
    print("✅ GEMINI_API_KEY found successfully!")

genai.configure(api_key=GEMINI_API_KEY)

# -------------------------------------------------
# ✅ Root route (for quick health check)
# -------------------------------------------------
@app.get("/")
def home():
    return {"message": "🌿 AfiyahMed Server is running successfully!"}


# -------------------------------------------------
# ✅ Flutter app calls this endpoint
# -------------------------------------------------
class PredictRequest(BaseModel):
    symptoms: str
    image_base64: str


@app.post("/predict_json")
async def predict_json(request: PredictRequest):
    try:
        # --- Decode image from base64 ---
        image_data = base64.b64decode(request.image_base64)
        image = Image.open(io.BytesIO(image_data))
        temp_path = "temp_image.jpg"
        image.save(temp_path)

        # --- Upload to Gemini ---
        gemini_file = genai.upload_file(temp_path)

        # --- Compose a smart prompt for Gemini ---
        prompt = f"""
        You are a medical image analysis assistant.
        The patient reports: {request.symptoms}.
        Analyze the uploaded skin image and symptoms.
        Return a structured JSON prediction with these fields:
        - top_diseases: list of dicts (name, confidence in %)
        - explanation: short text
        - urgency: Low/Medium/High
        - recommended_next_steps: list of next actions
        - disclaimer: short note reminding user to consult a doctor.
        """

        model = genai.GenerativeModel("gemini-2.5-flash")
        response = model.generate_content([prompt, gemini_file])

        text = response.text.strip()

        # --- If Gemini returned raw JSON, try to parse it ---
        import json
        try:
            prediction = json.loads(text)
        except json.JSONDecodeError:
            prediction = {"raw_text": text}

        return {"prediction": prediction}

    except Exception as e:
        print("❌ Error:", e)
        raise HTTPException(status_code=500, detail=str(e))


# -------------------------------------------------
# ✅ Simple chat endpoint (optional)
# -------------------------------------------------
@app.post("/chat")
async def chat(prompt: str):
    try:
        model = genai.GenerativeModel("gemini-2.5-flash")
        response = model.generate_content(prompt)
        return {"response": response.text}
    except Exception as e:
        print("❌ Chat error:", e)
        return {"error": str(e)}


# -------------------------------------------------
# ✅ Local run (Render will ignore this)
# -------------------------------------------------
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=10000)
