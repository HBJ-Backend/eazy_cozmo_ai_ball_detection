"""Cube actions: id validation, visibility gating, and action success/failure."""

import easy_cozmo
import sdk_fakes
from easy_cozmo.actions import actions_with_cubes


def test_pickup_cube_by_id_rejects_invalid_id(robot):
    assert easy_cozmo.pickup_cube_by_id(99) is False
    robot.pickup_object.assert_not_called()


def test_pickup_cube_by_id_fails_when_no_cube_visible(robot):
    robot.world.visible_objects = []
    assert easy_cozmo.pickup_cube_by_id(1) is False
    robot.pickup_object.assert_not_called()


def test_pickup_cube_by_id_succeeds_with_visible_cube(make_robot):
    robot = make_robot(succeed=True)
    cube = sdk_fakes.make_cube(cube_id=1, origin_id=robot.pose.origin_id)
    robot.world.visible_objects = [cube]
    assert easy_cozmo.pickup_cube_by_id(1) is True
    robot.pickup_object.assert_called_once()


def test_pickup_cube_by_id_returns_false_when_action_fails(make_robot):
    robot = make_robot(succeed=False)
    cube = sdk_fakes.make_cube(cube_id=1, origin_id=robot.pose.origin_id)
    robot.world.visible_objects = [cube]
    assert easy_cozmo.pickup_cube_by_id(1) is False
    robot.pickup_object.assert_called_once()


def test_pickup_cube_one_delegates_to_id_1(make_robot):
    robot = make_robot(succeed=True)
    cube = sdk_fakes.make_cube(cube_id=1, origin_id=robot.pose.origin_id)
    robot.world.visible_objects = [cube]
    assert easy_cozmo.pickup_cube_one() is True
    robot.pickup_object.assert_called_once()


def test_place_on_top_rejects_invalid_id(robot):
    assert easy_cozmo.place_on_top(99) is False
    robot.place_on_object.assert_not_called()


def test_distance_to_cube_rejects_invalid_id(robot):
    assert easy_cozmo.distance_to_cube(99) is False


# --- regression tests for previously-pinned bugs (now fixed) ---

def test_pickup_cube_returns_false_when_no_cube_visible(robot):
    # Was: NameError on undefined `cube_id`. Now: returns False cleanly.
    robot.world.visible_objects = []
    assert easy_cozmo.pickup_cube() is False


def test_cube_two_returns_visible_cube_for_id_2(make_robot):
    # Was: NameError (undefined get_visible_cube_by_id/robot). Now: looks up id 2.
    robot = make_robot(succeed=True)
    cube = sdk_fakes.make_cube(cube_id=2, origin_id=robot.pose.origin_id)
    robot.world.visible_objects = [cube]
    assert actions_with_cubes._cube_two() is cube


def test_cube_two_returns_none_when_not_visible(robot):
    robot.world.visible_objects = []
    assert actions_with_cubes._cube_two() is None


def test_cube_three_uses_id_3_not_2(make_robot):
    # Was: NameError, and it wrongly passed id 2. Now: looks up id 3.
    robot = make_robot(succeed=True)
    cube3 = sdk_fakes.make_cube(cube_id=3, origin_id=robot.pose.origin_id)
    robot.world.visible_objects = [cube3]
    assert actions_with_cubes._cube_three() is cube3


def test_cube_three_ignores_cube_2(make_robot):
    # Pins that _cube_three no longer looks for id 2.
    robot = make_robot(succeed=True)
    cube2 = sdk_fakes.make_cube(cube_id=2, origin_id=robot.pose.origin_id)
    robot.world.visible_objects = [cube2]
    assert actions_with_cubes._cube_three() is None


def test_double_scan_for_any_cube_false_when_none(robot):
    # Regression: double_scan_for_any_cube called the un-imported helper
    # _double_scan_for_object -> NameError. Now it scans and returns False.
    robot.world.visible_objects = []
    assert easy_cozmo.double_scan_for_any_cube(20) is False


def test_place_on_top_aborts_and_returns_false_on_failure(make_robot):
    # Was: failure branch referenced undefined `current_action`, NameError
    # swallowed by `except: pass` so abort() was never reached. Now the failure
    # branch runs and calls action.abort().
    robot = make_robot(succeed=False)
    cube = sdk_fakes.make_cube(cube_id=1, origin_id=robot.pose.origin_id)
    robot.world.visible_objects = [cube]
    action = robot.place_on_object.return_value
    assert easy_cozmo.place_on_top(1) is False
    action.abort.assert_called_once()


def test_scan_for_cube_levels_the_head_before_turning(robot):
    # The head is only set once, in initialize_robot. Anything that moved it
    # since (move_head_looking_up for faces, the ball routines) would leave a
    # scan looking over the cubes.
    easy_cozmo.scan_for_cube(90)
    assert robot.set_head_angle.called
    assert robot.set_head_angle.call_args[0][0] == sdk_fakes.Q("degrees", 0)


def test_scan_for_cube_by_id_levels_the_head_too(robot):
    # Separate code path from scan_for_cube, and the one the mars wrappers use.
    easy_cozmo.scan_for_cube_by_id(90, 1)
    assert robot.set_head_angle.called
    assert robot.set_head_angle.call_args[0][0] == sdk_fakes.Q("degrees", 0)
