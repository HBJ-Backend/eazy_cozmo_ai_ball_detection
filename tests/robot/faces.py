"""Manual robot test: faces and teammates.

EXPECTED: Cozmo scans for a face, aligns with it, and (if it recognizes a
registered teammate) greets them by name.

SETUP: stand in front of Cozmo. For the teammate greeting, your face must be
registered via the Meet Cozmo app.

"""
from easy_cozmo import *


def cozmo_program():
    print("=== ROBOT TEST: faces / teammates ===")
    print("EXPECTED: Cozmo finds a face, aligns, and greets a known teammate.")
    set_volume_low()

    if scan_for_faces(360):
        say("I see a face")
        align_with_face()
        if not say_something_to_visible_teammate("Hello", "nice to see you"):
            say("I see you, but I do not recognize you")
            print("  face seen, teammate not recognized")
        else:
            print("  teammate greeted: OK")
    else:
        say("I could not find a face")
        print("  no face found")

    print("DONE.")


if __name__ == "__main__":
    run_program_with_viewer(cozmo_program)
