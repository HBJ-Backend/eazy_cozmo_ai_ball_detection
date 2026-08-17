"""robot_utils: trig helpers, volume/headlight wrappers, pause, abort."""

import math

import pytest

import easy_cozmo


def test_trig_helpers_use_degrees():
    assert easy_cozmo.cosine(0) == pytest.approx(1.0)
    assert easy_cozmo.cosine(90) == pytest.approx(0.0, abs=1e-9)
    assert easy_cozmo.sine(90) == pytest.approx(1.0)
    assert easy_cozmo.tan(45) == pytest.approx(1.0)
    assert easy_cozmo.atan(1) == pytest.approx(45.0)
    assert easy_cozmo.asine(0.5) == pytest.approx(30.0)
    assert easy_cozmo.acosine(1) == pytest.approx(0.0, abs=1e-9)


def test_asine_clamps_slightly_above_one():
    # 1.0 < val < 1.1 is clamped to asin(1) == 90 degrees (with a warning).
    assert easy_cozmo.asine(1.05) == pytest.approx(90.0)


def test_asine_returns_none_when_far_above_one(robot):
    # val >= 1.1 is rejected (says an error, returns None).
    assert easy_cozmo.asine(2.0) is None


def test_pause_sleeps_without_error(robot):
    # time.sleep is monkeypatched to a no-op by the autouse fixture.
    assert easy_cozmo.pause(5) is None


def test_headlight_wrappers(robot):
    easy_cozmo.enable_head_light()
    robot.set_head_light.assert_called_with(True)
    easy_cozmo.disable_head_light()
    robot.set_head_light.assert_called_with(False)


def test_volume_wrappers(robot):
    easy_cozmo.set_volume_high()
    robot.set_robot_volume.assert_called_with(1)
    easy_cozmo.set_volume_low()
    robot.set_robot_volume.assert_called_with(.05)
    easy_cozmo.set_volume_med()
    robot.set_robot_volume.assert_called_with(.5)


def test_abort_raises_systemexit():
    with pytest.raises(SystemExit):
        easy_cozmo.abort()
