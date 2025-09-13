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

def normalize_brightness(image_bgr):
    hsv = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2HSV)
    h, s, v = cv2.split(hsv)
    
    # Equalize brightness channel (v)
    v_eq = cv2.equalizeHist(v)

    hsv_eq = cv2.merge((h, s, v_eq))
    image_bgr_eq = cv2.cvtColor(hsv_eq, cv2.COLOR_HSV2BGR)
    return image_bgr_eq


def apply_clahe(image_bgr):
    lab = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)

    # Apply CLAHE to L-channel
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    l_clahe = clahe.apply(l)

    lab_clahe = cv2.merge((l_clahe, a, b))
    image_bgr_clahe = cv2.cvtColor(lab_clahe, cv2.COLOR_LAB2BGR)
    return image_bgr_clahe


def adjust_gamma(image, gamma=1.5):
    invGamma = 1.0 / gamma
    table = np.array([((i / 255.0) ** invGamma) * 255
                      for i in np.arange(256)]).astype("uint8")
    return cv2.LUT(image, table)

def preprocess_image_for_yolo(cvimage):
    # Step 1: Normalize brightness (equalize V in HSV)
    image = normalize_brightness(cvimage)

    # Step 2: Apply CLAHE to enhance contrast
    image = apply_clahe(image)

    # Step 3: Optional - gamma correction
    image = adjust_gamma(image, gamma=1.2)  # increase gamma to darken

    return image

import socket
import json
def detect_ball(frame, client, tag=True, conf_thresh=0.8  , **kwargs):
    # print('detect')
    frame_processed = preprocess_image_for_yolo(frame)

    # Save image to a temporary file
    with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
        temp_path = tmp.name
        cv2.imwrite(temp_path, cv2.cvtColor(frame_processed, cv2.COLOR_RGB2BGR))
    try:
        host='127.0.0.1'
        port=65432
        results = client.send_image_path(temp_path)
        if results:
            data = results['results']
            if data['detected']:
                x1, y1, x2, y2, cx, cy, radius = data['x1'], data['y1'], data['x2'], data['y2'], data['cx'], data['cy'], data['radius']

                if tag:
                    cv2.rectangle(frame, (int(x1), int(y1)), (int(x2), int(y2)), (0, 255, 0), 2)
                    cv2.circle(frame, (cx, cy), 2, (0, 0, 255), 3)

                os.remove(temp_path)

                return True, frame, (cx, cy), radius
            else:
                os.remove(temp_path)

                return False, frame, None, None

        else:
            os.remove(temp_path)
            return False, frame, None, None


    
    except Exception as e:
        os.remove(temp_path)
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
