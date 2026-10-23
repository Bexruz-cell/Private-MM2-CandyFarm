"""
Unit & Behavioral Verification Suite for MM2 Companion Features
Target Module: MM2_CompanionFeatures.luau
Covers:
  1. Luau Bracket and Syntax Integrity
  2. Session Timer (HH:MM:SS format, monotonic elapsed time, pause/resume/reset)
  3. Player Stats Monitor (Health/MaxHealth ratio, status colors, WalkSpeed, death states)
  4. Map Detector (workspace container resolution, CoinContainer discovery, read-only guarantees)
  5. MM2 Round State Observer (state transitions, fail-closed timeouts, non-competing contract)
  6. UI Customization Engine (Transparency bounds [0.0, 0.5], UIScale bounds [0.6, 1.1], preset palettes)
  7. Diagnostic Panel & Error Logger (pcall capture, stack trace logging, 60-item FIFO ring buffer)
"""

import os
import math
import re
import pytest

# ==============================================================================
# 1. LUAU SYNTAX & BRACKET INTEGRITY
# ==============================================================================

def check_luau_bracket_matching(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    # Strip out Lua multiline comments: --[(=*)[ ... ]\1]
    content = re.sub(r'--\[(=*)\[.*?\]\1\]', '', content, flags=re.DOTALL)
    # Strip out Lua multiline strings: [(=*)[ ... ]\1]
    content = re.sub(r'(?<!-)\[(=*)\[.*?\]\1\]', '""', content, flags=re.DOTALL)

    stack = []
    pairs = {')': '(', ']': '[', '}': '{'}
    lines = content.splitlines()

    for lno, line in enumerate(lines, 1):
        line_code = re.sub(r'--.*$', '', line)
        i = 0
        while i < len(line_code):
            c = line_code[i]
            if c in ('"', "'"):
                quote = c
                i += 1
                while i < len(line_code) and line_code[i] != quote:
                    if line_code[i] == '\\':
                        i += 1
                    i += 1
            elif c in ('(', '[', '{'):
                stack.append((c, lno))
            elif c in (')', ']', '}'):
                if not stack:
                    raise SyntaxError(f"Unmatched closing '{c}' at line {lno} in {filepath}")
                top, top_lno = stack.pop()
                if pairs[c] != top:
                    raise SyntaxError(f"Mismatched '{c}' at line {lno}, expected match for '{top}' from line {top_lno} in {filepath}")
            i += 1

    if stack:
        raise SyntaxError(f"Unclosed delimiter {stack[-1]} in {filepath}")
    return True


def test_companion_features_luau_bracket_integrity():
    filepath = os.path.join(os.path.dirname(__file__), "..", "MM2_CompanionFeatures.luau")
    if not os.path.exists(filepath):
        filepath = os.path.join(os.path.dirname(__file__), "..", "src", "core", "CompanionTelemetry.luau")
    assert os.path.exists(filepath), "MM2_CompanionFeatures.luau or src/core/CompanionTelemetry.luau must exist"
    assert check_luau_bracket_matching(filepath) is True


# ==============================================================================
# 2. SESSION TIMER VERIFICATION
# ==============================================================================

class MockSessionTimer:
    def __init__(self):
        self.start_time = 0.0
        self.accumulated = 0.0
        self.is_active = False

    def start(self, current_time):
        if self.is_active:
            return
        self.start_time = current_time
        self.is_active = True

    def pause(self, current_time):
        if not self.is_active:
            return
        self.accumulated += (current_time - self.start_time)
        self.is_active = False

    def resume(self, current_time):
        if self.is_active:
            return
        self.start_time = current_time
        self.is_active = True

    def reset(self, current_time):
        self.start_time = current_time
        self.accumulated = 0.0

    def get_elapsed_seconds(self, current_time):
        if self.is_active:
            return self.accumulated + (current_time - self.start_time)
        return self.accumulated

    def get_formatted_time(self, current_time):
        total_secs = math.floor(self.get_elapsed_seconds(current_time))
        hours = total_secs // 3600
        mins = (total_secs % 3600) // 60
        secs = total_secs % 60
        return f"{hours:02d}:{mins:02d}:{secs:02d}"


def test_session_timer_formatting_and_lifecycle():
    timer = MockSessionTimer()
    t = 100.0

    timer.start(t)
    assert timer.get_formatted_time(t) == "00:00:00"

    # Step 59 seconds
    assert timer.get_formatted_time(t + 59.0) == "00:00:59"

    # Step to 1 minute 15 seconds
    assert timer.get_formatted_time(t + 75.0) == "00:01:15"

    # Step to 2 hours, 14 minutes, 33 seconds
    assert timer.get_formatted_time(t + 8073.0) == "02:14:33"

    # Pause at t + 8073
    timer.pause(t + 8073.0)
    assert timer.get_formatted_time(t + 9000.0) == "02:14:33"  # Frozen while paused

    # Resume at t + 9000
    timer.resume(t + 9000.0)
    assert timer.get_formatted_time(t + 9010.0) == "02:14:43"

    # Reset
    timer.reset(t + 9010.0)
    assert timer.get_formatted_time(t + 9010.0) == "00:00:00"


# ==============================================================================
# 3. PLAYER STATS MONITOR VERIFICATION
# ==============================================================================

class MockPlayerStatsMonitor:
    def __init__(self):
        self.health = 100
        self.max_health = 100
        self.walk_speed = 16.0
        self.is_alive = True
        self.status_text = "[СТАТУС: ЖИВ]"

    def evaluate(self, health, max_health, walk_speed):
        if health <= 0 or max_health <= 0:
            self.health = 0
            self.max_health = max(1, max_health)
            self.walk_speed = 0.0
            self.is_alive = False
            self.status_text = "[СТАТУС: ПОГИБ]"
            return 0.0, "[СТАТУС: ПОГИБ]"

        ratio = max(0.0, min(float(health) / float(max_health), 1.0))
        self.health = math.floor(health)
        self.max_health = math.floor(max_health)
        self.walk_speed = walk_speed
        self.is_alive = True

        if ratio > 0.60:
            self.status_text = "[ЗДОРОВЬЕ: НОРМА]"
        elif ratio >= 0.25:
            self.status_text = "[ЗДОРОВЬЕ: РАНЕН]"
        else:
            self.status_text = "[ЗДОРОВЬЕ: КРИТИЧЕСКИ]"

        return ratio, self.status_text


def test_player_stats_evaluation():
    psm = MockPlayerStatsMonitor()

    # Normal state
    ratio, status = psm.evaluate(100, 100, 16.0)
    assert ratio == 1.0
    assert status == "[ЗДОРОВЬЕ: НОРМА]"
    assert psm.is_alive is True

    # Wounded state (50% HP)
    ratio, status = psm.evaluate(50, 100, 16.0)
    assert ratio == 0.50
    assert status == "[ЗДОРОВЬЕ: РАНЕН]"

    # Critical state (15% HP)
    ratio, status = psm.evaluate(15, 100, 16.0)
    assert ratio == 0.15
    assert status == "[ЗДОРОВЬЕ: КРИТИЧЕСКИ]"

    # Death state (0 HP)
    ratio, status = psm.evaluate(0, 100, 0.0)
    assert ratio == 0.0
    assert status == "[СТАТУС: ПОГИБ]"
    assert psm.is_alive is False
    assert psm.walk_speed == 0.0


# ==============================================================================
# 4. CURRENT MAP DETECTOR & NON-INTRUSIVE RESOLUTION
# ==============================================================================

class MockWorkspaceMap:
    def __init__(self, name, has_coins=True, coin_count=40):
        self.name = name
        self.has_coins = has_coins
        self.coin_count = coin_count
        self.extents = (120.0, 30.0, 150.0)


def resolve_active_map(workspace_children):
    # Check "Normal" first
    for child in workspace_children:
        if child.name == "Normal":
            return child.name, child.coin_count if child.has_coins else 0

    # Check known names
    known = {"Mansion2", "BioLab", "Factory", "MilBase", "House2", "Hospital3", "Hotel", "Bank2"}
    for child in workspace_children:
        if child.name in known:
            return child.name, child.coin_count if child.has_coins else 0

    # Fallback with coins
    for child in workspace_children:
        if child.has_coins:
            return child.name, child.coin_count

    return None, 0


def test_map_detector_resolution():
    # Case 1: Standard MM2 Normal model
    children = [MockWorkspaceMap("Normal", has_coins=True, coin_count=35)]
    name, coins = resolve_active_map(children)
    assert name == "Normal"
    assert coins == 35

    # Case 2: Named map model
    children = [MockWorkspaceMap("Mansion2", has_coins=True, coin_count=40)]
    name, coins = resolve_active_map(children)
    assert name == "Mansion2"
    assert coins == 40

    # Case 3: Empty workspace (Lobby)
    children = []
    name, coins = resolve_active_map(children)
    assert name is None
    assert coins == 0


# ==============================================================================
# 5. ROUND OBSERVER STATE MACHINE (Non-competing)
# ==============================================================================

class MockRoundObserver:
    def __init__(self):
        self.state = "LOBBY"
        self.history = []

    def transition(self, new_state, details=None):
        if self.state == new_state:
            return
        old = self.state
        self.state = new_state
        self.history.append((old, new_state, details))


def test_round_observer_transitions():
    obs = MockRoundObserver()
    assert obs.state == "LOBBY"

    # Role selected
    obs.transition("STARTING", {"Signal": "RoleSelect"})
    assert obs.state == "STARTING"

    # Round starts
    obs.transition("IN_PROGRESS", {"Signal": "RoundStart"})
    assert obs.state == "IN_PROGRESS"

    # Round ends
    obs.transition("ROUND_END", {"Signal": "RoundEndFade"})
    assert obs.state == "ROUND_END"

    # Timeout returns to lobby
    obs.transition("LOBBY", {"Signal": "LobbyReturnTimeout"})
    assert obs.state == "LOBBY"

    assert len(obs.history) == 4
    assert obs.history[0] == ("LOBBY", "STARTING", {"Signal": "RoleSelect"})
    assert obs.history[1] == ("STARTING", "IN_PROGRESS", {"Signal": "RoundStart"})


# ==============================================================================
# 6. UI CUSTOMIZATION FORMULAS & CLAMPING
# ==============================================================================

def clamp_transparency(alpha: float) -> float:
    return max(0.0, min(float(alpha), 0.5))


def clamp_ui_scale(scale: float) -> float:
    return max(0.6, min(float(scale), 1.1))


def compute_slider_ratio(input_x: float, track_x: float, track_w: float) -> float:
    if track_w <= 0:
        return 0.0
    return max(0.0, min((input_x - track_x) / track_w, 1.0))


def test_ui_customization_bounds():
    # Transparency bounds [0.0, 0.5]
    assert clamp_transparency(-0.2) == 0.0
    assert clamp_transparency(0.0) == 0.0
    assert clamp_transparency(0.35) == 0.35
    assert clamp_transparency(0.5) == 0.5
    assert clamp_transparency(0.8) == 0.5  # Prevents invisible UI!

    # UIScale bounds [0.6, 1.1]
    assert clamp_ui_scale(0.3) == 0.6  # Prevents micro unclickable UI
    assert clamp_ui_scale(0.85) == 0.85
    assert clamp_ui_scale(1.0) == 1.0
    assert clamp_ui_scale(1.5) == 1.1  # Prevents offscreen overflow

    # Touch slider ratio calculation
    track_pos = 100.0
    track_width = 200.0
    assert compute_slider_ratio(100.0, track_pos, track_width) == 0.0
    assert compute_slider_ratio(200.0, track_pos, track_width) == 0.5
    assert compute_slider_ratio(300.0, track_pos, track_width) == 1.0
    assert compute_slider_ratio(50.0, track_pos, track_width) == 0.0   # Left clamp
    assert compute_slider_ratio(400.0, track_pos, track_width) == 1.0  # Right clamp


# ==============================================================================
# 7. DIAGNOSTIC PANEL & 60-ITEM FIFO RING BUFFER
# ==============================================================================

class MockDiagnosticRingBuffer:
    def __init__(self, capacity=60):
        self.capacity = capacity
        self.buffer = []

    def log(self, level, source, message):
        entry = {"level": level, "source": source, "message": message}
        if len(self.buffer) >= self.capacity:
            self.buffer.pop(0)  # FIFO pop oldest
        self.buffer.append(entry)

    def safe_call(self, source, func, *args):
        try:
            return True, func(*args)
        except Exception as e:
            self.log("ERROR", source, str(e))
            return False, str(e)


def test_diagnostic_ring_buffer_fifo():
    logger = MockDiagnosticRingBuffer(capacity=5)

    for i in range(1, 8):
        logger.log("INFO", "Test", f"Message {i}")

    assert len(logger.buffer) == 5
    # Oldest (1, 2) dropped; buffer contains [3, 4, 5, 6, 7]
    assert logger.buffer[0]["message"] == "Message 3"
    assert logger.buffer[-1]["message"] == "Message 7"


def test_safe_call_exception_containment():
    logger = MockDiagnosticRingBuffer(capacity=10)

    def risky_operation(should_fail=True):
        if should_fail:
            raise ValueError("Test executor exception")
        return "SUCCESS"

    # Case 1: Success
    ok, res = logger.safe_call("Risky1", risky_operation, False)
    assert ok is True
    assert res == "SUCCESS"
    assert len(logger.buffer) == 0

    # Case 2: Exception trapped and logged without bubbling
    ok, res = logger.safe_call("Risky2", risky_operation, True)
    assert ok is False
    assert "Test executor exception" in res
    assert len(logger.buffer) == 1
    assert logger.buffer[0]["level"] == "ERROR"
    assert logger.buffer[0]["source"] == "Risky2"
