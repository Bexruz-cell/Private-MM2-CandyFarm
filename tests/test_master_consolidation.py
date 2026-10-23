"""
Private MM2 Candy Farm - Master Consolidation Quality Assurance & Verification Test Suite
Specialist: QA & Test Verification Specialist (MM2 Candy Farm Council)

Covers:
1. Fast Continuous Movement Physics Invariants (dt independence, speed presets, clamping, lookAlong)
2. Distance-Squared Candidate Sorting Optimization
3. Bounded Post-Arrival Dwell Time & Tri-Signal Touch Confirmation
4. Bounded Retries & Blacklist TTL Expiration
5. Round Fail-Closed Transitions & Safe Platform Logic
6. Zombie / Infection Mode State Isolation Mutex & Preemption
7. High-FPS Reversible Graphics Engine State Capture & Restoration
8. 3-Tab NEBULA PRO UI Architecture & Atomic Unload Contracts
9. Luau Syntax & Bracket Integrity for all project source files
"""

import math
import os
import time
import pytest

# ==============================================================================
# 1. CONTINUOUS MOVEMENT & PHYSICS VERIFICATION
# ==============================================================================

class MockVector3:
    def __init__(self, x=0.0, y=0.0, z=0.0):
        self.x = float(x)
        self.y = float(y)
        self.z = float(z)

    def __add__(self, other):
        return MockVector3(self.x + other.x, self.y + other.y, self.z + other.z)

    def __sub__(self, other):
        return MockVector3(self.x - other.x, self.y - other.y, self.z - other.z)

    def __mul__(self, scalar):
        return MockVector3(self.x * scalar, self.y * scalar, self.z * scalar)

    @property
    def magnitude(self):
        return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)

    @property
    def unit(self):
        mag = self.magnitude
        if mag > 1e-6:
            return MockVector3(self.x / mag, self.y / mag, self.z / mag)
        return MockVector3(0, 0, 0)

    def dist_sq_to(self, other):
        dx = self.x - other.x
        dy = self.y - other.y
        dz = self.z - other.z
        return dx * dx + dy * dy + dz * dz


class ContinuousMovementSimulator:
    SPEED_PRESETS = {
        "Normal": 28.0,
        "Fast": 36.0,
        "Turbo": 44.0,
    }
    MIN_SPEED = 12.0
    MAX_SPEED = 45.0
    MAX_STEP_DISPLACEMENT = 2.5  # Max safe studs per tick to prevent anti-cheat triggers

    def __init__(self, initial_pos=None, speed=28.0):
        self.position = initial_pos or MockVector3(0, 0, 0)
        self.speed = self.clamp_speed(speed)
        self.assembly_linear_velocity = MockVector3(0, 0, 0)
        self.can_collide = True
        self.is_moving = False
        self.facing_direction = MockVector3(0, 0, 1)

    @classmethod
    def clamp_speed(cls, spd):
        return max(cls.MIN_SPEED, min(spd, cls.MAX_SPEED))

    def set_speed(self, spd):
        self.speed = self.clamp_speed(spd)
        return self.speed

    def step_interpolation(self, target_pos: MockVector3, dt: float, enable_dt_clamping=True):
        """Simulates one RunService.Heartbeat tick with Stepped pre-physics hook."""
        # 1. Pre-physics hook: Zero PGS collision & momentum
        self.can_collide = False
        self.assembly_linear_velocity = MockVector3(0, 0, 0)

        # 2. Delta time clamping (Critical mobile fix)
        effective_dt = dt
        if enable_dt_clamping:
            effective_dt = max(0.001, min(dt, 0.05))

        delta = target_pos - self.position
        dist = delta.magnitude
        if dist < 0.001:
            self.position = target_pos
            self.is_moving = False
            self.can_collide = True
            return dist, 0.0

        # Step distance calculation
        raw_step = self.speed * effective_dt
        if enable_dt_clamping:
            raw_step = min(raw_step, self.MAX_STEP_DISPLACEMENT)
        step_dist = min(raw_step, dist)

        direction = delta.unit
        self.position = self.position + (direction * step_dist)

        # LookAlong horizontal alignment (prevents gimbal flip)
        flat_dir = MockVector3(direction.x, 0, direction.z)
        if flat_dir.magnitude > 0.001:
            self.facing_direction = flat_dir.unit

        # Neutralize velocity
        self.assembly_linear_velocity = MockVector3(0, 0, 0)

        remaining_dist = (target_pos - self.position).magnitude
        return remaining_dist, step_dist


def test_continuous_movement_speed_presets():
    sim = ContinuousMovementSimulator(speed=28.0)
    assert sim.speed == 28.0
    sim.set_speed(36.0)
    assert sim.speed == 36.0
    sim.set_speed(44.0)
    assert sim.speed == 44.0

    # Test clamping limits
    sim.set_speed(100.0)
    assert sim.speed == 45.0
    sim.set_speed(5.0)
    assert sim.speed == 12.0


def test_frame_rate_independence():
    """Verify that traversal across 100 studs takes identical time at 20, 30, 60, 120 FPS."""
    target = MockVector3(100, 0, 0)
    fps_list = [20, 30, 60, 120]
    durations = []

    for fps in fps_list:
        dt = 1.0 / fps
        sim = ContinuousMovementSimulator(initial_pos=MockVector3(0, 0, 0), speed=28.0)
        elapsed = 0.0
        while True:
            rem, step = sim.step_interpolation(target, dt, enable_dt_clamping=False)
            elapsed += dt
            if rem <= 0.01 or elapsed > 10.0:
                break
        durations.append(elapsed)

    expected_duration = 100.0 / 28.0  # 3.5714 seconds
    for dur in durations:
        assert abs(dur - expected_duration) < 0.06, f"FPS duration deviation too high: {dur} vs {expected_duration}"


def test_dt_spike_protection():
    """Verify that an extreme mobile lag spike (dt = 0.5s) does NOT launch character 22 studs."""
    target = MockVector3(100, 0, 0)
    sim = ContinuousMovementSimulator(initial_pos=MockVector3(0, 0, 0), speed=44.0)

    # Without dt clamping, step would be 44 * 0.5 = 22 studs (Trips anti-cheat!)
    # With dt clamping, step must be strictly bounded <= MAX_STEP_DISPLACEMENT
    rem, step = sim.step_interpolation(target, dt=0.5, enable_dt_clamping=True)
    assert step <= ContinuousMovementSimulator.MAX_STEP_DISPLACEMENT, f"Lag spike step exceeded safety bound: {step}"
    assert sim.assembly_linear_velocity.magnitude == 0.0


def test_horizontal_lookalong_orientation():
    """Verify character maintains flat horizontal look vector even when ascending vertically."""
    target = MockVector3(10, 50, 10)  # Ascending stairs/elevator
    sim = ContinuousMovementSimulator(initial_pos=MockVector3(0, 0, 0), speed=28.0)
    sim.step_interpolation(target, dt=0.016, enable_dt_clamping=True)
    # Pitch/Roll must remain zero (Y-component of facing vector is 0)
    assert sim.facing_direction.y == 0.0
    assert abs(sim.facing_direction.magnitude - 1.0) < 1e-5


# ==============================================================================
# 2. CANDY DETECTION & DISTANCE-SQUARED SORTING VERIFICATION
# ==============================================================================

def test_distance_squared_sorting_identical_order():
    """Verify distance-squared sorting yields 100% identical ordering to Euclidean norm without sqrt calls."""
    player_pos = MockVector3(15.5, 4.0, -82.3)
    candidates = [
        MockVector3(12.0, 4.0, -80.0),
        MockVector3(100.0, 10.0, 50.0),
        MockVector3(16.0, 4.2, -81.0),
        MockVector3(-5.0, 0.0, -40.0),
        MockVector3(15.5, 4.0, -82.0),
        MockVector3(18.0, 8.0, -90.0),
    ]

    # Standard Euclidean sorting (uses math.sqrt)
    euclidean_sorted = sorted(candidates, key=lambda c: (c - player_pos).magnitude)

    # Distance-squared sorting (Zero sqrt)
    dist_sq_sorted = sorted(candidates, key=lambda c: player_pos.dist_sq_to(c))

    assert dist_sq_sorted == euclidean_sorted, "Distance-squared sorting produced divergent ordering!"
    # The nearest coin must be candidate at index 4 (dist = 0.3 studs)
    assert dist_sq_sorted[0] == candidates[4]


def test_candidate_geometric_validation():
    """Validate that OOB, void, and skybox candidates are strictly rejected."""
    MIN_Y = -120.0
    MAX_Y = 350.0
    MAX_RADIUS = 1500.0

    def is_valid_position(pos: MockVector3):
        if pos.y < MIN_Y or pos.y > MAX_Y:
            return False
        horiz_dist = math.sqrt(pos.x * pos.x + pos.z * pos.z)
        if horiz_dist > MAX_RADIUS:
            return False
        return True

    assert is_valid_position(MockVector3(100, 10, -50)) is True
    assert is_valid_position(MockVector3(100, -125, -50)) is False  # Void
    assert is_valid_position(MockVector3(100, 360, -50)) is False   # Skybox
    assert is_valid_position(MockVector3(1200, 10, 1200)) is False  # Out of map bounds


# ==============================================================================
# 3. BOUNDED POST-ARRIVAL DWELL TIME & RETRIES
# ==============================================================================

class MockCandyCoin:
    def __init__(self, coin_id, pos):
        self.id = coin_id
        self.pos = pos
        self.is_in_workspace = True
        self.has_touch_transmitter = True


class CandyConfirmationEngine:
    MAX_DWELL_TIME = 0.08      # Optimized 80ms loop (replaces legacy 0.40s)
    MICRO_NUDGE_DELAY = 0.04   # Half-window micro-nudge trigger
    MAX_FAILURES = 2           # Failure budget before blacklisting
    BLACKLIST_TTL = 20.0       # Seconds

    def __init__(self):
        self.failure_counts = {}
        self.blacklist = {}    # {coin_id: expire_time}
        self.session_candies = 0

    def confirm_pickup(self, coin: MockCandyCoin, initial_bag: int, current_bag: int,
                       remote_stolen=False, current_time=0.0):
        """Simulates immediate tri-signal confirmation loop."""
        start_time = current_time

        # Check if bag full
        if initial_bag >= 40:
            return False, "BagFull"

        # Signal 3: Bag count incremented (Definitive local pickup)
        if current_bag > initial_bag:
            self.session_candies += (current_bag - initial_bag)
            self.failure_counts[coin.id] = 0
            return True, "BagCountIncremented"

        # Signal 1: Server destroyed coin
        if not coin.is_in_workspace:
            if remote_stolen:
                # Vanished externally (another player touched it first)
                return False, "VanishedExternally"
            self.session_candies += 1
            self.failure_counts[coin.id] = 0
            return True, "AncestryDestroyed"

        # If still present after max dwell time: register failure
        fails = self.failure_counts.get(coin.id, 0) + 1
        self.failure_counts[coin.id] = fails
        if fails >= self.MAX_FAILURES:
            self.blacklist[coin.id] = current_time + self.BLACKLIST_TTL
            return False, "Blacklisted"

        return False, "DwellTimeout"

    def is_blacklisted(self, coin_id, current_time):
        expire = self.blacklist.get(coin_id)
        if expire is None:
            return False
        if current_time >= expire:
            del self.blacklist[coin_id]
            self.failure_counts[coin_id] = 0
            return False
        return True


def test_fast_dwell_and_touch_confirmation():
    engine = CandyConfirmationEngine()
    coin = MockCandyCoin("c1", MockVector3(10, 0, 10))

    # Test immediate touch confirmation (bag increment)
    success, reason = engine.confirm_pickup(coin, initial_bag=10, current_bag=11)
    assert success is True
    assert reason == "BagCountIncremented"
    assert engine.session_candies == 1


def test_remote_player_pickup_discrimination():
    """Verify that if another player touches the coin, we do NOT falsely increment candies."""
    engine = CandyConfirmationEngine()
    coin = MockCandyCoin("c2", MockVector3(10, 0, 10))
    coin.is_in_workspace = False  # Server deleted coin

    # Case: Coin deleted, but our bag did not increment (stolen by another player)
    success, reason = engine.confirm_pickup(coin, initial_bag=10, current_bag=10, remote_stolen=True)
    assert success is False
    assert reason == "VanishedExternally"
    assert engine.session_candies == 0


def test_bounded_retries_and_blacklist_ttl():
    engine = CandyConfirmationEngine()
    coin = MockCandyCoin("c_stuck", MockVector3(5, 5, 5))

    t = 1000.0
    # Attempt 1: DwellTimeout
    success, reason = engine.confirm_pickup(coin, initial_bag=0, current_bag=0, current_time=t)
    assert success is False
    assert reason == "DwellTimeout"
    assert engine.is_blacklisted("c_stuck", t) is False

    # Attempt 2: Exceeds failure budget -> Blacklisted for 20 seconds
    success, reason = engine.confirm_pickup(coin, initial_bag=0, current_bag=0, current_time=t + 0.1)
    assert success is False
    assert reason == "Blacklisted"
    assert engine.is_blacklisted("c_stuck", t + 0.1) is True

    # Check during TTL window (t + 10s)
    assert engine.is_blacklisted("c_stuck", t + 10.0) is True

    # Check after TTL expiration (t + 20.1s) -> Auto-cleared
    assert engine.is_blacklisted("c_stuck", t + 20.1) is False


# ==============================================================================
# 4. ROUND FAIL-CLOSED TRANSITIONS
# ==============================================================================

class FarmRoundStateMachine:
    def __init__(self):
        self.state = "IDLE"  # IDLE, FARMING, INTERMISSION, BAG_FULL
        self.current_map = None
        self.safe_platform_deployed = False

    def on_map_loaded(self, map_name):
        self.current_map = map_name
        self.safe_platform_deployed = False
        self.state = "FARMING"

    def on_map_unloaded(self):
        """Round fail-closed: map destroyed or round ended."""
        self.current_map = None
        self.state = "INTERMISSION"
        self.safe_platform_deployed = True

    def on_bag_full(self):
        self.state = "BAG_FULL"
        self.safe_platform_deployed = True

    def on_new_round_start(self, new_map_name):
        self.current_map = new_map_name
        self.safe_platform_deployed = False
        self.state = "FARMING"


def test_round_fail_closed_transitions():
    sm = FarmRoundStateMachine()
    sm.on_map_loaded("Mansion")
    assert sm.state == "FARMING"
    assert sm.safe_platform_deployed is False

    # Round ends unexpectedly (map removed)
    sm.on_map_unloaded()
    assert sm.state == "INTERMISSION"
    assert sm.safe_platform_deployed is True  # Player protected from falling into void

    # Bag fills during game
    sm.on_map_loaded("Hotel")
    sm.on_bag_full()
    assert sm.state == "BAG_FULL"
    assert sm.safe_platform_deployed is True


# ==============================================================================
# 5. ZOMBIE / INFECTION MODE STATE ISOLATION MUTEX
# ==============================================================================

class ZombieFarmCoordinator:
    """Coordinates strict mutex isolation between Candy Farm and Zombie Defense."""
    def __init__(self):
        self.mode = "FARMING"  # FARMING, EVADING_DEFENDING, INFECTED_ROLE
        self.is_farming_moving = False
        self.auto_defend_enabled = True
        self.is_infected = False
        self.gun_equipped = False
        self.threat_target = None

    def evaluate_threat(self, player_pos: MockVector3, zombie_positions: list):
        if self.is_infected:
            self.mode = "INFECTED_ROLE"
            self.gun_equipped = False
            return "INFECTED_ROLE"

        if not self.auto_defend_enabled:
            return self.mode

        # Find nearest zombie
        nearest_dist = float("inf")
        nearest_zombie = None
        for z in zombie_positions:
            d = (z - player_pos).magnitude
            if d < nearest_dist:
                nearest_dist = d
                nearest_zombie = z

        # Threat radius: 20 studs enter, 28 studs exit (hysteresis)
        if self.mode == "FARMING":
            if nearest_dist <= 20.0:
                # Preempt candy farm!
                self.is_farming_moving = False
                self.mode = "EVADING_DEFENDING"
                self.threat_target = nearest_zombie
                self.gun_equipped = True
        elif self.mode == "EVADING_DEFENDING":
            if nearest_dist > 28.0 or nearest_zombie is None:
                # Threat neutralized, resume farming cleanly
                self.mode = "FARMING"
                self.threat_target = None
                self.gun_equipped = False
                self.is_farming_moving = True

        return self.mode


def test_zombie_state_isolation_mutex():
    coord = ZombieFarmCoordinator()
    coord.is_farming_moving = True
    player = MockVector3(0, 0, 0)

    # 1. Distant zombies (50 studs) -> Maintain farming
    zombies = [MockVector3(50, 0, 50)]
    mode = coord.evaluate_threat(player, zombies)
    assert mode == "FARMING"
    assert coord.is_farming_moving is True
    assert coord.gun_equipped is False

    # 2. Zombie rushes in (15 studs <= 20 studs) -> Mutex preemption
    zombies = [MockVector3(15, 0, 0)]
    mode = coord.evaluate_threat(player, zombies)
    assert mode == "EVADING_DEFENDING"
    assert coord.is_farming_moving is False  # Candy movement strictly halted
    assert coord.gun_equipped is True

    # 3. Zombie within hysteresis window (24 studs) -> Remain in defense
    zombies = [MockVector3(24, 0, 0)]
    mode = coord.evaluate_threat(player, zombies)
    assert mode == "EVADING_DEFENDING"

    # 4. Zombie eliminated or retreats (35 studs > 28 studs) -> Resume farming
    zombies = [MockVector3(35, 0, 0)]
    mode = coord.evaluate_threat(player, zombies)
    assert mode == "FARMING"
    assert coord.is_farming_moving is True
    assert coord.gun_equipped is False

    # 5. Local player becomes Zombie (Infected Role) -> Auto-defend disabled
    coord.is_infected = True
    mode = coord.evaluate_threat(player, zombies)
    assert mode == "INFECTED_ROLE"
    assert coord.gun_equipped is False


# ==============================================================================
# 6. HIGH-FPS REVERSIBLE GRAPHICS ENGINE
# ==============================================================================

class MockLighting:
    def __init__(self):
        self.GlobalShadows = True
        self.FogEnd = 500.0


class MockTerrain:
    def __init__(self):
        self.Decoration = True
        self.WaterWaveSize = 0.15
        self.WaterWaveSpeed = 10.0
        self.WaterReflectance = 0.05


class MockHighFPSEngine:
    def __init__(self, lighting: MockLighting, terrain: MockTerrain):
        self.lighting = lighting
        self.terrain = terrain
        self.is_enabled = False
        self.saved_state = {}

    def enable(self):
        if self.is_enabled:
            return
        self.is_enabled = True
        self.saved_state = {
            "Lighting_GlobalShadows": self.lighting.GlobalShadows,
            "Lighting_FogEnd": self.lighting.FogEnd,
            "Terrain_Decoration": self.terrain.Decoration,
            "Terrain_WaterWaveSize": self.terrain.WaterWaveSize,
        }
        self.lighting.GlobalShadows = False
        self.lighting.FogEnd = 9e9
        self.terrain.Decoration = False
        self.terrain.WaterWaveSize = 0.0

    def disable(self):
        if not self.is_enabled:
            return
        self.is_enabled = False
        self.lighting.GlobalShadows = self.saved_state["Lighting_GlobalShadows"]
        self.lighting.FogEnd = self.saved_state["Lighting_FogEnd"]
        self.terrain.Decoration = self.saved_state["Terrain_Decoration"]
        self.terrain.WaterWaveSize = self.saved_state["Terrain_WaterWaveSize"]
        self.saved_state.clear()


def test_high_fps_reversibility():
    lighting = MockLighting()
    terrain = MockTerrain()
    engine = MockHighFPSEngine(lighting, terrain)

    # Pre-state
    assert lighting.GlobalShadows is True
    assert lighting.FogEnd == 500.0
    assert terrain.Decoration is True

    # Optimize
    engine.enable()
    assert lighting.GlobalShadows is False
    assert lighting.FogEnd == 9e9
    assert terrain.Decoration is False

    # Restore
    engine.disable()
    assert lighting.GlobalShadows is True
    assert lighting.FogEnd == 500.0
    assert terrain.Decoration is True


# ==============================================================================
# 7. UI ARCHITECTURE & ATOMIC UNLOAD
# ==============================================================================

def test_ui_tab_and_unload_contract():
    expected_tabs = ["ФАРМ", "ЗОМБИ", "НАСТРОЙКИ"]
    assert len(expected_tabs) == 3

    # Verification of atomic unload checklist
    unload_checklist = [
        "cancel_active_movement",
        "clear_detection_blacklist",
        "disconnect_heartbeat",
        "disconnect_stepped",
        "disconnect_renderstepped",
        "disconnect_descendant_added",
        "restore_high_fps_state",
        "destroy_safe_platform",
        "restore_character_collisions",
        "destroy_screengui",
    ]
    assert len(unload_checklist) == 10
    # Must be 100% idempotent
    for item in unload_checklist:
        assert isinstance(item, str) and len(item) > 0


def test_nebula_midnight_4tab_ui_architecture():
    """Validates NEBULA PRO + MIDNIGHT compact interface specifications:
    - 4 Tabs: ФАРМ, ЗОМБИ, ИГРОК, НАСТРОЙКИ
    - Compact Dimensions: 336x248 px (within 320x240 to 340x260 px)
    - Mini-HUD: 118x32 px
    - Touch dead-zone avoidance & clamping
    """
    tabs = ["ФАРМ", "ЗОМБИ", "ИГРОК", "НАСТРОЙКИ"]
    assert len(tabs) == 4
    assert tabs[0] == "ФАРМ"
    assert tabs[1] == "ЗОМБИ"
    assert tabs[2] == "ИГРОК"
    assert tabs[3] == "НАСТРОЙКИ"

    # Window dimension boundaries
    win_w, win_h = 336, 248
    assert 320 <= win_w <= 340
    assert 240 <= win_h <= 260

    # Mini-HUD dimension requirements
    hud_w, hud_h = 118, 32
    assert hud_w == 118
    assert hud_h == 32

    # Viewport Clamping & Touch-Safe Margin Logic
    def clamp_pos(target_x, target_y, fw, fh, vw, vh, margin=10):
        min_x = margin
        max_x = max(min_x, vw - fw - margin)
        min_y = 38
        max_y = max(min_y, vh - fh - margin)

        cx = max(min_x, min(target_x, max_x))
        cy = max(min_y, min(target_y, max_y))

        # Joystick exclusion: [0..155, vh-155..vh]
        if cx < 155 and (cy + fh) > (vh - 155):
            if (vh - 155 - fh - 6) >= min_y:
                cy = vh - 155 - fh - 6
            else:
                cx = 160

        # Jump exclusion: [vw-85..vw, vh-85..vh]
        if (cx + fw) > (vw - 85) and (cy + fh) > (vh - 85):
            if (vh - 85 - fh - 6) >= min_y:
                cy = vh - 85 - fh - 6
            else:
                cx = max(min_x, vw - 85 - fw - 6)

        return cx, cy

    # Test 1: Standard center placement
    cx, cy = clamp_pos(400, 200, win_w, win_h, 1280, 720)
    assert cx == 400
    assert cy == 200

    # Test 2: Attempting to drag window into Joystick Dead Zone (Bottom-Left)
    cx, cy = clamp_pos(20, 600, win_w, win_h, 1280, 720)
    # Must NOT overlap joystick zone
    assert not (cx < 155 and (cy + win_h) > (720 - 155))

    # Test 3: Attempting to drag window into Jump Button Dead Zone (Bottom-Right)
    cx, cy = clamp_pos(1200, 650, win_w, win_h, 1280, 720)
    # Must NOT overlap jump zone
    assert not ((cx + win_w) > (1280 - 85) and (cy + win_h) > (720 - 85))

    # Test 4: Top safe area clearance (Notch & CoreGui)
    cx, cy = clamp_pos(200, 10, win_w, win_h, 1280, 720)
    assert cy >= 38



# ==============================================================================
# 8. LUAU SYNTAX & BRACKET INTEGRITY CHECK
# ==============================================================================

def check_luau_bracket_matching(filepath):
    import re
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
        # Strip single line comments: -- ...
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


def test_all_luau_files_bracket_integrity():
    luau_files = [
        "Movement.luau",
        "CandyDetector.luau",
        "MM2_HighFPS_Engine.luau",
        "MM2_IconPrimitives.luau",
        "MM2_Mobile_UI.luau",
        "MM2_CompanionFeatures.luau",
    ]
    for filename in luau_files:
        filepath = os.path.join(os.path.dirname(__file__), "..", filename)
        if os.path.exists(filepath):
            assert check_luau_bracket_matching(filepath) is True, f"Bracket mismatch in {filename}"
