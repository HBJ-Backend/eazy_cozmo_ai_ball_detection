"""actions_with_objects: observable-object checks + visibility/nearest helpers."""

import easy_cozmo
import sdk_fakes
from easy_cozmo.actions import actions_with_objects


def test_is_observable_object_true_for_cube():
    assert actions_with_objects._is_observable_object(sdk_fakes.make_cube()) is True


def test_is_observable_object_false_for_plain_object():
    assert actions_with_objects._is_observable_object(object()) is False


def test_get_visible_object_none_when_empty(robot):
    robot.world.visible_objects = []
    assert actions_with_objects._get_visible_object() is None


def test_get_visible_object_returns_cube(make_robot):
    robot = make_robot(succeed=True)
    cube = sdk_fakes.make_cube(cube_id=1, origin_id=robot.pose.origin_id)
    robot.world.visible_objects = [cube]
    assert actions_with_objects._get_visible_object() is cube


def test_get_visible_objects_lists_cubes(make_robot):
    robot = make_robot(succeed=True)
    cube = sdk_fakes.make_cube(cube_id=1, origin_id=robot.pose.origin_id)
    robot.world.visible_objects = [cube]
    assert actions_with_objects._get_visible_objects() == [cube]


def test_get_nearest_object_false_when_none(robot):
    robot.world.visible_objects = []
    assert actions_with_objects._get_nearest_object() is False


# Note: _get_nearest_object's actual nearest-selection compares real distances
# (robot.pose - object.pose), which needs real poses a fake robot can't provide.
# That path is covered by the manual robot tests (align_with_nearest_cube).
