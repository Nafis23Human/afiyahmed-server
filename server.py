import os
import base64
import random
import json
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


def parse_gemini_response(response_text):
    """
    Parse the JSON response from Gemini AI.
    Handles cases where Gemini wraps JSON in markdown code blocks.
    """
    try:
        # Remove markdown code blocks if present (\`\`\`json ... \`\`\`)
        if "\`\`\`json" in response_text:
            response_text = response_text.split("\`\`\`json")[1].split("\`\`\`")[0].strip()
        elif "\`\`\`" in response_text:
            response_text = response_text.split("\`\`\`")[1].split("\`\`\`")[0].strip()

        # Parse the JSON string
        parsed = json.loads(response_text)
        return parsed
    except json.JSONDecodeError:
        # If parsing fails, return a default response
        return {
            "top_3_possible_diseases": [
                {"name": "Unable to parse", "confidence": 100}
            ],
            "explanation": "Error parsing AI response",
            "urgency": "Moderate",
            "recommended_next_steps": ["Consult a dermatologist"],
            "disclaimer": "This is an AI-based suggestion, not a medical diagnosis."
        }


# Predict endpoint
@app.post("/predict_json")
async def predict_json(request: PredictRequest):
    try:
        # Decode the base64 image
        image_bytes = base64.b64decode(request.image_base64)

        prompt = f"""
        You are a dermatologist AI. Analyze this patient's image and symptoms.

        Patient Symptoms: {request.symptoms}

        Return ONLY a valid JSON object (no markdown, no extra text) with this exact structure:
        {{
            "top_3_possible_diseases": [
                {{"name": "Disease Name", "confidence": 75}},
                {{"name": "Disease Name", "confidence": 20}},
                {{"name": "Disease Name", "confidence": 5}}
            ],
            "explanation": "Brief explanation of the diagnosis considering both image and symptoms",
            "urgency": "Low/Moderate/High",
            "recommended_next_steps": [
                "Step 1",
                "Step 2",
                "Step 3"
            ],
            "disclaimer": "This is an AI-based suggestion, not a medical diagnosis."
        }}
        """

        # Use Gemini AI if enabled
        if USE_GEMINI:
            response = model.generate_content([
                prompt,
                {"mime_type": "image/jpeg", "data": image_bytes}
            ])

            parsed_response = parse_gemini_response(response.text)

            # Return the properly structured response
            return {
                "prediction": parsed_response
            }

        # Dummy structured output for testing (always returns structured JSON)
        disease_names = ["Eczema", "Psoriasis", "Dermatitis", "Rosacea", "Fungal Infection"]
        random.shuffle(disease_names)
        percentages = [random.randint(20, 50) for _ in range(3)]
        total = sum(percentages)
        percentages = [round(p * 100 / total) for p in percentages]
        diff = 100 - sum(percentages)
        if diff != 0:
            percentages[0] += diff

        top_diseases = [
            {"name": disease_names[i], "confidence": percentages[i]}
            for i in range(3)
        ]

        return {
            "prediction": {
                "top_3_possible_diseases": top_diseases,
                "explanation": f"Based on the uploaded image and your reported symptoms ({request.symptoms}), these are the most likely skin conditions.",
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
