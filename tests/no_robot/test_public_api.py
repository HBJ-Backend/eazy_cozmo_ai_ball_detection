"""Public-API / wiring contract for the flat ``easy_cozmo`` namespace.

This is the "did an edit break the code flow?" guard. It does two things:

1. Asserts every submodule imports cleanly (catches a broken import anywhere
   in the core -> actions -> themes chain, including the relative-import
   rewrites from the tier restructure).
2. Asserts every function in the documented public API still resolves as a
   bare callable on ``easy_cozmo`` (catches a missing ``from .x import *``
   re-export, or a function that got renamed/removed by accident).

When you ADD a public function, add its name here. A failure means either a
real wiring break, or this contract needs updating to match an intentional
change.
"""

import importlib

import pytest

import easy_cozmo


# Every easy_cozmo submodule must import without error.
SUBMODULES = [
    "easy_cozmo._sdk_patches",
    "easy_cozmo.core",
    "easy_cozmo.core.defaults",
    "easy_cozmo.core.easy_cozmo",
    "easy_cozmo.core.initialize_robot",
    "easy_cozmo.core.movements",
    "easy_cozmo.core.say",
    "easy_cozmo.core.animations",
    "easy_cozmo.core.odometry",
    "easy_cozmo.core.robot_utils",
    "easy_cozmo.core.cv_utils",
    "easy_cozmo.actions",
    "easy_cozmo.actions.actions_with_objects",
    "easy_cozmo.actions.actions_with_cubes",
    "easy_cozmo.actions.actions_with_faces",
    "easy_cozmo.actions.actions_with_landmarks",
    "easy_cozmo.actions.actions_with_custom_markers",
    "easy_cozmo.themes",
    "easy_cozmo.themes.soccer",
    "easy_cozmo.themes.soccer.ball_detector",
    "easy_cozmo.themes.soccer.ball_detection_utils",
    "easy_cozmo.themes.line_following",
    "easy_cozmo.themes.line_following.line_detector",
    "easy_cozmo.themes.line_following.line_detection_utils",
    "easy_cozmo.themes.mars",
    "easy_cozmo.themes.mars.wrappers",
    "easy_cozmo.themes.sustainability",
    "easy_cozmo.themes.sustainability.wrappers",
]

# Public functions that must remain exposed on the flat namespace, by area.
PUBLIC_API = {
    "movements": [
        "move_forward", "move_backward", "move_forward_in_seconds",
        "move_forward_avoiding_landmark", "reverse", "reverse_in_seconds",
        "rotate", "rotate_in_place", "rotate_left", "rotate_right",
        "move_lift_up", "move_lift_down", "move_lift_ground",
        "move_head_looking_up", "move_head_looking_down",
        "move_head_looking_forward", "set_wheels_speeds", "stop", "stop_moving",
        "move", "drive", "start_moving", "steer", "steer_left", "steer_right",
        "steer_straight",
    ],
    "say": ["say", "say_error"],
    "robot_utils": [
        "pause", "abort", "enable_head_light", "disable_head_light",
        "set_volume_high", "set_volume_low", "set_volume_med",
        "cosine", "sine", "tan", "atan", "asine", "acosine",
        "enable_camera_settings_for_bright_light",
        "disable_camera_settings_for_bright_light",
    ],
    "animations": [
        "show_happy", "show_sad", "show_excited", "show_victory",
        "show_frustrated", "show_dancing",
    ],
    "runtime": ["run_program", "run_program_with_viewer", "initialize_robot"],
    "odometry": [
        "initialize_odometry", "reset_odometry", "get_distance_traveled",
        "get_odom_pose", "wrap_angle",
    ],
    "cubes": [
        "scan_for_cube", "scan_for_cube_by_id", "scan_for_cube_one",
        "scan_for_cube_two", "scan_for_cube_three", "double_scan_for_any_cube",
        "pickup_cube", "pickup_cube_by_id", "pickup_cube_one",
        "pickup_cube_two", "pickup_cube_three", "place_on_top",
        "place_on_top_of_one", "place_on_top_of_two", "place_on_top_of_three",
        "drop_cube", "center_cube", "distance_to_cube",
        "align_with_nearest_cube", "align_with_cube_by_id",
    ],
    "faces": [
        "scan_for_faces", "scan_for_teammates", "is_face_visible",
        "is_teammate_visible", "align_with_face",
        "say_something_to_visible_teammate",
        "enable_facial_expression_recognition",
        "disable_facial_expression_recognition",
        "wait_for_a_smiling_face_visible",
    ],
    "landmarks": [
        "scan_for_landmark", "double_scan_for_landmark",
        "align_with_nearest_landmark",
    ],
    "markers": [
        "scan_for_marker", "scan_for_marker_by_id", "double_scan_for_marker",
        "align_with_nearest_marker", "center_marker", "distance_to_marker",
    ],
    "soccer": [
        "scan_for_ball", "distance_to_ball", "is_ball_visible",
        "align_with_ball", "center_ball", "kick", "kick_ball", "touch_ball",
        "align_with_ball_and_cube", "align_ball_and_cube", "scan_for_goal",
        "distance_to_goal", "scan_for_left_post", "scan_for_right_post",
        "distance_to_left_post", "distance_to_right_post",
        "align_with_ball_and_left_post", "align_with_ball_and_right_post",
        "compute_hor_dev", "last_err", "is_stable_detection", "get_ball_pnp",
        "init_ball_detection",
    ],
    "line_following": [
        "initialize_line_detector", "get_detected_line_angle",
        "is_line_detected", "init_line_detection",
    ],
    "mars": [
        "send_message", "receive_message", "report_status", "raise_alert",
        "beep", "receive_task",
        "scan_for_ice_sample", "scan_for_freezer", "scan_for_debris",
        "scan_for_rock_sample",
        "pickup_sample", "pickup_debris", "pickup_ice_sample",
        "drop_sample", "drop_debris",
        "store_sample_in_freezer", "align_with_flag",
        "scan_for_crew", "greet_crew_member", "follow_astronaut",
        "wait_for_go_signal",
    ],
    "sustainability": [
        "scan_for_turbine_oil", "align_with_turbine_oil",
        "scan_for_sheep_wool", "align_with_sheep_wool",
        "scan_for_crop_residue", "align_with_crop_residue",
        "scan_for_tree", "align_with_tree",
        "scan_for_fruit_crate", "align_with_fruit_crate",
        "scan_for_signpost", "align_with_signpost",
    ],
    "cv": ["region_of_interest"],
}

_ALL_NAMES = [(area, name) for area, names in PUBLIC_API.items() for name in names]


@pytest.mark.parametrize("dotted", SUBMODULES)
def test_submodule_imports_cleanly(dotted):
    assert importlib.import_module(dotted) is not None


@pytest.mark.parametrize("area,name", _ALL_NAMES, ids=[f"{a}:{n}" for a, n in _ALL_NAMES])
def test_public_function_is_exposed_and_callable(area, name):
    assert hasattr(easy_cozmo, name), f"{name} ({area}) missing from flat namespace"
    assert callable(getattr(easy_cozmo, name)), f"{name} ({area}) is not callable"
