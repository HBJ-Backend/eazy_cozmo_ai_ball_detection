"""Ball geometry / detection-statistics math (real numpy + OpenCV)."""

import numpy as np

import easy_cozmo.themes.soccer.ball_detector as bd
from easy_cozmo.themes.soccer.ball_detection_utils import get_ball_pnp


def test_get_ball_pnp_returns_positive_finite_distance():
    ret, rvecs, tvecs = get_ball_pnp((160, 120), 30)
    assert ret is True
    distance = np.linalg.norm(tvecs)
    assert distance > 0
    assert np.isfinite(distance)


def test_get_ball_pnp_larger_radius_means_closer():
    _, _, t_small = get_ball_pnp((160, 120), 20)
    _, _, t_large = get_ball_pnp((160, 120), 60)
    assert np.linalg.norm(t_large) < np.linalg.norm(t_small)


class _FakeDetector:
    """A throwaway stand-in for the real BallDetector's running buffers."""

    def __init__(self, img_centers, img_radius):
        self.img_centers = img_centers
        self.img_radius = img_radius


def test_detection_stats_are_stable_when_ball_centered():
    # A steady buffer at the image center (x=160) -> zero deviation, stable.
    bd._ball_detector = _FakeDetector([(160, 120)] * 5, [30] * 5)

    err, std = bd.compute_hor_dev()
    assert err == 0
    assert std == 0
    assert bd.last_err() == 0
    assert bd.is_stable_detection() is True


def test_detection_is_not_stable_when_jittery():
    bd._ball_detector = _FakeDetector(
        [(0, 0), (300, 300), (10, 250), (290, 5)],
        [5, 50, 8, 45],
    )
    assert bd.is_stable_detection() is False
