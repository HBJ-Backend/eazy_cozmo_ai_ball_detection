"""Manual robot test: find blocks (cubes) by id.

EXPECTED: Cozmo rotates scanning for each cube id 1..3 and reports which it
found.

SETUP: place one or more light cubes around Cozmo.

"""
from easy_cozmo import *


def cozmo_program():
    print("=== ROBOT TEST: find cubes ===")
    print("EXPECTED: Cozmo scans for cube ids 1, 2, 3 and reports each.")
    set_volume_low()

    for cube_id in (1, 2, 3):
        if scan_for_cube_by_id(360, cube_id):
            say("I found cube " + str(cube_id))
            print(f"  cube {cube_id}: FOUND")
        else:
            say("I could not find cube " + str(cube_id))
            print(f"  cube {cube_id}: not found")

    print("DONE.")


if __name__ == "__main__":
    run_program_with_viewer(cozmo_program)
