"""Sustainability wrappers: each name must reach the right cube id."""

import pytest

from easy_cozmo.themes.sustainability import wrappers


SCANS = [
    ("scan_for_turbine_oil", 1),
    ("scan_for_sheep_wool", 1),
    ("scan_for_crop_residue", 1),
    ("scan_for_tree", 1),
    ("scan_for_fruit_crate", 2),
    ("scan_for_signpost", 3),
]

ALIGNS = [
    ("align_with_turbine_oil", 1),
    ("align_with_sheep_wool", 1),
    ("align_with_crop_residue", 1),
    ("align_with_tree", 1),
    ("align_with_fruit_crate", 2),
    ("align_with_signpost", 3),
]


@pytest.mark.parametrize("name,cube_id", SCANS)
def test_scan_wrapper_targets_its_cube(robot, monkeypatch, name, cube_id):
    seen = {}

    def fake_scan(angle, cid, scan_speed=None, annotate=True):
        seen.update(angle=angle, cube_id=cid, scan_speed=scan_speed)
        return True

    monkeypatch.setattr(wrappers, "scan_for_cube_by_id", fake_scan)
    assert getattr(wrappers, name)(90, scan_speed=42) is True
    assert seen == {"angle": 90, "cube_id": cube_id, "scan_speed": 42}


@pytest.mark.parametrize("name,cube_id", ALIGNS)
def test_align_wrapper_targets_its_cube(robot, monkeypatch, name, cube_id):
    seen = {}

    def fake_align(cid, distance=None, refined=None):
        seen.update(cube_id=cid, distance=distance)
        return True

    monkeypatch.setattr(wrappers, "align_with_cube_by_id", fake_align)
    assert getattr(wrappers, name)(distance=200) is True
    assert seen == {"cube_id": cube_id, "distance": 200}


def test_scan_wrappers_default_the_scan_speed(robot, monkeypatch):
    from easy_cozmo.core.defaults import df_scan_cube_speed
    seen = {}
    monkeypatch.setattr(
        wrappers, "scan_for_cube_by_id",
        lambda angle, cid, scan_speed=None, annotate=True: seen.update(
            scan_speed=scan_speed) or True)
    wrappers.scan_for_tree(90)
    assert seen["scan_speed"] == df_scan_cube_speed


def test_cube_role_constants():
    # Cube 1 is the collectable item under four different names.
    assert (wrappers.TURBINE_OIL, wrappers.SHEEP_WOOL,
            wrappers.CROP_RESIDUE, wrappers.TREE) == (1, 1, 1, 1)
    assert (wrappers.FRUIT_CRATE, wrappers.SIGNPOST) == (2, 3)
