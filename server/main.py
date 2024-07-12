from fastapi import FastAPI, Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
from firebase_admin import credentials, initialize_app, auth
from google.cloud import firestore
import google.generativeai as genai
import toml


app = FastAPI()
config = toml.load("config.toml")

# Firebase 초기화
cred = credentials.Certificate(config["firebase"]["service_account_key"])
initialize_app(cred)

# Firestore 클라이언트 초기화
db = firestore.Client()

# Gemini API 설정
genai.configure(api_key=config["gemini"]["api_key"])
model = genai.GenerativeModel(config["gemini"]["model"])

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

async def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        decoded_token = auth.verify_id_token(token)
        return decoded_token['uid']
    except:
        raise HTTPException(status_code=401, detail="Invalid authentication credentials")

@app.post("/login")
async def login(id_token: str):
    try:
        decoded_token = auth.verify_id_token(id_token)
        return {"access_token": id_token, "token_type": "bearer"}
    except:
        raise HTTPException(status_code=401, detail="Invalid Firebase ID token")

@app.get("/user_info")
async def get_user_info(current_user: str = Depends(get_current_user)):
    user_ref = db.collection('users').document(current_user)
    user_doc = user_ref.get()
    if user_doc.exists:
        return user_doc.to_dict()
    else:
        raise HTTPException(status_code=404, detail="User not found")

@app.post("/chat")
async def chat(message: str, current_user: str = Depends(get_current_user)):
    try:
        response = model.generate_content(message)
        return {"response": response.text}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating response: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
