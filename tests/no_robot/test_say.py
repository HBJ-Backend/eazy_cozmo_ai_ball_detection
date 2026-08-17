"""Speech helpers: say() and say_error()."""

import easy_cozmo


def test_say_speaks_message(robot):
    easy_cozmo.say("hello")
    robot.say_text.assert_called_once_with("hello")


def test_say_concatenates_extra_args(robot):
    # First arg is concatenated directly with a space-joined tail.
    easy_cozmo.say("a", "b", "c")
    robot.say_text.assert_called_once_with("ab c")


def test_say_error_prefixes_error(robot):
    easy_cozmo.say_error("oops")
    robot.say_text.assert_called_once_with("ERROR, oops")


def test_underscore_say_is_print_only(robot):
    # _say prints but does not drive the robot's speech.
    from easy_cozmo.core.say import _say
    assert _say("quiet message") is None
    robot.say_text.assert_not_called()
