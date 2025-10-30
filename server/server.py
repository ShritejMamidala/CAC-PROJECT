
from fastapi import FastAPI, File, UploadFile, Form
from fastapi.responses import JSONResponse
from ultralytics import YOLO
import uvicorn
import cv2
import numpy as np
import os
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"
app = FastAPI()

# Load your trained model once at startup
model = YOLO(r"C:\Users\shrit\Desktop\CAC-PROJECT\best.pt") 
@app.post("/predict")
async def predict(
    file: UploadFile = File(...),
    conf: float = Form(0.25)  # confidence threshold 
):
    # Read image bytes
    image_bytes = await file.read()
    nparr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    # Run inference
    results = model.predict(img, conf=conf)

    detections = []
    for r in results:
        for box in r.boxes:
            x1, y1, x2, y2 = box.xyxy[0].tolist()
            cls = int(box.cls[0].item())
            score = float(box.conf[0].item())
            detections.append({
                "bbox": [x1, y1, x2, y2],
                "class": model.names[cls],
                "score": score
            })

    return JSONResponse({"detections": detections})

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
