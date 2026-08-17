"""Image preprocessing / segmentation helpers (real OpenCV + numpy)."""

import numpy as np

from easy_cozmo.themes.soccer.ball_detection_utils import (
    preprocess_image_for_yolo,
    color_segmentation,
    crop_image_for_ball,
)


def test_preprocess_preserves_shape_and_dtype():
    frame = np.random.randint(0, 255, (120, 160, 3), dtype=np.uint8)
    out = preprocess_image_for_yolo(frame)
    assert out.shape == frame.shape
    assert out.dtype == frame.dtype


def test_color_segmentation_returns_binary_single_channel_mask():
    frame = np.zeros((120, 160, 3), dtype=np.uint8)
    low = np.array([0, 0, 0], dtype=np.uint8)
    high = np.array([180, 255, 255], dtype=np.uint8)
    mask = color_segmentation(frame, hsv_low=low, hsv_high=high)
    assert mask.ndim == 2
    assert mask.shape == (120, 160)
    assert set(np.unique(mask)).issubset({0, 255})


def test_crop_zeroes_blob_above_the_horizon():
    # A full-white mask cropped: everything above the 30% horizon is zeroed,
    # everything below is kept.
    mask = np.full((120, 160), 255, dtype=np.uint8)
    height, width = mask.shape
    cropped = crop_image_for_ball(mask.copy(), width, height)
    assert cropped[5, 80] == 0      # above horizon -> removed
    assert cropped[110, 80] == 255  # below horizon -> kept
