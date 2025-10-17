# server.py
import os
import base64
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# Optional: Gemini AI
try:
    import google.generativeai as genai
    USE_GEMINI = True
except ImportError:
    USE_GEMINI = False

# -------------------------
# Get Gemini API key safely
# -------------------------
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if USE_GEMINI and not GEMINI_API_KEY:
    raise ValueError("GEMINI_API_KEY is not set in environment variables!")

if USE_GEMINI:
    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel("gemini-2.5-flash")

# -------------------------
# Initialize FastAPI
# -------------------------
app = FastAPI(title="AfiyahMed AI Skin Diagnosis")

# Enable CORS for Flutter Web/Desktop/Mobile
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -------------------------
# Request model
# -------------------------
class PredictRequest(BaseModel):
    symptoms: str
    image_base64: str

# -------------------------
# Predict endpoint
# -------------------------
@app.post("/predict_json")
async def predict_json(request: PredictRequest):
    try:
        # Decode image
        image_bytes = base64.b64decode(request.image_base64)

        prompt = f"""
        You are a medical AI assistant.
        Analyze the patient's image and the symptoms: {request.symptoms}.
        Provide possible diseases, explanations, urgency, and next steps.
        """

        if USE_GEMINI:
            response = model.generate_content([
                prompt,
                {"mime_type": "image/jpeg", "data": image_bytes}
            ])
            return {"prediction": response.text}
        else:
            # Dummy response for local testing
            return {
                "prediction": {
                    "top_diseases": [
                        {"name": "Eczema", "confidence": "75%"},
                        {"name": "Psoriasis", "confidence": "20%"}
                    ],
                    "explanation": "Based on the image and symptoms, the AI suspects common skin conditions.",
                    "urgency": "Moderate",
                    "recommended_next_steps": [
                        "Consult a dermatologist",
                        "Apply moisturizer",
                        "Avoid scratching affected area"
                    ],
                    "disclaimer": "This is an AI-based suggestion, not a medical diagnosis."
                }
            }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
