"""Manual robot test: align with the nearest block.

EXPECTED: Cozmo finds a cube, drives to it, and squares up with its nearest
face.

SETUP: place one light cube a short distance in front of Cozmo.

"""
from easy_cozmo import *


def cozmo_program():
    print("=== ROBOT TEST: align with nearest cube ===")
    print("EXPECTED: Cozmo drives to and squares up with the nearest cube.")
    set_volume_low()

    if scan_for_cube(360):
        if align_with_nearest_cube():
            say("aligned with the cube")
            print("  aligned: OK")
        else:
            say("could not align")
            print("  align FAILED")
    else:
        say("no cube found")
        print("  no cube found")

    print("DONE.")


if __name__ == "__main__":
    run_program_with_viewer(cozmo_program)
