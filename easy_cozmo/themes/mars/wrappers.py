"""Mars workshop vocabulary.

Thin renames over the core library so the exercises read like a mission log
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

import random

# Which cube plays which part in the mission. Students say "ice sample", not
# "cube 1", so the numbers live here and nowhere else.
ICE_SAMPLE  = 1
FREEZER     = 2
PATH_MARKER = 3


# ---------------------------------------------------------------------------
# Comms: speech, backpack lights and a beep, so a transmission carries across
# a noisy room instead of being only audible or only visible.
#
# Beeps are played as notes through play_song, not through play_audio.
# play_audio posts a fire-and-forget event to the CodeLab game object and is
# silent in SDK mode, with no return value or action to tell you so. play_song
# goes through the animation system, returns an action, and can be waited on,
# so the beep's length is the note's length rather than a guessed pause.
# ---------------------------------------------------------------------------
BEEP_SEND    = (NoteTypes.C3, NoteTypes.C3) 
BEEP_RECEIVE = (NoteTypes.G2, NoteTypes.C3) 
BEEP_OK      = (NoteTypes.A2, NoteTypes.D2)
BEEP_ALERT   = (NoteTypes.C2, NoteTypes.C2, NoteTypes.C2) 


def _play_notes(note_types, duration=NoteDurations.Quarter):
    """Play a short run of notes and wait for it to finish."""
    notes = [SongNote(n, duration) for n in note_types]
    action = easy_cozmo._robot.play_song(notes)
    action.wait_for_completed()
    return bool(action.has_succeeded)


def _signal(light, note_types=None):
    """Light the backpack while a beep plays."""
    robot = easy_cozmo._robot
    robot.set_all_backpack_lights(light)
    if note_types:
        _play_notes(note_types)
    else:
        pause(0.4)
    robot.set_backpack_lights_off()


def send_message(txtmsg, *args):
    _signal(cozmo.lights.blue_light, BEEP_SEND)
    return say("Message sent: " + txtmsg, *args)


def receive_message():
    _signal(cozmo.lights.green_light, BEEP_RECEIVE)
    return say("Message received")


def report_status(txtmsg, *args):
    _signal(cozmo.lights.green_light, BEEP_OK)
    return say("Status: " + txtmsg, *args)


def raise_alert(txtmsg, *args):
    _signal(cozmo.lights.red_light, BEEP_ALERT)
    return say("Alert: " + txtmsg, *args)


def beep(times=1, notes=BEEP_SEND):
    ok = True
    for _ in range(times):
        ok = _play_notes(notes) and ok
    return ok


# ---------------------------------------------------------------------------
# Samples and debris
# ---------------------------------------------------------------------------
def scan_for_ice_sample(angle, scan_speed=df_scan_cube_speed):
    return scan_for_cube_by_id(angle, ICE_SAMPLE, scan_speed=scan_speed)

def scan_for_freezer(angle, scan_speed=df_scan_cube_speed):
    return scan_for_cube_by_id(angle, FREEZER, scan_speed=scan_speed)


def scan_for_debris(angle, scan_speed=df_scan_cube_speed):
    return scan_for_cube(angle, scan_speed=scan_speed)


def scan_for_rock_sample(angle, scan_speed=df_scan_cube_speed):
    return scan_for_cube(angle, scan_speed=scan_speed)


def pickup_sample():
    return pickup_cube()

def pickup_debris():
    return pickup_cube()


def pickup_ice_sample():
    return pickup_cube_by_id(ICE_SAMPLE)


def drop_sample():
    return drop_cube()

def drop_debris():
    return drop_cube()


def store_sample_in_freezer():
    return place_on_top(FREEZER)


def scan_for_flag(angle, scan_speed=df_scan_cube_speed):
    return scan_for_cube_by_id(angle, PATH_MARKER, scan_speed=scan_speed)

def align_with_flag(distance=df_align_distance):
    return align_with_cube_by_id(PATH_MARKER, distance)


# ---------------------------------------------------------------------------
# Crew
# ---------------------------------------------------------------------------
def scan_for_crew(angle=360, scan_speed=df_scan_face_speed):
    return scan_for_teammates(angle, scan_speed)


def greet_crew_member(text_before='', text_after='', *args):
    return say_something_to_visible_teammate(text_before, text_after, *args)


def follow_astronaut():
    return align_with_face()


def wait_for_go_signal(waiting_time):
    return wait_for_a_smiling_face_visible(waiting_time)

# ---------------------------------------------------------------------------
# Other
# ---------------------------------------------------------------------------

def receive_task():
    task_id = random.randint(1,5)
    _signal(cozmo.lights.green_light, BEEP_OK)
    say("Code " + str(task_id))
    
    return task_id
