"""odometry: wrap_angle math + accessors + initialization wiring."""

import math

import pytest

import easy_cozmo
from easy_cozmo.core import odometry


def test_wrap_angle_keeps_in_range():
    assert easy_cozmo.wrap_angle(0.0) == pytest.approx(0.0)
    assert easy_cozmo.wrap_angle(math.pi / 2) == pytest.approx(math.pi / 2)
    # 3*pi/2 wraps down by 2*pi -> -pi/2
    assert easy_cozmo.wrap_angle(3 * math.pi / 2) == pytest.approx(-math.pi / 2)
    # -3*pi/2 wraps up by 2*pi -> +pi/2
    assert easy_cozmo.wrap_angle(-3 * math.pi / 2) == pytest.approx(math.pi / 2)


def test_reset_odometry_zeroes_distance():
    odometry.reset_odometry()
    assert easy_cozmo.get_distance_traveled() == 0


def test_get_odom_pose_is_available():
    odometry.reset_odometry()
    assert easy_cozmo.get_odom_pose() is not None


def test_initialize_odometry_registers_handler(robot):
    easy_cozmo.initialize_odometry()
    assert robot.add_event_handler.called
    # and distance starts at zero after init
    assert easy_cozmo.get_distance_traveled() == 0
