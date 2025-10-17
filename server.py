from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
import google.generativeai as genai
import os
from dotenv import load_dotenv

# Load .env file for local use (Render ignores it)
load_dotenv()

# Create FastAPI app
app = FastAPI()

# Allow all origins (you can restrict later if needed)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Load Gemini API Key ---
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

if not GEMINI_API_KEY:
    print("⚠️ GEMINI_API_KEY missing! Environment keys available:")
    for key in os.environ.keys():
        print("   ", key)
    raise ValueError("❌ GEMINI_API_KEY is not set in environment variables!")
else:
    print("✅ GEMINI_API_KEY found successfully!")

# Configure Gemini client
genai.configure(api_key=GEMINI_API_KEY)


# --- Routes ---
@app.get("/")
def home():
    return {"message": "✅ AfiyahMed Server is running successfully!"}


@app.post("/analyze_image/")
async def analyze_image(file: UploadFile = File(...)):
    try:
        contents = await file.read()

        # Upload image to Gemini
        image = genai.upload_file(file.name, contents)

        # Use Gemini model
        model = genai.GenerativeModel("gemini-1.5-flash")
        response = model.generate_content(
            ["Analyze this medical image and describe what you observe.", image]
        )

        return {"analysis": response.text}

    except Exception as e:
        print("❌ Error analyzing image:", e)
        return {"error": str(e)}


@app.post("/chat/")
async def chat(prompt: str):
    try:
        model = genai.GenerativeModel("gemini-1.5-flash")
        response = model.generate_content(prompt)
        return {"response": response.text}
    except Exception as e:
        print("❌ Chat error:", e)
        return {"error": str(e)}


# Run locally (ignored on Render)
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=10000)
