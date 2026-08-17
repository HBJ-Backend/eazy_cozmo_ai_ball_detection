"""Manual robot test: speech.

EXPECTED: Cozmo speaks three lines aloud (the last prefixed with "ERROR"),
and the same text prints to the console.
"""
from easy_cozmo import *


def cozmo_program():
    print("=== ROBOT TEST: say ===")
    print("EXPECTED: Cozmo speaks each line; the last is an error message.")
    show_happy()
    set_volume_med()
    say("Hello, I am Cozmo")
    say("This is a normal message")
    say_error("This is an error message")
    print("DONE: confirm you heard 3 spoken lines.")


if __name__ == "__main__":
    run_program(cozmo_program)
