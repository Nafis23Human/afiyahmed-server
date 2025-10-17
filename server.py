from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
import google.generativeai as genai
import os

# ✅ Load API key directly from Render environment
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

if not GEMINI_API_KEY:
    raise ValueError("❌ GEMINI_API_KEY is not set in environment variables!")

# ✅ Configure Gemini
genai.configure(api_key=GEMINI_API_KEY)

app = FastAPI()

# ✅ CORS setup (for Flutter or web)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # You can restrict this to your domain later
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def home():
    return {"message": "✅ AfiyahMed API is running successfully!"}

# ✅ Example endpoint for image or text-based analysis
@app.post("/analyze/")
async def analyze_image(file: UploadFile = File(...)):
    try:
        contents = await file.read()
        model = genai.GenerativeModel("gemini-1.5-flash")

        response = model.generate_content(["Analyze this image:", contents])
        return {"result": response.text}
    except Exception as e:
        return {"error": str(e)}
