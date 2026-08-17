"""Manual robot test: pick up and put down blocks.

EXPECTED: for each cube it can find, Cozmo picks it up, then drops it.

SETUP: place light cubes in front of Cozmo at head level.

"""
from easy_cozmo import *


def cozmo_program():
    print("=== ROBOT TEST: pick up and place cubes ===")
    print("EXPECTED: each found cube is picked up, then dropped.")
    set_volume_low()

    for cube_id in (1, 2, 3):
        if not scan_for_cube_by_id(360, cube_id):
            print(f"  cube {cube_id}: not found, skipping")
            continue
        if pickup_cube_by_id(cube_id):
            say("picked up cube " + str(cube_id))
            drop_cube()
            say("dropped cube " + str(cube_id))
            print(f"  cube {cube_id}: picked up and dropped")
        else:
            say("could not pick up cube " + str(cube_id))
            print(f"  cube {cube_id}: pickup FAILED")

    print("DONE.")


if __name__ == "__main__":
    run_program_with_viewer(cozmo_program)
