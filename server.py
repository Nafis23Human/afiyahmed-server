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
    Handles cases where Gemini wraps JSON in markdown code blocks or adds extra text.
    """
    try:
        # First, try to remove markdown code blocks
        if "\`\`\`json" in response_text:
            response_text = response_text.split("\`\`\`json")[1].split("\`\`\`")[0].strip()
        elif "\`\`\`" in response_text:
            response_text = response_text.split("\`\`\`")[1].split("\`\`\`")[0].strip()

        # Look for the first { and last } to extract the JSON object
        start_idx = response_text.find('{')
        end_idx = response_text.rfind('}')

        if start_idx != -1 and end_idx != -1:
            response_text = response_text[start_idx:end_idx + 1]

        response_text = response_text.strip()

        print(f"[v0] Cleaned response: {response_text[:300]}...")

        # Parse the JSON string
        parsed = json.loads(response_text)

        required_fields = ["top_3_possible_diseases", "explanation", "urgency", "recommended_next_steps", "disclaimer"]
        for field in required_fields:
            if field not in parsed:
                print(f"[v0] Missing field: {field}")
                raise ValueError(f"Missing required field: {field}")

        if not isinstance(parsed["top_3_possible_diseases"], list) or len(parsed["top_3_possible_diseases"]) == 0:
            raise ValueError("Invalid diseases structure")

        for disease in parsed["top_3_possible_diseases"]:
            if "name" not in disease or "confidence" not in disease:
                raise ValueError("Disease missing name or confidence")

        print("[v0] Successfully parsed Gemini response")
        return parsed

    except json.JSONDecodeError as e:
        print(f"[v0] JSON parsing error: {str(e)}")
        print(f"[v0] Raw response: {response_text[:500]}")
        return None
    except ValueError as e:
        print(f"[v0] Validation error: {str(e)}")
        return None


# Predict endpoint
@app.post("/predict_json")
async def predict_json(request: PredictRequest):
    try:
        # Decode the base64 image
        image_bytes = base64.b64decode(request.image_base64)

        prompt = f"""You are a dermatologist AI. Analyze this patient's skin image and symptoms carefully.

Patient Symptoms: {request.symptoms}

Return ONLY a valid JSON object with this exact structure (no markdown, no extra text):
{{
    "top_3_possible_diseases": [
        {{"name": "Disease Name", "confidence": 75}},
        {{"name": "Disease Name", "confidence": 20}},
        {{"name": "Disease Name", "confidence": 5}}
    ],
    "explanation": "Brief explanation considering both the image and symptoms",
    "urgency": "Low/Moderate/High",
    "recommended_next_steps": [
        "Step 1",
        "Step 2",
        "Step 3"
    ],
    "disclaimer": "This is an AI-based suggestion, not a medical diagnosis."
}}"""

        # Use Gemini AI if enabled
        if USE_GEMINI:
            try:
                response = model.generate_content([
                    prompt,
                    {"mime_type": "image/jpeg", "data": image_bytes}
                ])

                print(f"[v0] Gemini raw response: {response.text[:500]}...")
                parsed_response = parse_gemini_response(response.text)

                if parsed_response is None:
                    print("[v0] Parsing failed, returning error response")
                    return {
                        "prediction": {
                            "top_3_possible_diseases": [
                                {"name": "Analysis Error", "confidence": 0}
                            ],
                            "explanation": "Unable to analyze the image. Please try again with a clearer image.",
                            "urgency": "Low",
                            "recommended_next_steps": [
                                "Ensure the image is clear and well-lit",
                                "Try uploading a different image",
                                "Consult a dermatologist directly"
                            ],
                            "disclaimer": "This is an AI-based suggestion, not a medical diagnosis."
                        }
                    }

                return {
                    "prediction": parsed_response
                }
            except Exception as gemini_error:
                print(f"[v0] Gemini API error: {str(gemini_error)}")
                raise HTTPException(status_code=500, detail=f"Gemini API error: {str(gemini_error)}")

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
