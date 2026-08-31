"""Mars workshop wrappers: each one must reach the right core function."""

import easy_cozmo
from easy_cozmo.themes.mars import wrappers


def test_scan_for_ice_sample_reaches_the_robot(robot):
    # Goes through scan_for_cube_by_id, which turns in place to look around.
    easy_cozmo.scan_for_ice_sample(90)
    assert robot.turn_in_place.called


def test_scan_wrappers_honour_scan_speed(robot, monkeypatch):
    # Regression: the first draft named a scan_speed parameter and then ignored
    # it, always passing the default through.
    seen = {}

    def fake_scan_by_id(angle, cube_id, scan_speed=None, annotate=True):
        seen["by_id"] = (angle, cube_id, scan_speed)
        return True

    def fake_scan(angle, scan_speed=None):
        seen["any"] = (angle, scan_speed)
        return True

    monkeypatch.setattr(wrappers, "scan_for_cube_by_id", fake_scan_by_id)
    monkeypatch.setattr(wrappers, "scan_for_cube", fake_scan)

    wrappers.scan_for_ice_sample(90, scan_speed=42)
    wrappers.scan_for_debris(90, scan_speed=43)

    assert seen["by_id"] == (90, wrappers.ICE_SAMPLE, 42)
    assert seen["any"] == (90, 43)


def test_send_message_lights_blue_beeps_and_speaks(robot):
    easy_cozmo.send_message("signal received")

    assert robot.set_all_backpack_lights.called
    assert robot.set_backpack_lights_off.called
    assert robot.play_song.called
    spoken = robot.say_text.call_args[0][0]
    # A space after the colon: say() concatenates without inserting one.
    assert spoken == "Message sent: signal received"


def test_beeps_go_through_play_song_not_play_audio(robot):
    # play_audio posts a fire-and-forget event to the CodeLab game object and
    # is silent in SDK mode. play_song returns a real action instead.
    easy_cozmo.send_message("a")
    robot.play_audio.assert_not_called()
    robot.play_song.return_value.wait_for_completed.assert_called()


def test_send_and_receive_use_different_beeps(robot):
    easy_cozmo.send_message("a")
    sent = len(robot.play_song.call_args[0][0])
    easy_cozmo.receive_message("b")
    received = len(robot.play_song.call_args[0][0])
    assert (sent, received) == (len(wrappers.BEEP_SEND), len(wrappers.BEEP_RECEIVE))
    assert sent != received


def test_beep_plays_once_per_repeat_and_says_nothing(robot):
    easy_cozmo.beep(times=3)
    assert robot.play_song.call_count == 3
    robot.say_text.assert_not_called()


def test_receive_message_has_a_default_text(robot):
    easy_cozmo.receive_message()
    assert robot.say_text.call_args[0][0] == "Message received: signal received"


def test_report_status_and_alert_prefix_their_text(robot):
    easy_cozmo.report_status("Functional")
    assert robot.say_text.call_args[0][0] == "Status: Functional"
    easy_cozmo.raise_alert("dust storm")
    assert robot.say_text.call_args[0][0] == "Alert: dust storm"


def test_cube_role_constants(robot):
    assert (wrappers.ICE_SAMPLE, wrappers.FREEZER, wrappers.PATH_MARKER) == (1, 2, 3)
