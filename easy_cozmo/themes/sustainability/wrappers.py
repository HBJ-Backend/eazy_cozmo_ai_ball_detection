"""Sustainability workshop vocabulary.

Thin renames over the core library so the exercises read like farming tasks 
instead of a cube-and-face API.
"""

import cozmo
from cozmo.song import NoteDurations, NoteTypes, SongNote

from ...core import easy_cozmo
from ...core.defaults import (df_align_distance, df_scan_cube_speed,
                              df_scan_face_speed)
from ...core.robot_utils import disable_head_light, enable_head_light, pause
from ...core.say import say
from ...actions.actions_with_cubes import (align_with_cube_by_id,
                                           distance_to_cube, drop_cube,
                                           pickup_cube, pickup_cube_by_id,
                                           place_on_top, scan_for_cube,
                                           scan_for_cube_by_id)
from ...actions.actions_with_faces import (align_with_face, scan_for_teammates,
                                           say_something_to_visible_teammate,
                                           wait_for_a_smiling_face_visible)

# Which cube plays which part. Cube 1 is the collectable item in every
# scenario, so it answers to several names; the numbers live here and nowhere
# else, and students say "sheep wool", not "cube 1".
TURBINE_OIL  = 1
SHEEP_WOOL   = 1
CROP_RESIDUE = 1
TREE         = 1
FRUIT_CRATE  = 2
SIGNPOST     = 3


# ---------------------------------------------------------------------------
# Collectable items 
# ---------------------------------------------------------------------------
def scan_for_turbine_oil(angle, scan_speed=df_scan_cube_speed):
    return scan_for_cube_by_id(angle, TURBINE_OIL, scan_speed=scan_speed)


def align_with_turbine_oil(distance=df_align_distance):
    return align_with_cube_by_id(TURBINE_OIL, distance)


def scan_for_sheep_wool(angle, scan_speed=df_scan_cube_speed):
    return scan_for_cube_by_id(angle, SHEEP_WOOL, scan_speed=scan_speed)


def align_with_sheep_wool(distance=df_align_distance):
    return align_with_cube_by_id(SHEEP_WOOL, distance)


def scan_for_crop_residue(angle, scan_speed=df_scan_cube_speed):
    return scan_for_cube_by_id(angle, CROP_RESIDUE, scan_speed=scan_speed)


def align_with_crop_residue(distance=df_align_distance):
    return align_with_cube_by_id(CROP_RESIDUE, distance)


def scan_for_tree(angle, scan_speed=df_scan_cube_speed):
    return scan_for_cube_by_id(angle, TREE, scan_speed=scan_speed)


def align_with_tree(distance=df_align_distance):
    return align_with_cube_by_id(TREE, distance)


# ---------------------------------------------------------------------------
# Fixed features of the farm
# ---------------------------------------------------------------------------
def scan_for_fruit_crate(angle, scan_speed=df_scan_cube_speed):
    return scan_for_cube_by_id(angle, FRUIT_CRATE, scan_speed=scan_speed)


def align_with_fruit_crate(distance=df_align_distance):
    return align_with_cube_by_id(FRUIT_CRATE, distance)


def scan_for_signpost(angle, scan_speed=df_scan_cube_speed):
    return scan_for_cube_by_id(angle, SIGNPOST, scan_speed=scan_speed)


def align_with_signpost(distance=df_align_distance):
    return align_with_cube_by_id(SIGNPOST, distance)