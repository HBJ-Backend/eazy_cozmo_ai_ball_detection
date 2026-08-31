"""Speech helpers: say() and say_error()."""

import easy_cozmo


def test_say_speaks_message(robot):
    easy_cozmo.say("hello")
    assert robot.say_text.call_args[0][0] == "hello"


def test_say_concatenates_extra_args(robot):
    # First arg is concatenated directly with a space-joined tail.
    easy_cozmo.say("a", "b", "c")
    assert robot.say_text.call_args[0][0] == "ab c"


def test_say_passes_the_voice_defaults(robot):
    from easy_cozmo.core import defaults
    easy_cozmo.say("hello")
    kwargs = robot.say_text.call_args[1]
    assert kwargs["duration_scalar"] == defaults.df_say_duration_scalar
    assert kwargs["voice_pitch"] == defaults.df_say_voice_pitch
    assert kwargs["use_cozmo_voice"] == defaults.df_say_use_cozmo_voice


def test_say_reads_defaults_at_call_time(robot, monkeypatch):
    # Changing the default mid-program takes effect on the next say().
    from easy_cozmo.core import defaults
    monkeypatch.setattr(defaults, "df_say_duration_scalar", 0.5)
    easy_cozmo.say("hello")
    assert robot.say_text.call_args[1]["duration_scalar"] == 0.5


def test_say_per_call_override_beats_the_default(robot):
    easy_cozmo.say("hello", duration_scalar=0.3)
    assert robot.say_text.call_args[1]["duration_scalar"] == 0.3


def test_say_error_prefixes_error(robot):
    easy_cozmo.say_error("oops")
    robot.say_text.assert_called_once_with("ERROR, oops")


def test_underscore_say_is_print_only(robot):
    # _say prints but does not drive the robot's speech.
    from easy_cozmo.core.say import _say
    assert _say("quiet message") is None
    robot.say_text.assert_not_called()
