"""Manual robot test: stack one block on another.

EXPECTED: Cozmo picks up cube 1 and places it on top of cube 2.

SETUP: place cube 1 and cube 2 within view.
"""
from easy_cozmo import *


def cozmo_program():
    print("=== ROBOT TEST: stack cube 1 on cube 2 ===")
    print("EXPECTED: cube 1 is picked up and placed on top of cube 2.")
    set_volume_low()

    if not (scan_for_cube_by_id(360, 1) and pickup_cube_by_id(1)):
        say("could not pick up cube 1")
        print("  pickup of cube 1 FAILED")
        return

    say("now placing on cube 2")
    if scan_for_cube_by_id(360, 2) and place_on_top(2):
        say("stacked successfully")
        print("  stacked: OK")
    else:
        say("could not place on cube 2")
        print("  place_on_top FAILED")

    print("DONE.")


if __name__ == "__main__":
    run_program_with_viewer(cozmo_program)
