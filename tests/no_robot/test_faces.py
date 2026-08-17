"""actions_with_faces: face/teammate visibility + scan gating."""

import easy_cozmo
import sdk_fakes


def test_is_face_visible_false_when_none(robot):
    robot.world.visible_faces = []
    assert easy_cozmo.is_face_visible() is False


def test_is_face_visible_returns_the_face(robot):
    face = sdk_fakes.make_face(name="")
    robot.world.visible_faces = [face]
    assert easy_cozmo.is_face_visible() is face


def test_is_teammate_visible_true_for_named_face(robot):
    robot.world.visible_faces = [sdk_fakes.make_face(name="Alice")]
    assert easy_cozmo.is_teammate_visible() is True


def test_is_teammate_visible_false_for_unnamed_face(robot):
    # An unnamed face is a person but not a registered teammate.
    robot.world.visible_faces = [sdk_fakes.make_face(name="")]
    assert easy_cozmo.is_teammate_visible() is False


def test_scan_for_faces_false_when_none_visible(robot):
    robot.world.visible_faces = []
    assert easy_cozmo.scan_for_faces(360) is False


def test_scan_for_faces_true_when_face_present(robot):
    robot.world.visible_faces = [sdk_fakes.make_face(name="")]
    assert easy_cozmo.scan_for_faces(360) is True
