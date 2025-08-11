# Whisper Answer Assistant

Whisper Answer Assistant is a real-time English speech recognition (ASR) and short, speakable response generation system. It uses the `faster-whisper` model to transcribe audio from the microphone, and if the transcribed text is an English question, it returns a quick answer via the OpenAI Chat API. Through its HTTP API, iOS or other clients can connect to the backend to receive responses.

## 🚀 Features
- Real-time audio listening (segmentation via WebRTC VAD)
- LLM-based short answer generation (ChatGPT `gpt-4o-mini` by default)
- Language and question filtering (only English questions are processed)
- API security with Bearer Token
- iOS/Android client support
- Optional clipboard copy of the answer

## 📦 Requirements
- Python 3.9+
- macOS / Linux / Windows (with microphone access)
- ffmpeg (recommended for `faster-whisper`)
- OpenAI API key

## 📂 Installation
1. Clone the repository:
    ```bash
    git clone https://github.com/kullanici/whisper-answer-assistant.git
    cd whisper-answer-assistant
    ```
2. Prepare the environment:
    ```bash
    python -m venv .venv
    source .venv/bin/activate   # Windows: .venv\Scripts\activate
    pip install -e .
    ```
3. Create `.env` file:
    ```bash
    OPENAI_API_KEY=sk-xxxx
    APP_BEARER_TOKEN=abc123
    HOST=0.0.0.0
    PORT=8787
    RELOAD=1
    ```
4. (Optional) Adjust configuration in `configs/settings.yaml`  
   You can change values such as `model`, `min_char`, `force_language_en`.

## 💻 Running the Backend
```bash
export OPENAI_API_KEY=sk-xxxx
export APP_BEARER_TOKEN=abc123
python -m uvicorn server.api:app --host 0.0.0.0 --port 8787 --reload


Health check:

curl http://127.0.0.1:8787/health


Example API request:

curl -N -H "Authorization: Bearer abc123" \
-H "Content-Type: application/json" \
-d '{"text":"What is the fastest way to debounce API calls on iOS?"}' \
http://127.0.0.1:8787/v1/answer

🎧 CLI Mode (Microphone)
python -m waa.cli --list-devices
python -m waa.cli --device 2 --whisper-model base


📱 Connecting from iOS or Other Clients
Find the LAN IP address of the Mac running the backend:

ipconfig getifaddr en0


Example: 192.168.1.3

Use the backend URL in the iOS client:

http://192.168.1.3:8787/v1/answer

Include header:

Authorization: Bearer abc123

🛠 Troubleshooting
"OPENAI_API_KEY missing" → Make sure .env is created and variables are exported.

"Address already in use" → Stop the process using port 8787:
lsof -iTCP:8787 -sTCP:LISTEN
kill -9 <PID>


Timeout (iOS) → Ensure both Mac and iOS device are on the same Wi-Fi and the correct IP is used.

📄 License
MIT






