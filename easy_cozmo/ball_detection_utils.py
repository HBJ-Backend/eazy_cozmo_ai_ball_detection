import cv2
try:
    from .cv_utils import region_of_interest
except Exception: #ImportError
    from easy_cozmo.cv_utils import region_of_interest

import tempfile
import os 

def color_segmentation(cvimage, **kwargs):
    blurred = cv2.GaussianBlur(cvimage, (11, 11), 0)
    hsv = cv2.cvtColor(blurred, cv2.COLOR_BGR2HSV)
    height, width, channels = cvimage.shape
    # construct a mask for the color "green", then perform
    # a series of dilations and erosions to remove any small
    # blobs left in the mask
    hsv_low = kwargs['hsv_low']
    hsv_high = kwargs['hsv_high']
    mask = cv2.inRange(hsv, hsv_low, hsv_high)
    mask = cv2.erode(mask, None, iterations=2)
    mask = cv2.dilate(mask, None, iterations=2)

    mask_cropped = crop_image_for_ball(mask.copy(), width, height)
    mask = mask_cropped

    return mask

def crop_image_for_ball(cvimage, width, height):
    import numpy as np
    # np.warnings.filterwarnings('ignore')

    region_of_interest_vertices = [
        (0, height),
        (0, 0.30*height),
        (width, 0.30*height),
        (width, height)
    ]
    cropped_image = region_of_interest(
        cvimage,
        np.array(
            [region_of_interest_vertices],
            np.int32
        ),
    )
    return cropped_image


import cv2
import imutils
import numpy as np

# import os
# import uuid
# from datetime import datetime

def save_image(cvimage, folder="dataset", prefix="ball"):
    # Make sure the folder exists
    if not os.path.exists(folder):
        os.makedirs(folder)

    # Create unique filename (timestamp + uuid4)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    unique_id = str(uuid.uuid4())[:8]  # short unique ID
    filename = f"{prefix}_{timestamp}_{unique_id}.png"

    # Full path
    path = os.path.join(folder, filename)

    # Save the image
    cv2.imwrite(path, cvimage)
    print(f"Image saved to {path}")
    return path

import cv2
import pathlib

# from yolov5 import YOLOv5
import yolov5
def load_model():
    # print('load')
    # --- Patch PosixPath for Windows ---
    if hasattr(pathlib, "PosixPath"):
        pathlib.PosixPath = pathlib.WindowsPath
    # --- Config ---
    MODEL_PATH = "C:/Users/CS/eazy_cozmo_ai_ball_detection/easy_cozmo/yolov5/best_windows.pt"   # path to your trained YOLOv5-Nano model
    # Load the YOLOv5 model
    model = yolov5.load(MODEL_PATH)
    return model

def detect_ball(frame, model, tag=True, conf_thresh=0.8  , **kwargs):
    # print('detect')
    try:
        # Save image to a temporary file
        with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
            temp_path = tmp.name
            cv2.imwrite(temp_path, cv2.cvtColor(frame, cv2.COLOR_RGB2BGR))

        # Run inference using the temp file
        results = model(temp_path, size=256)

        # Delete the temp file
        os.remove(temp_path)

        for det in results.xyxy[0]:  # detections for first image
            x1, y1, x2, y2, conf, cls = det
            # print('conf: ', conf)
            radius = int(0.5 * max(x2 - x1, y2 - y1))
            # print(x1,y1,x2,y2, conf)
            if conf >= conf_thresh and radius < 80 and radius > 20:
                cx, cy = int((x1 + x2) / 2), int((y1 + y2) / 2)
                radius = int(0.5 * max(x2 - x1, y2 - y1))

                if tag:
                    cv2.rectangle(frame, (int(x1), int(y1)), (int(x2), int(y2)), (0, 255, 0), 2)
                    cv2.circle(frame, (cx, cy), 2, (0, 0, 255), 3)

                image_bgr = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
                return True, frame, (cx, cy), radius
                
            else:
                return False, frame, None, None

        return False, frame, None, None
    
    except Exception as e:
        print(f"Detection error: {e}")
        return False, frame, None, None


def get_ball_pnp(center, rad, **kwargs):
    import numpy as np
    # np.warnings.filterwarnings('ignore')
    import cv2 as cv
    import math

    # some default values
    ballradius=25
    fx,fy = 277.345389059622, 278.253264643578
    cx,cy = 152.389201831827, 109.376457506074
    k1,k2=-0.0691655300978844,0.0630063731358772
    p1,p2=0,0

    camera_matrix = None
    if kwargs.__contains__('camera_matrix'):
        camera_matrix = kwargs['camera_matrix']
    else:
        camera_matrix=np.array([[fx,0,cx],
                             [0,fy,cy],
                             [0,0,1]])

    distortion_coef = None
    if kwargs.__contains__('distortion_coef'):
        distortion_coef = kwargs['distortion_coef']
    else:
        distortion_coef = np.array([k1,k2,p1,p2])

    if kwargs.__contains__('ball_radius'):
        ball_radius = kwargs['ball_radius']

    objp=np.array([[ballradius,0,0],
                   [0,-ballradius,0],
                   [0,ballradius,0],
                   [0,0,ballradius],
                   [0,0,-ballradius],
                   [ballradius*math.sin(math.pi/4.),ballradius*math.cos(math.pi/4.),0],
                   [ballradius*math.sin(math.pi/4.),-ballradius*math.cos(math.pi/4.),0],
                   [ballradius*math.sin(math.pi/4.),0,-ballradius*math.cos(math.pi/4.)],
                   [ballradius*math.sin(math.pi/4.),0,ballradius*math.cos(math.pi/4.)]

                   ])
    pts2=np.array([[center[0], center[1]],
                   [center[0]-rad,center[1]],
                   [center[0]+rad,center[1]],
                   [center[0],center[1]-rad],
                   [center[0],center[1]+rad],
                   [center[0]+rad*math.cos(math.pi/4.),center[1]],
                   [center[0]-rad*math.cos(math.pi/4.),center[1]],
                   [center[0],center[1]+rad*math.cos(math.pi/4.)],
                   [center[0],center[1]-rad*math.cos(math.pi/4.)],
                   ])
    ret,rvecs, tvecs = cv.solvePnP(objp, pts2, camera_matrix, distortion_coef)
    return ret, rvecs, tvecs
