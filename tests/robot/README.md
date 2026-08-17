# Robot tests (manual)

Manual tests for the behaviours that can only be checked on a real Cozmo:
driving, scanning, picking up and placing cubes, ball detection and kicking,
faces and speech. Each script connects to a robot and prints an `EXPECTED:`
line, then narrates what it is doing out loud, so a person can watch and
confirm.

`pytest` does not collect these. The filenames don't start with `test_`, and
`pytest.ini` limits collection to `tests/no_robot/`. Run them one at a time.

## Prerequisites

1. Cozmo connected and the app in SDK mode (iPad over USB with iTunes open).
2. The `cozmo-venv` environment active.
3. `PYTHONPATH` set to the repo root so the repo's `easy_cozmo` is used:
   ```powershell
   cd <repo root>
   $env:PYTHONPATH = (Get-Location).Path
   ```
4. For `scan_ball.py` and `kick_ball.py` only, the detection server has to be
   running in another terminal on `127.0.0.1:44444`:
   ```powershell
   python easy_cozmo\themes\soccer\server.py
   ```

## Running

```powershell
python tests\robot\say.py
python tests\robot\movements.py
python tests\robot\find_cube.py
python tests\robot\pickup_place_cube.py
python tests\robot\stack_cubes.py
python tests\robot\align_cube.py
python tests\robot\scan_ball.py        # needs detection server
python tests\robot\kick_ball.py        # needs detection server
python tests\robot\faces.py
```

## What each covers

| Script | Behaviour | Setup |
|---|---|---|
| `say.py` | Speech (`say`, `say_error`, volume) | none |
| `movements.py` | Drive, rotate, reverse, lift, head | clear space in front |
| `find_cube.py` | `scan_for_cube_by_id` | 1-3 light cubes nearby |
| `pickup_place_cube.py` | Pick up then drop each cube | cubes in front |
| `stack_cubes.py` | Pick up cube 1, place on cube 2 | cubes 1 and 2 in view |
| `align_cube.py` | Drive to and square up with nearest cube | one cube nearby |
| `scan_ball.py` | Detect ball, report distance | orange ball, server |
| `kick_ball.py` | Find, align and kick the ball | orange ball, server |
| `faces.py` | Scan for a face, align, greet a teammate | a person |

These replace the older scripts in `tests/old_tests/`, some of which used the
defunct `mindcraft_treasure_hunt_cozmo` API.
