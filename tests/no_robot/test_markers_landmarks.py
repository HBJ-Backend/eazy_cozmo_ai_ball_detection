"""Marker / landmark scan + align helpers.

Regression coverage for helpers that were called but never imported into these
modules (double_scan_for_* -> _double_scan_for_object, align_with_nearest_marker
-> _align_with_nearest_object): they used to raise NameError the moment they ran.
The public-API contract test only checks they *resolve*; these tests *call* them.
"""

import easy_cozmo


def test_double_scan_for_marker_false_when_none(robot):
    robot.world.visible_objects = []
    assert easy_cozmo.double_scan_for_marker(20) is False


def test_align_with_nearest_marker_none_when_none(robot):
    robot.world.visible_objects = []
    assert easy_cozmo.align_with_nearest_marker() is None


def test_double_scan_for_landmark_false_when_none(robot):
    robot.world.visible_objects = []
    assert easy_cozmo.double_scan_for_landmark(20) is False


def test_align_with_nearest_landmark_none_when_none(robot):
    robot.world.visible_objects = []
    assert easy_cozmo.align_with_nearest_landmark() is None
