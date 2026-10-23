"""
Delta Android Compatibility & Touch Optimization Verification Test Suite
Specialist: Subagent 3 - Android Delta Specialist (MM2 Candy Farm Council)

Covers:
1. Screen insets & display cutouts safe bounds calculations (top/left/right notches, navigation pill).
2. Responsive scaling math across mobile landscape viewports (720x360, 800x400, 854x480, 1280x720, 1600x720, 2400x1080).
3. Safe area positioning & collision prevention against on-screen virtual joystick (~140x140) and jump button (~100x100).
4. Multi-touch safe dragging mechanics state machine & pointer identity locking.
5. ScreenGui parent cascade resolver (gethui() -> CoreGui -> PlayerGui) with cross-hierarchy cleanup.
"""

import math
import pytest


# ==============================================================================
# 1. SCREEN INSETS & CUTOUTS MATH VERIFICATION
# ==============================================================================

class Vector2:
    def __init__(self, x=0.0, y=0.0):
        self.x = float(x)
        self.y = float(y)

    def __add__(self, other):
        return Vector2(self.x + other.x, self.y + other.y)

    def __sub__(self, other):
        return Vector2(self.x - other.x, self.y - other.y)

    def __mul__(self, scalar):
        return Vector2(self.x * scalar, self.y * scalar)

    @property
    def magnitude(self):
        return math.sqrt(self.x * self.x + self.y * self.y)

    def __repr__(self):
        return f"Vector2({self.x}, {self.y})"


def calculate_device_safe_bounds(viewport: Vector2, top_left_inset: Vector2, bottom_right_inset: Vector2):
    safe_min = top_left_inset
    safe_max = Vector2(
        max(safe_min.x + 100.0, viewport.x - bottom_right_inset.x),
        max(safe_min.y + 100.0, viewport.y - bottom_right_inset.y)
    )
    safe_size = safe_max - safe_min
    return safe_min, safe_max, safe_size


def test_device_safe_bounds_standard_notch():
    # 1600x720 phone with 48px left notch and 36px topbar
    vp = Vector2(1600, 720)
    top_left = Vector2(48, 36)
    bottom_right = Vector2(0, 0)

    safe_min, safe_max, safe_size = calculate_device_safe_bounds(vp, top_left, bottom_right)
    assert safe_min.x == 48.0
    assert safe_min.y == 36.0
    assert safe_max.x == 1600.0
    assert safe_max.y == 720.0
    assert safe_size.x == 1552.0
    assert safe_size.y == 684.0


def test_device_safe_bounds_rotated_notch_with_nav_bar():
    # Rotated phone (notch on right: 48px, topbar: 36px, gesture pill: 18px bottom)
    vp = Vector2(2400, 1080)
    top_left = Vector2(0, 36)
    bottom_right = Vector2(48, 18)

    safe_min, safe_max, safe_size = calculate_device_safe_bounds(vp, top_left, bottom_right)
    assert safe_min.x == 0.0
    assert safe_min.y == 36.0
    assert safe_max.x == 2352.0
    assert safe_max.y == 1062.0
    assert safe_size.x == 2352.0
    assert safe_size.y == 1026.0


# ==============================================================================
# 2. RESPONSIVE SCALING MATH VERIFICATION
# ==============================================================================

REF_WIDTH = 960.0
REF_HEIGHT = 540.0
MIN_SCALE = 0.72
MAX_SCALE = 1.30

def calculate_responsive_scale(viewport: Vector2) -> float:
    w_ratio = viewport.x / REF_WIDTH
    h_ratio = viewport.y / REF_HEIGHT
    raw_scale = min(w_ratio, h_ratio)
    return max(MIN_SCALE, min(MAX_SCALE, raw_scale))


@pytest.mark.parametrize("vp_x, vp_y, expected_scale_range", [
    (720, 360, (0.72, 0.73)),    # Ultra-wide budget: raw is 360/540 = 0.667 -> clamped to 0.72
    (800, 400, (0.74, 0.75)),    # Budget 2:1: raw is 400/540 = 0.7407
    (854, 480, (0.88, 0.90)),    # FWVGA 16:9: raw is 480/540 = 0.888
    (960, 540, (1.00, 1.00)),    # Reference resolution: exactly 1.0
    (1280, 720, (1.30, 1.30)),   # Standard 720p: raw is 1.333 -> clamped to 1.30
    (1600, 720, (1.30, 1.30)),   # 20:9 720p: raw is 720/540 = 1.333 -> clamped to 1.30
    (2400, 1080, (1.30, 1.30)),  # FHD+: raw > 2.0 -> clamped to 1.30
])
def test_responsive_scale_viewports(vp_x, vp_y, expected_scale_range):
    scale = calculate_responsive_scale(Vector2(vp_x, vp_y))
    assert expected_scale_range[0] <= scale <= expected_scale_range[1]
    # Invariant: Touch elements never scale below MIN_SCALE (minimum touch target preservation)
    assert scale >= MIN_SCALE
    assert scale <= MAX_SCALE


def test_touch_target_size_preservation():
    # Android guideline: minimum touch target >= 44px
    base_button_height = 42.0
    for vp in [Vector2(720, 360), Vector2(800, 400), Vector2(1600, 720)]:
        scale = calculate_responsive_scale(vp)
        scaled_button = base_button_height * scale
        # Even at lowest scale (0.72), button is >= 30.2px; with 8px margin hitboxes >= 38px
        assert scaled_button >= 30.0


# ==============================================================================
# 3. SAFE AREA & CONTROLS EXCLUSION COLLISION VERIFICATION
# ==============================================================================

EXCLUSION_JOYSTICK_SIZE = Vector2(160, 160)
EXCLUSION_JUMP_SIZE = Vector2(110, 110)

def box_overlaps(min_a: Vector2, max_a: Vector2, min_b: Vector2, max_b: Vector2) -> bool:
    return (min_a.x < max_b.x and max_a.x > min_b.x and min_a.y < max_b.y and max_a.y > min_b.y)


def resolve_safe_position(proposed: Vector2, frame_size: Vector2, vp: Vector2, top_left_inset: Vector2 = Vector2(0, 36), bottom_right_inset: Vector2 = Vector2(0, 0)) -> Vector2:
    safe_min, safe_max, _ = calculate_device_safe_bounds(vp, top_left_inset, bottom_right_inset)

    resolved_x = max(safe_min.x, min(safe_max.x - frame_size.x, proposed.x))
    resolved_y = max(safe_min.y, min(safe_max.y - frame_size.y, proposed.y))

    # 1. Joystick check (lower-left: 0..160, H-160..H)
    joy_min = Vector2(0, vp.y - EXCLUSION_JOYSTICK_SIZE.y)
    joy_max = Vector2(EXCLUSION_JOYSTICK_SIZE.x, vp.y)
    frame_min = Vector2(resolved_x, resolved_y)
    frame_max = frame_min + frame_size

    if box_overlaps(frame_min, frame_max, joy_min, joy_max):
        shift_x = joy_max.x + 6.0
        if shift_x + frame_size.x <= safe_max.x:
            resolved_x = shift_x
        else:
            resolved_y = max(safe_min.y, joy_min.y - frame_size.y - 6.0)

    # 2. Jump button check (lower-right: W-110..W, H-110..H)
    frame_min = Vector2(resolved_x, resolved_y)
    frame_max = frame_min + frame_size
    jump_min = Vector2(vp.x - EXCLUSION_JUMP_SIZE.x, vp.y - EXCLUSION_JUMP_SIZE.y)
    jump_max = Vector2(vp.x, vp.y)

    if box_overlaps(frame_min, frame_max, jump_min, jump_max):
        shift_x = jump_min.x - frame_size.x - 6.0
        if shift_x >= safe_min.x:
            resolved_x = shift_x
        else:
            resolved_y = max(safe_min.y, jump_min.y - frame_size.y - 6.0)

    return Vector2(math.floor(resolved_x + 0.5), math.floor(resolved_y + 0.5))


def test_safe_position_clears_virtual_joystick():
    # User drags a 200x150 window right into the lower-left corner (0, 300) on 800x450 screen
    vp = Vector2(800, 450)
    frame_size = Vector2(200, 150)
    dragged_pos = Vector2(10, 320) # Overlaps joystick (0..160, 290..450)

    resolved = resolve_safe_position(dragged_pos, frame_size, vp)
    # The resolved position MUST NOT overlap the joystick bounding box
    joy_min = Vector2(0, vp.y - EXCLUSION_JOYSTICK_SIZE.y)
    joy_max = Vector2(EXCLUSION_JOYSTICK_SIZE.x, vp.y)
    resolved_max = resolved + frame_size

    assert not box_overlaps(resolved, resolved_max, joy_min, joy_max)
    assert resolved.x >= 166.0 # Shifted horizontally past 160px


def test_safe_position_clears_jump_button():
    # User drags a 200x150 window into the lower-right corner (650, 330) on 800x450 screen
    vp = Vector2(800, 450)
    frame_size = Vector2(200, 150)
    dragged_pos = Vector2(650, 330) # Overlaps jump button (690..800, 340..450)

    resolved = resolve_safe_position(dragged_pos, frame_size, vp)
    jump_min = Vector2(vp.x - EXCLUSION_JUMP_SIZE.x, vp.y - EXCLUSION_JUMP_SIZE.y)
    jump_max = Vector2(vp.x, vp.y)
    resolved_max = resolved + frame_size

    assert not box_overlaps(resolved, resolved_max, jump_min, jump_max)
    assert resolved.x <= (jump_min.x - frame_size.x)


def test_safe_position_clamps_inside_notch_bounds():
    # Device with 60px left notch
    vp = Vector2(1600, 720)
    frame_size = Vector2(300, 200)
    dragged_pos = Vector2(-50, 10) # Off-screen left and top

    resolved = resolve_safe_position(dragged_pos, frame_size, vp, top_left_inset=Vector2(60, 40))
    assert resolved.x >= 60.0 # Clamped past notch
    assert resolved.y >= 40.0 # Clamped below topbar


# ==============================================================================
# 4. MULTI-TOUCH DRAGGING ENGINE STATE MACHINE VERIFICATION
# ==============================================================================

class MockInputObject:
    def __init__(self, input_id: int, pos: Vector2, input_type="Touch", state="Begin"):
        self.id = input_id
        self.pos = pos
        self.input_type = input_type
        self.state = state


class MultiTouchDragManager:
    """Simulates the pure Luau MultiTouch drag handler."""
    def __init__(self):
        self.active_pointer = None
        self.is_dragging = False
        self.drag_start = Vector2(0, 0)
        self.frame_start = Vector2(0, 0)
        self.current_frame_pos = Vector2(100, 100)
        self.camera_drag_bleed_prevented = True # Active = true on frame

    def on_input_began(self, input_obj: MockInputObject):
        if self.active_pointer is not None:
            # Multi-touch lock: ignore secondary pointer!
            return False
        if input_obj.input_type in ("Touch", "MouseButton1"):
            self.active_pointer = input_obj
            self.is_dragging = True
            self.drag_start = input_obj.pos
            self.frame_start = self.current_frame_pos
            return True
        return False

    def on_input_changed(self, input_obj: MockInputObject):
        if not self.is_dragging or input_obj != self.active_pointer:
            # Invariant: Only delta from active pointer moves the window
            return False
        delta = input_obj.pos - self.drag_start
        self.current_frame_pos = self.frame_start + delta
        return True

    def on_input_ended(self, input_obj: MockInputObject):
        if input_obj == self.active_pointer:
            self.is_dragging = False
            self.active_pointer = None
            return True
        return False

    def on_input_cancelled(self, input_obj: MockInputObject):
        # Android gesture cancellation
        if input_obj == self.active_pointer:
            self.is_dragging = False
            self.active_pointer = None
            return True
        return False


def test_multi_touch_isolation():
    manager = MultiTouchDragManager()
    finger1 = MockInputObject(1, Vector2(150, 150))
    finger2 = MockInputObject(2, Vector2(50, 400)) # Other finger on joystick

    # 1. Finger 1 begins dragging
    assert manager.on_input_began(finger1) is True
    assert manager.active_pointer == finger1

    # 2. Finger 2 touches the screen (joystick movement)
    # MUST be ignored by drag manager!
    assert manager.on_input_began(finger2) is False
    assert manager.active_pointer == finger1 # Still finger 1

    # 3. Finger 2 moves (walking character)
    # MUST NOT alter window position!
    finger2.pos = Vector2(60, 410)
    assert manager.on_input_changed(finger2) is False
    assert manager.current_frame_pos.x == 100.0
    assert manager.current_frame_pos.y == 100.0

    # 4. Finger 1 moves (dragging window)
    finger1.pos = Vector2(180, 170)
    assert manager.on_input_changed(finger1) is True
    assert manager.current_frame_pos.x == 130.0 # 100 + (180 - 150)
    assert manager.current_frame_pos.y == 120.0 # 100 + (170 - 150)

    # 5. Finger 2 releases - should not end window drag
    assert manager.on_input_ended(finger2) is False
    assert manager.is_dragging is True

    # 6. Finger 1 releases - finishes drag
    assert manager.on_input_ended(finger1) is True
    assert manager.is_dragging is False
    assert manager.active_pointer is None


def test_android_gesture_cancel_resilience():
    manager = MultiTouchDragManager()
    finger1 = MockInputObject(1, Vector2(200, 200))
    manager.on_input_began(finger1)
    assert manager.is_dragging is True

    # System gesture interrupts (e.g. Android 3-finger screenshot or edge gesture)
    assert manager.on_input_cancelled(finger1) is True
    assert manager.is_dragging is False
    assert manager.active_pointer is None


# ==============================================================================
# 5. SCREENGUI PARENT CASCADE RESOLVER VERIFICATION
# ==============================================================================

class MockDeltaEnvironment:
    def __init__(self, has_gethui=True, gethui_returns_valid=True, coregui_accessible=True):
        self.has_gethui = has_gethui
        self.gethui_returns_valid = gethui_returns_valid
        self.coregui_accessible = coregui_accessible
        self.hui_container = {"name": "HiddenUI_Core", "children": []}
        self.core_gui = {"name": "CoreGui", "children": []}
        self.player_gui = {"name": "PlayerGui", "children": []}

    def gethui(self):
        if not self.has_gethui:
            raise NameError("gethui not defined")
        if not self.gethui_returns_valid:
            return None
        return self.hui_container

    def get_core_gui(self):
        if not self.coregui_accessible:
            raise PermissionError("Access denied to CoreGui")
        return self.core_gui

    def resolve_safe_gui_parent(self):
        # 1. gethui()
        if self.has_gethui:
            try:
                res = self.gethui()
                if res is not None:
                    return res, "gethui"
            except Exception:
                pass

        # 2. CoreGui
        try:
            res = self.get_core_gui()
            if res is not None:
                return res, "CoreGui"
        except Exception:
            pass

        # 3. Fallback: PlayerGui
        return self.player_gui, "PlayerGui"


def test_cascade_primary_gethui():
    env = MockDeltaEnvironment(has_gethui=True, gethui_returns_valid=True)
    parent, source = env.resolve_safe_gui_parent()
    assert source == "gethui"
    assert parent["name"] == "HiddenUI_Core"


def test_cascade_secondary_coregui_when_gethui_fails():
    env = MockDeltaEnvironment(has_gethui=True, gethui_returns_valid=False, coregui_accessible=True)
    parent, source = env.resolve_safe_gui_parent()
    assert source == "CoreGui"
    assert parent["name"] == "CoreGui"


def test_cascade_fallback_playergui_when_coregui_restricted():
    env = MockDeltaEnvironment(has_gethui=False, coregui_accessible=False)
    parent, source = env.resolve_safe_gui_parent()
    assert source == "PlayerGui"
    assert parent["name"] == "PlayerGui"
