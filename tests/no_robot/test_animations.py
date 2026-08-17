"""animations: each helper plays the correct anim trigger."""

import cozmo  # the fake, installed by conftest
import pytest

import easy_cozmo

# function name -> expected cozmo.anim.Triggers attribute
ANIMATIONS = {
    "show_happy": "CodeLabHappy",
    "show_victory": "CodeLabExcited",
    "show_excited": "CodeLabFireTruck",
    "show_sad": "CodeLabLose",
    "show_frustrated": "CodeLabFrustrated",
    "show_dancing": "CodeLabDancingMambo",
}


@pytest.mark.parametrize("func_name,trigger_name", list(ANIMATIONS.items()))
def test_animation_plays_expected_trigger(robot, func_name, trigger_name):
    getattr(easy_cozmo, func_name)()
    robot.play_anim_trigger.assert_called_once()
    expected = getattr(cozmo.anim.Triggers, trigger_name)
    assert robot.play_anim_trigger.call_args[0][0] is expected
