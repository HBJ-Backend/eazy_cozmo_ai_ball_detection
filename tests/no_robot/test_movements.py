"""Movement primitives: unit conversions, signs, and accept/reject logic."""

import easy_cozmo
from sdk_fakes import Q


def test_move_forward_success(robot):
    # 10 cm -> 100 mm, default forward speed 80 mmps, animations off.
    assert easy_cozmo.move_forward(10) is True
    robot.drive_straight.assert_called_once()
    args, kwargs = robot.drive_straight.call_args
    assert args[0] == Q("distance_mm", 100)
    assert kwargs["speed"] == Q("speed_mmps", 80)
    assert kwargs["should_play_anim"] is False


def test_move_forward_failure(make_robot):
    robot = make_robot(succeed=False)
    assert easy_cozmo.move_forward(10) is False


def test_rotate_in_place_negates_angle(robot):
    # rotate_in_place(90) -> turn_in_place(degrees(-90))
    assert easy_cozmo.rotate_in_place(90) is True
    assert robot.turn_in_place.call_args[0][0] == Q("degrees", -90)


def test_rotate_left_and_right_have_opposite_signs(robot):
    easy_cozmo.rotate_right(30)
    right_arg = robot.turn_in_place.call_args[0][0]
    easy_cozmo.rotate_left(30)
    left_arg = robot.turn_in_place.call_args[0][0]
    assert right_arg == Q("degrees", -30)
    assert left_arg == Q("degrees", 30)


def test_move_lift_up(robot):
    assert easy_cozmo.move_lift_up() is True
    robot.set_lift_height.assert_called_once_with(1)


def test_move_head_looking_forward(robot):
    assert easy_cozmo.move_head_looking_forward() is True
    assert robot.set_head_angle.call_args[0][0] == Q("degrees", 0)


def test_reverse_in_seconds(robot):
    # Both wheels reverse at -80 mmps for the requested duration.
    assert easy_cozmo.reverse_in_seconds(3) is True
    robot.drive_wheels.assert_called_once_with(-80, -80, duration=3)


def test_set_wheels_speeds_rejects_too_fast(robot):
    # 100 cm/s -> 1000 mm/s exceeds df_max_wheel_speed (70): rejected, no motors.
    assert easy_cozmo.set_wheels_speeds(100, 100) is False
    robot.drive_wheel_motors.assert_not_called()


def test_set_wheels_speeds_accepts_in_range(robot):
    # 5 cm/s -> 50 mm/s is within range.
    assert easy_cozmo.set_wheels_speeds(5, 5) is True
    robot.drive_wheel_motors.assert_called_once()


def test_stop_is_noop_when_not_moving(robot):
    robot.are_wheels_moving = False
    assert easy_cozmo.stop() is True
    robot.stop_all_motors.assert_not_called()


def test_stop_stops_motors_when_moving(robot):
    robot.are_wheels_moving = True
    assert easy_cozmo.stop() is True
    robot.stop_all_motors.assert_called_once()


def test_movements_module_imports_time():
    # Regression: movements.py used time.sleep in abort loops without importing
    # time (latent NameError). Ensure `time` is now available in the module.
    from easy_cozmo.core import movements
    assert hasattr(movements, "time")


def test_rotate_alias_matches_rotate_in_place(robot):
    easy_cozmo.rotate(45)
    assert robot.turn_in_place.call_args[0][0] == Q("degrees", -45)


def test_move_lift_down_and_ground(robot):
    assert easy_cozmo.move_lift_down() is True
    robot.set_lift_height.assert_called_with(0.2)
    assert easy_cozmo.move_lift_ground() is True
    robot.set_lift_height.assert_called_with(0)


def test_move_head_up_and_down(robot):
    assert easy_cozmo.move_head_looking_up() is True
    assert easy_cozmo.move_head_looking_down() is True
    assert robot.set_head_angle.call_count == 2


def test_reverse_and_move_backward(robot):
    # Reverse uses drive_straight with a negative distance, not a timed
    # drive_wheels, so it covers the same distance as move_forward.
    assert easy_cozmo.reverse(10) is True
    args, kwargs = robot.drive_straight.call_args
    assert args[0] == Q("distance_mm", -100)
    assert kwargs["speed"] == Q("speed_mmps", 80)
    robot.drive_wheels.assert_not_called()
    assert easy_cozmo.move_backward(10) is True


def test_move_forward_avoiding_landmark_uses_go_to_pose(robot):
    assert easy_cozmo.move_forward_avoiding_landmark(10) is True
    robot.go_to_pose.assert_called_once()


def test_move_without_distance_is_rejected_when_stationary(robot):
    # KNOWN QUIRK: move()/drive()/start_moving() use df_forward_speed/10 = 8 cm/s
    # -> 80 mm/s, which exceeds df_max_wheel_speed (70). set_wheels_speeds rejects
    # it and move() returns False, so Cozmo never actually rolls via move().
    robot.are_wheels_moving = False
    assert easy_cozmo.move() is False
    robot.drive_wheel_motors.assert_not_called()


def test_move_returns_true_when_already_moving(robot):
    robot.are_wheels_moving = True
    assert easy_cozmo.move() is True


def test_drive_and_start_moving_alias_move(robot):
    robot.are_wheels_moving = True
    assert easy_cozmo.drive() is True
    assert easy_cozmo.start_moving() is True


def test_stop_moving_alias_stops(robot):
    robot.are_wheels_moving = True
    assert easy_cozmo.stop_moving() is True
    robot.stop_all_motors.assert_called_once()


def test_steer_straight_drives_low_symmetric_speed(robot):
    assert easy_cozmo.steer_straight() is True
    robot.drive_wheel_motors.assert_called_once()


def test_steer_left_and_right_reject_negative(robot):
    assert easy_cozmo.steer_left(-5) is False
    assert easy_cozmo.steer_right(-5) is False
