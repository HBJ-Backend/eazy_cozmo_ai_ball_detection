# No-robot tests

Automated tests for `easy_cozmo` that run without a Cozmo, a phone, or a
network. Only the `cozmo` SDK is faked (see `sdk_fakes.py`). numpy, OpenCV,
PIL, imutils and scipy are the real packages, so the geometry and image tests
run against real code.

These cover the pure-Python logic and check that imports and re-exports still
work after an edit. Anything that needs real hardware (scanning, detection,
motion, the YOLO socket) is covered by [`tests/robot/`](../robot/) instead.

## Running

From the repo root, with the dev virtualenv active:

```
pip install -r requirements-dev.txt
pytest
```

`pytest.ini` sets `testpaths = tests/no_robot`, so a bare `pytest` only picks up
this suite, not the manual scripts in `tests/robot/` or the archived ones in
`tests/old_tests/` (those call `run_program()` on import).

## What's covered

- `test_public_api.py`: every submodule imports and every public function is
  still callable on the flat `easy_cozmo` namespace. This is the one that
  catches a broken import chain. Add new public functions here.
- `test_movements.py`: cm to mm conversion, rotation signs, lift and head
  positions, reverse, wheel speed limits, stop, steer, aliases.
- `test_actions_with_cubes.py`: cube id validation, visibility checks,
  pickup and place success and failure paths.
- `test_actions_with_objects.py`: observable-object and visibility helpers.
- `test_faces.py`: face and teammate visibility, scan gating.
- `test_say.py`: `say()`, `say_error()`, `_say()` text and the ERROR prefix.
- `test_robot_utils.py`: trig helpers, volume and headlight wrappers, `pause`,
  `abort`.
- `test_odometry.py`: `wrap_angle` math, reset and accessors, init wiring.
- `test_animations.py`: each animation plays the right trigger.
- `test_ball_geometry.py`: `get_ball_pnp` distance and detection stability.
- `test_cv_preprocessing.py`: YOLO preprocessing shape and dtype, HSV mask,
  above-horizon crop.

## How the fake works

`conftest.py` puts the fake `cozmo` package into `sys.modules` before
`easy_cozmo` is imported. In `sdk_fakes.py`:

- `Q(unit, value)` is a tagged quantity, so unit conversions like `degrees` or
  `distance_mm` can be asserted by equality.
- `_AutoModule` is a module whose unknown attributes resolve to mocks. Used for
  `cozmo.util`, `objects`, `annotate`, `robot`, `world`, `faces`, `anim`.
- Real classes where import-time behaviour needs them: `Pose`, `LightCube`,
  `CustomObject`, `annotate.Annotator`.
- `make_robot()`, `make_cube()` and `make_face()` back the fixtures.
  `set_robot()` installs the robot as the library's global `_robot`.
