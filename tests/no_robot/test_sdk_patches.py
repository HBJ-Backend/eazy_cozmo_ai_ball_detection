"""The runtime SDK compatibility shim (easy_cozmo._sdk_patches)."""

import types

from PIL import ImageDraw

import easy_cozmo  # noqa: F401, importing applies the shim
from easy_cozmo import _sdk_patches


def test_shim_marked_applied_after_import():
    assert _sdk_patches._applied is True


def test_textsize_restored_on_pillow_10_plus():
    # After `import easy_cozmo`, ImageDraw.textsize is callable again even on
    # Pillow >= 10 (which removed it). On Pillow < 10 it was already present.
    assert hasattr(ImageDraw.ImageDraw, "textsize")


def test_apply_is_idempotent():
    # Calling apply() again is a harmless no-op.
    _sdk_patches.apply()
    assert _sdk_patches._applied is True


def test_shim_textsize_returns_full_line_height():
    # The SDK bottom-anchors text with y = box_bottom - height, so the height
    # has to be the full line box rather than the tight ink bbox. Otherwise
    # labels like the ball distance clip off the bottom of the frame.
    from PIL import Image, ImageDraw, ImageFont
    d = ImageDraw.Draw(Image.new("RGB", (120, 60)))
    font = ImageFont.load_default()
    width, height = d.textsize("Distance 123", font=font)
    ascent, descent = font.getmetrics()
    assert height >= ascent + descent
    ink = d.textbbox((0, 0), "Distance 123", font=font)
    assert height >= ink[3] - ink[1]   # at least as tall as the ink bbox
    assert width > 0


def _box(left_x, top_y, right_x, bottom_y):
    return types.SimpleNamespace(
        left_x=left_x, top_y=top_y, right_x=right_x, bottom_y=bottom_y)


def test_nan_box_wrapper_skips_nonfinite_and_forwards_finite():
    calls = []

    def fake_add_img_box(image, box, color, text=None):
        calls.append(box)

    wrapped = _sdk_patches._make_safe_add_img_box(fake_add_img_box)
    assert wrapped._easy_cozmo_patched is True

    nan_box = _box(float("nan"), 0, 10, 10)
    inf_box = _box(0, 0, float("inf"), 10)
    finite_box = _box(0, 0, 10, 10)

    wrapped(None, nan_box, "red")     # skipped
    wrapped(None, inf_box, "red")     # skipped
    wrapped(None, finite_box, "red")  # forwarded

    assert calls == [finite_box]
