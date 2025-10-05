import socket
import pathlib
import cv2
import yolov5
import json
import threading
import getpass
def load_model():
    if hasattr(pathlib, "PosixPath"):
        pathlib.PosixPath = pathlib.WindowsPath

    MODEL_PATH = f"C:/Users/{getpass.getuser()}/eazy_cozmo_ai_ball_detection/easy_cozmo/best_windows.pt"
    model = yolov5.load(MODEL_PATH)
    return model

def detect_ball(image_path, model, conf_thresh=0.7):
    try:
        frame = cv2.imread(image_path)
        if frame is None:
            raise ValueError("Image not found or unreadable.")

        results = model(image_path, size=256)
        for det in results.xyxy[0]:  # detections for first image
            x1, y1, x2, y2, conf, cls = det
            radius = int(0.5 * max(x2 - x1, y2 - y1))
            if conf >= conf_thresh and radius > 17:
                cx, cy = int((x1 + x2) / 2), int((y1 + y2) / 2)
                radius = int(0.5 * max(x2 - x1, y2 - y1))

                return {'results' : {'detected': True, 'cx': cx, 'cy': cy, 'x1': float(x1), 'y1':float(y1),
                            'x2': float(x2), 'y2':float(y2), 'radius':radius}}
                
            else:
                return {'results' : {'detected': False, 'cx': None, 'cy': None, 'x1': None, 'y1':None,
                            'x2': None, 'y2':None, 'radius':None}}
    except Exception as e:
        print(e)
        return {
            "success": False,
            "error": str(e)
        }

import socket

def handle_client(conn, addr, model):
    print(f"[SERVER] New connection from {addr}")
    try:
        
        buffer = ""

        while True:
            data = conn.recv(1024).decode('utf-8')
            if not data:
                print(f"[SERVER] Connection from {addr} closed by client.")
                break

            buffer += data

            while '\n' in buffer:
                line, buffer = buffer.split('\n', 1)
                line = line.strip()
                if not line:
                    continue

                result = detect_ball(line, model)

                try:
                    conn.sendall((json.dumps(result) + '\n').encode('utf-8'))
                except (ConnectionResetError, BrokenPipeError) as e:
                    print(f"[SERVER] Client disconnected early: {addr} — {e}")
                    return


    except Exception as e:
        print(f"[SERVER] Error with client {addr}: {e}")



def start_server(host='127.0.0.1', port=65432):
    model = load_model()
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind((host, port))
    server.listen()

    print(f"[SERVER] Ball Detection Server listening on {host}:{port}")

    try:
        while True:
            conn, addr = server.accept()
            client_thread = threading.Thread(target=handle_client, args=(conn, addr, model))
            client_thread.daemon = True  # Optional: daemon thread exits when main thread exits
            client_thread.start()
    except KeyboardInterrupt:
        print("[SERVER] Shutting down.")
    finally:
        server.close()

if __name__ == "__main__":
    start_server()

