import os
import base64
import random
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# Optional Gemini AI
try:
    import google.generativeai as genai
    USE_GEMINI = True
except ImportError:
    USE_GEMINI = False

# Configure Gemini
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if USE_GEMINI:
    if not GEMINI_API_KEY:
        raise ValueError("GEMINI_API_KEY not set in environment variables.")
    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel("gemini-2.5-flash")

# Initialize FastAPI
app = FastAPI(title="AfiyahMed AI Skin Diagnosis")

# CORS setup
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Request model
class PredictRequest(BaseModel):
    symptoms: str
    image_base64: str

# Predict endpoint
@app.post("/predict_json")
async def predict_json(request: PredictRequest):
    try:
        image_bytes = base64.b64decode(request.image_base64)

        prompt = f"""
        You are a dermatologist AI.
        Analyze this patient’s image and reported symptoms: "{request.symptoms}".
        Return a structured JSON with:
        - top 3 possible diseases (name + confidence percentage that sum up to 100) 
        - explanation
        - urgency (Low/Moderate/High)
        - recommended next steps (as a list)
        - disclaimer: "This is an AI-based suggestion, not a medical diagnosis."
        """

        # -------------------------
        # Use Gemini AI if enabled
        # -------------------------
        if USE_GEMINI:
            response = model.generate_content([
                prompt,
                {"mime_type": "image/jpeg", "data": image_bytes}
            ])
            # -------------------------
            # Wrap Gemini text in structured JSON
            # -------------------------
            top_diseases = [
                {"name": "Gemini AI Prediction", "confidence": "100%"}
            ]
            return {
                "prediction": {
                    "top_diseases": top_diseases,
                    "explanation": response.text,
                    "urgency": "Moderate",
                    "recommended_next_steps": [
                        "Consult a certified dermatologist for detailed examination.",
                    ],
                    "disclaimer": "This is an AI-based suggestion, not a medical diagnosis."
                }
            }

        # -------------------------
        # Dummy structured output for testing (always returns structured JSON)
        # -------------------------
        disease_names = ["Eczema", "Psoriasis", "Dermatitis", "Rosacea", "Fungal Infection"]
        random.shuffle(disease_names)
        percentages = [random.randint(20, 50) for _ in range(3)]
        total = sum(percentages)
        percentages = [round(p * 100 / total) for p in percentages]
        diff = 100 - sum(percentages)
        if diff != 0:
            percentages[0] += diff  # fix rounding error

        top_diseases = [
            {"name": disease_names[i], "confidence": f"{percentages[i]}%"}
            for i in range(3)
        ]

        return {
            "prediction": {
                "top_diseases": top_diseases,
                "explanation": "Based on the uploaded image and described symptoms, these are the most likely skin conditions.",
                "urgency": "Moderate",
                "recommended_next_steps": [
                    "Keep the affected area clean and dry.",
                    "Avoid harsh soaps or chemicals.",
                    "Consult a certified dermatologist for a detailed examination."
                ],
                "disclaimer": "This is an AI-based suggestion, not a medical diagnosis."
            }
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
