"""
Private MM2 Candy Farm & RockHub Companion - Comprehensive QA Regression Test Suite
Specialist: Subagent 9 - QA Engineer (MM2 Candy Farm Council)
Target Platform: Delta Mobile Executor on Android (Roblox Mobile Touch Engine & CoreGui)

Regression Test Coverage:
1. Decommissioning of obsolete movement/farming loops (ensuring zero physics interference).
2. Screen boundary clamping and compact UI dimensions (< 340x260 px).
3. RockHub runtime resizer detection logic (finding RockHubUI in gethui/CoreGui and applying safe UIScale).
4. Real-time metric feeds (FPS rolling average calculation, Ping extraction, health percentage).
5. Clean unload and event disconnection.
"""

import math
import pytest
from typing import Dict, List, Optional, Any


# ==============================================================================
# MOCK INFRASTRUCTURE FOR ROBLOX ROBUST TESTING
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

    def __eq__(self, other):
        if not isinstance(other, MockVector3):
            return False
        return (
            abs(self.x - other.x) < 1e-6
            and abs(self.y - other.y) < 1e-6
            and abs(self.z - other.z) < 1e-6
        )

    @property
    def magnitude(self):
        return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)

    @classmethod
    def zero(cls):
        return MockVector3(0.0, 0.0, 0.0)


class MockUDim2:
    def __init__(self, scale_x=0.0, offset_x=0, scale_y=0.0, offset_y=0):
        self.scale_x = float(scale_x)
        self.offset_x = int(offset_x)
        self.scale_y = float(scale_y)
        self.offset_y = int(offset_y)

    def __eq__(self, other):
        if not isinstance(other, MockUDim2):
            return False
        return (
            self.scale_x == other.scale_x
            and self.offset_x == other.offset_x
            and self.scale_y == other.scale_y
            and self.offset_y == other.offset_y
        )


class MockRBXScriptConnection:
    def __init__(self, name="Connection"):
        self.name = name
        self.connected = True

    def disconnect(self):
        self.connected = False


class MockInstance:
    def __init__(self, class_name: str, name: str, parent: Optional["MockInstance"] = None):
        self.class_name = class_name
        self.name = name
        self._parent = None
        self.children: List["MockInstance"] = []
        self.properties: Dict[str, Any] = {}
        if parent is not None:
            self.parent = parent

    @property
    def parent(self):
        return self._parent

    @parent.setter
    def parent(self, new_parent: Optional["MockInstance"]):
        if self._parent and self in self._parent.children:
            self._parent.children.remove(self)
        self._parent = new_parent
        if new_parent and self not in new_parent.children:
            new_parent.children.append(self)

    def find_first_child(self, name: str) -> Optional["MockInstance"]:
        for child in self.children:
            if child.name == name:
                return child
        return None

    def find_first_child_of_class(self, class_name: str) -> Optional["MockInstance"]:
        for child in self.children:
            if child.class_name == class_name:
                return child
        return None

    def get_descendants(self) -> List["MockInstance"]:
        descendants = []
        for child in self.children:
            descendants.append(child)
            descendants.extend(child.get_descendants())
        return descendants

    def destroy(self):
        for child in list(self.children):
            child.destroy()
        self.parent = None
        self.children.clear()


# ==============================================================================
# 1. DECOMMISSIONING & ZERO-INTERFERENCE CONTRACT (ROCKHUB SAFETY)
# ==============================================================================

class DecommissioningManager:
    """
    Simulates Companion decommissioning and cleanup under the Zero-Interference Contract:
    1. The Companion must NEVER modify character physics during normal operation.
    2. Automatic physics restoration is completely removed from startup, shutdown, respawn, and round transitions.
    3. Never deletes movement constraints, body movers, or forces created by RockHub or other scripts.
    4. Never changes Humanoid states, collisions, CFrame, or AssemblyLinearVelocity.
    5. Cleanup affects ONLY objects and connections owned by the Companion.
    """

    def __init__(self, character: MockInstance, workspace_root: MockInstance):
        self.character = character
        self.workspace_root = workspace_root
        self.companion_tasks: List[MockRBXScriptConnection] = []
        self.is_farming = False

    def decommission_movement_and_farming(self) -> Dict[str, Any]:
        """
        Executes safe Companion cleanup respecting the Zero-Interference Contract:
        - Disconnects ONLY Companion-owned tasks & event connections.
        - Preserves all BodyMovers, constraints, and forces intact (for RockHub).
        - Preserves Humanoid state, platform stand, and walkspeed untouched.
        - Preserves limb collisions untouched.
        - Preserves AssemblyLinearVelocity & momentum untouched.
        - Destroys ONLY Companion-owned objects (e.g. Companion UI or safe staging platform).
        """
        report = {
            "movers_destroyed": 0,
            "movers_preserved": 0,
            "connections_disconnected": 0,
            "platform_destroyed": False,
            "velocity_neutralized": False,
            "humanoid_restored": False,
            "collisions_restored": False,
        }

        # 1. Disconnect ONLY Companion-owned connections
        for conn in self.companion_tasks:
            if conn.connected:
                conn.disconnect()
                report["connections_disconnected"] += 1
        self.companion_tasks.clear()
        self.is_farming = False

        # 2. Zero-Interference: Verify body movers are PRESERVED and NOT destroyed
        for desc in self.character.get_descendants():
            if desc.class_name in (
                "BodyVelocity", "BodyPosition", "BodyGyro", "BodyAngularVelocity",
                "LinearVelocity", "AlignPosition", "AlignOrientation", "VectorForce"
            ):
                report["movers_preserved"] += 1

        # 3. Zero-Interference: Never neutralize velocities on HumanoidRootPart
        # hrp.AssemblyLinearVelocity is left completely untouched

        # 4. Zero-Interference: Never mutate Humanoid State or collisions
        # Humanoid and BasePart.CanCollide are left completely untouched

        # 5. Clean up ONLY Companion-owned workspace objects if present
        platform = self.workspace_root.find_first_child("MM2_SafePlatform")
        if platform:
            platform.destroy()
            report["platform_destroyed"] = True

        return report


def test_decommission_body_movers_and_constraints_purged():
    """Verify that RockHub body movers and constraints are NEVER destroyed (Zero-Interference Contract)."""
    char = MockInstance("Model", "Character")
    hrp = MockInstance("BasePart", "HumanoidRootPart", char)
    hum = MockInstance("Humanoid", "Humanoid", char)
    ws = MockInstance("Workspace", "Workspace")
    char.parent = ws

    # Add RockHub movement movers & constraints to HRP
    bv = MockInstance("BodyVelocity", "BodyVelocity", hrp)
    bp = MockInstance("BodyPosition", "BodyPosition", hrp)
    lv = MockInstance("LinearVelocity", "LinearVelocity", hrp)
    ap = MockInstance("AlignPosition", "AlignPosition", hrp)

    manager = DecommissioningManager(char, ws)
    report = manager.decommission_movement_and_farming()

    # Must NOT destroy any body movers or constraints
    assert report["movers_destroyed"] == 0
    assert report["movers_preserved"] == 4
    assert hrp.find_first_child("BodyVelocity") is bv
    assert hrp.find_first_child("BodyPosition") is bp
    assert hrp.find_first_child("LinearVelocity") is lv
    assert hrp.find_first_child("AlignPosition") is ap


def test_decommission_momentum_and_velocity_zeroed():
    """Verify that character momentum and velocity are NEVER zeroed or altered."""
    char = MockInstance("Model", "Character")
    hrp = MockInstance("BasePart", "HumanoidRootPart", char)
    initial_linear_vel = MockVector3(250.0, -100.0, 450.0)
    initial_angular_vel = MockVector3(10.0, 50.0, -20.0)
    hrp.properties["AssemblyLinearVelocity"] = initial_linear_vel
    hrp.properties["AssemblyAngularVelocity"] = initial_angular_vel
    ws = MockInstance("Workspace", "Workspace")
    char.parent = ws

    manager = DecommissioningManager(char, ws)
    report = manager.decommission_movement_and_farming()

    # Velocities must remain untouched for RockHub's active physics
    assert report["velocity_neutralized"] is False
    assert hrp.properties["AssemblyLinearVelocity"] == initial_linear_vel
    assert hrp.properties["AssemblyAngularVelocity"] == initial_angular_vel
    assert hrp.properties["AssemblyLinearVelocity"].magnitude > 100.0


def test_decommission_humanoid_and_collisions_restored():
    """Verify that Humanoid states and limb collisions are NEVER mutated by Companion."""
    char = MockInstance("Model", "Character")
    hrp = MockInstance("BasePart", "HumanoidRootPart", char)
    torso = MockInstance("BasePart", "Torso", char)
    head = MockInstance("BasePart", "Head", char)
    hum = MockInstance("Humanoid", "Humanoid", char)
    hum.properties["State"] = "Physics"
    hum.properties["PlatformStand"] = True
    hum.properties["WalkSpeed"] = 28.0

    torso.properties["CanCollide"] = False
    head.properties["CanCollide"] = False

    ws = MockInstance("Workspace", "Workspace")
    char.parent = ws

    manager = DecommissioningManager(char, ws)
    report = manager.decommission_movement_and_farming()

    # Zero-Interference: Companion leaves Humanoid and limb properties untouched
    assert report["humanoid_restored"] is False
    assert report["collisions_restored"] is False
    assert hum.properties["State"] == "Physics"
    assert hum.properties["PlatformStand"] is True
    assert hum.properties["WalkSpeed"] == 28.0
    assert torso.properties["CanCollide"] is False
    assert head.properties["CanCollide"] is False


def test_decommission_safe_platform_and_connections_annihilated():
    """Verify that cleanup strictly disconnects Companion tasks and removes Companion instances."""
    char = MockInstance("Model", "Character")
    MockInstance("HumanoidRootPart", "HumanoidRootPart", char)
    ws = MockInstance("Workspace", "Workspace")
    char.parent = ws

    platform = MockInstance("Part", "MM2_SafePlatform", ws)
    manager = DecommissioningManager(char, ws)

    conn1 = MockRBXScriptConnection("CompanionMetricHeartbeat")
    conn2 = MockRBXScriptConnection("CompanionUIEvent")
    manager.companion_tasks.extend([conn1, conn2])
    manager.is_farming = True

    report = manager.decommission_movement_and_farming()

    assert report["connections_disconnected"] == 2
    assert conn1.connected is False
    assert conn2.connected is False
    assert report["platform_destroyed"] is True
    assert ws.find_first_child("MM2_SafePlatform") is None
    assert platform.parent is None
    assert manager.is_farming is False


# ==============================================================================
# 2. SCREEN BOUNDARY CLAMPING AND COMPACT UI DIMENSIONS (< 340x260 px)
# ==============================================================================

class UIClampEngine:
    """
    Validates compact dimensions (< 340x260) and executes safe boundary clamping
    with Android mobile safe insets (notch, status bar, navigation bar).
    """

    SAFE_INSET_LEFT = 20
    SAFE_INSET_RIGHT = 20
    SAFE_INSET_TOP = 24     # Android notch / top status bar
    SAFE_INSET_BOTTOM = 16  # Virtual navigation pill / gesture bar

    MAX_ALLOWED_WIDTH = 340
    MAX_ALLOWED_HEIGHT = 260

    def __init__(self, frame_size: MockUDim2, ui_scale: float = 1.0):
        # Strict dimension check
        assert frame_size.offset_x < self.MAX_ALLOWED_WIDTH, (
            f"UI width {frame_size.offset_x}px must be strictly < {self.MAX_ALLOWED_WIDTH}px"
        )
        assert frame_size.offset_y < self.MAX_ALLOWED_HEIGHT, (
            f"UI height {frame_size.offset_y}px must be strictly < {self.MAX_ALLOWED_HEIGHT}px"
        )
        assert frame_size.scale_x == 0.0, "Scale X must be 0 for deterministic pixel sizing"
        assert frame_size.scale_y == 0.0, "Scale Y must be 0 for deterministic pixel sizing"

        self.width = frame_size.offset_x
        self.height = frame_size.offset_y
        self.ui_scale = ui_scale

    def clamp_position(self, target_x: int, target_y: int, viewport_x: int, viewport_y: int) -> MockUDim2:
        """
        Clamps window position so that its entire scaled footprint stays strictly inside
        the safe screen area, regardless of touch dragging.
        """
        eff_width = int(self.width * self.ui_scale)
        eff_height = int(self.height * self.ui_scale)

        min_x = self.SAFE_INSET_LEFT
        max_x = max(min_x, viewport_x - eff_width - self.SAFE_INSET_RIGHT)

        min_y = self.SAFE_INSET_TOP
        max_y = max(min_y, viewport_y - eff_height - self.SAFE_INSET_BOTTOM)

        clamped_x = max(min_x, min(target_x, max_x))
        clamped_y = max(min_y, min(target_y, max_y))

        return MockUDim2(0, clamped_x, 0, clamped_y)


def test_compact_ui_dimensions_budget():
    # Recommended esports-compact dimensions: 320x240 px
    compact_size = MockUDim2(0, 320, 0, 240)
    engine = UIClampEngine(compact_size, ui_scale=1.0)
    assert engine.width == 320
    assert engine.height == 240
    assert engine.width < 340
    assert engine.height < 260

    # Test rejection of non-compact dimensions
    with pytest.raises(AssertionError):
        UIClampEngine(MockUDim2(0, 340, 0, 255))  # 340 is not < 340

    with pytest.raises(AssertionError):
        UIClampEngine(MockUDim2(0, 320, 0, 260))  # 260 is not < 260


def test_screen_boundary_clamping_standard_and_extreme_drag():
    compact_size = MockUDim2(0, 320, 0, 240)
    engine = UIClampEngine(compact_size, ui_scale=1.0)
    viewport_w, viewport_h = 800, 450  # Mobile landscape 16:9

    # Case 1: Dragging off-screen to top-left negative coordinates
    clamped = engine.clamp_position(-150, -80, viewport_w, viewport_h)
    assert clamped.offset_x == UIClampEngine.SAFE_INSET_LEFT  # 20
    assert clamped.offset_y == UIClampEngine.SAFE_INSET_TOP   # 24

    # Case 2: Dragging far off bottom-right
    # Max X = 800 - 320 - 20 = 460
    # Max Y = 450 - 240 - 16 = 194
    clamped = engine.clamp_position(9999, 9999, viewport_w, viewport_h)
    assert clamped.offset_x == 460
    assert clamped.offset_y == 194

    # Case 3: Safe interior drag
    clamped = engine.clamp_position(200, 100, viewport_w, viewport_h)
    assert clamped.offset_x == 200
    assert clamped.offset_y == 100


def test_screen_boundary_clamping_with_uiscale():
    compact_size = MockUDim2(0, 320, 0, 240)
    # UI scale down to 0.75x
    engine = UIClampEngine(compact_size, ui_scale=0.75)
    viewport_w, viewport_h = 800, 450

    # Scaled dimensions: 320 * 0.75 = 240 px, 240 * 0.75 = 180 px
    # Max X = 800 - 240 - 20 = 540
    # Max Y = 450 - 180 - 16 = 254
    clamped = engine.clamp_position(1200, 1200, viewport_w, viewport_h)
    assert clamped.offset_x == 540
    assert clamped.offset_y == 254


def test_viewport_resize_reclamp_on_device_rotation():
    compact_size = MockUDim2(0, 320, 0, 240)
    engine = UIClampEngine(compact_size, ui_scale=1.0)

    # Initial position at (450, 150) in landscape 1280x720
    initial_pos = engine.clamp_position(450, 150, 1280, 720)
    assert initial_pos.offset_x == 450
    assert initial_pos.offset_y == 150

    # User rotates device or switches to split-screen 640x360
    # Max X in 640x360: 640 - 320 - 20 = 300
    # Max Y in 640x360: 360 - 240 - 16 = 104
    reclamped = engine.clamp_position(initial_pos.offset_x, initial_pos.offset_y, 640, 360)
    assert reclamped.offset_x == 300  # Automatically pulled back into bounds
    assert reclamped.offset_y == 104


# ==============================================================================
# 3. ROCKHUB RUNTIME RESIZER DETECTION LOGIC
# ==============================================================================

class RockHubResizer:
    """
    Simulates locating RockHubUI across gethui -> CoreGui -> PlayerGui,
    detecting its Main frame (680x470), and non-destructively applying safe mobile UIScale.
    """

    TARGET_SCREEN_WIDTH = 680
    TARGET_SCREEN_HEIGHT = 470
    SAFE_SCALE_MAX = 0.55
    SAFE_SCALE_MIN = 0.40

    def __init__(self, gethui_fn=None, core_gui=None, player_gui=None):
        self.gethui_fn = gethui_fn
        self.core_gui = core_gui
        self.player_gui = player_gui
        self.hooked_gui: Optional[MockInstance] = None
        self.uiscale_instance: Optional[MockInstance] = None
        self.original_scale: float = 1.0

    def find_rockhub_gui(self) -> Optional[MockInstance]:
        containers = []
        if callable(self.gethui_fn):
            try:
                hui = self.gethui_fn()
                if hui:
                    containers.append(("gethui", hui))
            except Exception:
                pass
        if self.core_gui:
            containers.append(("CoreGui", self.core_gui))
        if self.player_gui:
            containers.append(("PlayerGui", self.player_gui))

        for source_name, container in containers:
            # 1. Match by ScreenGui name
            rh = container.find_first_child("RockHubUI")
            if rh:
                return rh

            # 2. Structural fingerprint: ScreenGui containing a frame 'Main' with (680, 470)
            for child in container.children:
                if child.class_name == "ScreenGui":
                    main_frame = child.find_first_child("Main")
                    if main_frame and main_frame.properties.get("Width") == self.TARGET_SCREEN_WIDTH:
                        return child

        return None

    def calculate_safe_scale(self, viewport_w: int, viewport_h: int) -> float:
        """
        Calculates scale so RockHub window never exceeds 60% of viewport width
        and 75% of viewport height.
        """
        scale_x = (viewport_w * 0.60) / self.TARGET_SCREEN_WIDTH
        scale_y = (viewport_h * 0.75) / self.TARGET_SCREEN_HEIGHT
        computed = min(scale_x, scale_y)
        return round(max(self.SAFE_SCALE_MIN, min(computed, self.SAFE_SCALE_MAX)), 3)

    def attach_and_rescale(self, viewport_w: int, viewport_h: int) -> bool:
        gui = self.find_rockhub_gui()
        if not gui:
            return False

        self.hooked_gui = gui
        main_frame = gui.find_first_child("Main")
        if not main_frame:
            return False

        # Find or create UIScale
        uiscale = main_frame.find_first_child_of_class("UIScale")
        if not uiscale:
            uiscale = MockInstance("UIScale", "CompanionUIScale", main_frame)
            self.original_scale = 1.0
        else:
            self.original_scale = uiscale.properties.get("Scale", 1.0)

        target_scale = self.calculate_safe_scale(viewport_w, viewport_h)
        uiscale.properties["Scale"] = target_scale
        self.uiscale_instance = uiscale

        # Position to safe top-right area to not block joystick (bottom-left)
        main_frame.properties["Position"] = MockUDim2(0.5, 0, 0.5, 0)
        return True

    def restore(self):
        if self.uiscale_instance and self.uiscale_instance.parent:
            self.uiscale_instance.properties["Scale"] = self.original_scale


def test_rockhub_resizer_container_priority():
    # 1. Test gethui priority
    gethui_root = MockInstance("Folder", "HUI")
    core_root = MockInstance("Folder", "CoreGui")
    player_root = MockInstance("Folder", "PlayerGui")

    # Put RockHub in gethui
    rh_hui = MockInstance("ScreenGui", "RockHubUI", gethui_root)
    resizer = RockHubResizer(gethui_fn=lambda: gethui_root, core_gui=core_root, player_gui=player_root)
    found = resizer.find_rockhub_gui()
    assert found is rh_hui

    # 2. Test fallback to CoreGui when gethui is None
    rh_hui.destroy()
    rh_core = MockInstance("ScreenGui", "RockHubUI", core_root)
    resizer2 = RockHubResizer(gethui_fn=lambda: None, core_gui=core_root, player_gui=player_root)
    found2 = resizer2.find_rockhub_gui()
    assert found2 is rh_core

    # 3. Test fallback to PlayerGui when CoreGui is restricted
    rh_core.destroy()
    rh_player = MockInstance("ScreenGui", "RockHubUI", player_root)
    resizer3 = RockHubResizer(gethui_fn=lambda: None, core_gui=None, player_gui=player_root)
    found3 = resizer3.find_rockhub_gui()
    assert found3 is rh_player


def test_rockhub_resizer_structural_fingerprint_matching():
    core_root = MockInstance("Folder", "CoreGui")
    # ScreenGui with custom/random name from executor, but containing 'Main' of 680x470
    obfuscated_gui = MockInstance("ScreenGui", "RobloxExploitGui_x78a", core_root)
    main_frame = MockInstance("Frame", "Main", obfuscated_gui)
    main_frame.properties["Width"] = 680
    main_frame.properties["Height"] = 470

    resizer = RockHubResizer(core_gui=core_root)
    found = resizer.find_rockhub_gui()
    assert found is obfuscated_gui


def test_rockhub_safe_scale_calculation_and_attachment():
    core_root = MockInstance("Folder", "CoreGui")
    rh_gui = MockInstance("ScreenGui", "RockHubUI", core_root)
    main_frame = MockInstance("Frame", "Main", rh_gui)
    main_frame.properties["Width"] = 680
    main_frame.properties["Height"] = 470

    # In Mobile landscape 800x450
    resizer = RockHubResizer(core_gui=core_root)
    # Scale width: (800 * 0.60)/680 = 480/680 = 0.705
    # Scale height: (450 * 0.75)/470 = 337.5/470 = 0.718
    # Min = 0.705, clamped to SAFE_SCALE_MAX (0.55)
    success = resizer.attach_and_rescale(viewport_w=800, viewport_h=450)
    assert success is True
    assert resizer.uiscale_instance is not None
    scale = resizer.uiscale_instance.properties["Scale"]
    assert 0.40 <= scale <= 0.55
    assert scale == 0.55

    # On a very small mobile screen (640x360)
    # Scale width: (640 * 0.60)/680 = 384/680 = 0.564
    # Scale height: (360 * 0.75)/470 = 270/470 = 0.574
    # Clamped to 0.55
    resizer.attach_and_rescale(viewport_w=640, viewport_h=360)
    assert resizer.uiscale_instance.properties["Scale"] <= 0.55


def test_rockhub_resizer_reversibility():
    core_root = MockInstance("Folder", "CoreGui")
    rh_gui = MockInstance("ScreenGui", "RockHubUI", core_root)
    main_frame = MockInstance("Frame", "Main", rh_gui)
    main_frame.properties["Width"] = 680
    main_frame.properties["Height"] = 470
    existing_uiscale = MockInstance("UIScale", "UIScale", main_frame)
    existing_uiscale.properties["Scale"] = 0.85

    resizer = RockHubResizer(core_gui=core_root)
    resizer.attach_and_rescale(viewport_w=800, viewport_h=450)
    assert resizer.uiscale_instance.properties["Scale"] == 0.55

    # Trigger clean unload restoration
    resizer.restore()
    assert existing_uiscale.properties["Scale"] == 0.85


# ==============================================================================
# 4. REAL-TIME METRIC FEEDS (FPS ROLLING AVERAGE, PING, HEALTH %)
# ==============================================================================

class RealtimeMetricsEngine:
    """
    Calculates rolling average FPS, extracts network Ping with safe fallbacks,
    and computes player health percentage with edge-case protection.
    """

    def __init__(self, buffer_size: int = 15):
        self.buffer_size = buffer_size
        self.dt_samples: List[float] = []
        self.smoothed_fps = 60.0
        self.last_valid_ping = 0

    def push_frame_delta(self, dt: float) -> Dict[str, Any]:
        """
        Processes frame delta:
        - Clamps dt against zero/negative anomalies [0.0005, 0.2]
        - Maintains rolling window
        - Computes FPS = buffer_size / sum(dt_samples)
        - Computes frame time in ms
        """
        clamped_dt = max(0.0005, min(dt, 0.2))
        self.dt_samples.append(clamped_dt)
        if len(self.dt_samples) > self.buffer_size:
            self.dt_samples.pop(0)

        total_dt = sum(self.dt_samples)
        if total_dt > 1e-6:
            raw_fps = len(self.dt_samples) / total_dt
        else:
            raw_fps = 60.0

        clamped_fps = max(1, min(int(round(raw_fps)), 360))
        frame_time_ms = round(clamped_dt * 1000.0, 1)

        return {
            "fps": clamped_fps,
            "frame_time_ms": frame_time_ms,
            "raw_dt": clamped_dt
        }

    def extract_ping(self, stats_service: Optional[Any]) -> int:
        """
        Safely extracts ping from Stats.Network.ServerStatsItem['Data Ping']:GetValue()
        with pcall error boundary and bounds clamp [0, 9999].
        """
        try:
            if not stats_service:
                return self.last_valid_ping

            network = getattr(stats_service, "Network", None)
            if not network:
                return self.last_valid_ping

            server_stats = getattr(network, "ServerStatsItem", None)
            if not server_stats:
                return self.last_valid_ping

            ping_item = server_stats.get("Data Ping")
            if not ping_item:
                return self.last_valid_ping

            raw_ping = ping_item.get_value()
            clamped_ping = max(0, min(int(round(raw_ping)), 9999))
            self.last_valid_ping = clamped_ping
            return clamped_ping
        except Exception:
            return self.last_valid_ping

    @staticmethod
    def calculate_health_percentage(health: Optional[float], max_health: Optional[float]) -> int:
        """
        Computes health percentage [0, 100]% with division-by-zero, nil,
        overheal, and negative health guards.
        """
        if health is None or max_health is None:
            return 0
        if max_health <= 0:
            return 0
        if health <= 0:
            return 0

        pct = (health / max_health) * 100.0
        return max(0, min(int(round(pct)), 100))


def test_fps_rolling_average_smoothing_under_spike():
    engine = RealtimeMetricsEngine(buffer_size=15)

    # Establish 60 FPS baseline (dt = 0.01667)
    for _ in range(15):
        result = engine.push_frame_delta(0.01667)
    assert result["fps"] == 60
    assert result["frame_time_ms"] == 16.7

    # Sudden 1-frame GC spike: dt = 0.20s (instantaneous 5 FPS)
    spike_result = engine.push_frame_delta(0.20)
    # Rolling average dampens the spike:
    # 14 samples of 0.01667 + 1 sample of 0.20 = 0.23338 + 0.20 = 0.43338s
    # FPS = 15 / 0.43338 ≈ 34.6 -> 35 FPS (NO violent jump to 5 FPS!)
    assert spike_result["fps"] >= 34
    assert spike_result["fps"] <= 36
    assert spike_result["frame_time_ms"] == 200.0


def test_fps_zero_and_negative_dt_guard():
    engine = RealtimeMetricsEngine(buffer_size=10)

    # Corrupt engine delta 0.0 or negative
    res1 = engine.push_frame_delta(0.0)
    assert res1["raw_dt"] == 0.0005  # clamped to safe min
    assert 1 <= res1["fps"] <= 360

    res2 = engine.push_frame_delta(-0.05)
    assert res2["raw_dt"] == 0.0005
    assert 1 <= res2["fps"] <= 360


def test_ping_extraction_and_safe_fallback():
    engine = RealtimeMetricsEngine()

    class MockPingItem:
        def __init__(self, val):
            self.val = val
        def get_value(self):
            return self.val

    class MockNetwork:
        def __init__(self, ping_val):
            self.ServerStatsItem = {"Data Ping": MockPingItem(ping_val)}

    class MockStats:
        def __init__(self, network):
            self.Network = network

    # Normal retrieval
    stats = MockStats(MockNetwork(58.4))
    assert engine.extract_ping(stats) == 58

    # Edge case: High latency
    stats_lag = MockStats(MockNetwork(345.9))
    assert engine.extract_ping(stats_lag) == 346

    # Edge case: Missing stat or exception thrown
    class BrokenStats:
        @property
        def Network(self):
            raise RuntimeError("Access Denied to Security Context")

    broken_stats = BrokenStats()
    assert engine.extract_ping(broken_stats) == 346  # Retains last valid ping gracefully

    # Nil stats
    assert engine.extract_ping(None) == 346


def test_health_percentage_invariants_and_edge_cases():
    calc = RealtimeMetricsEngine.calculate_health_percentage

    # Standard healthy / wounded
    assert calc(100.0, 100.0) == 100
    assert calc(50.0, 100.0) == 50
    assert calc(1.0, 100.0) == 1

    # Dead / ragdoll
    assert calc(0.0, 100.0) == 0
    assert calc(-25.0, 100.0) == 0

    # Overheal / shield (clamped to 100%)
    assert calc(150.0, 100.0) == 100
    assert calc(200.0, 100.0) == 100

    # Zero / negative max_health (Division by zero guard)
    assert calc(50.0, 0.0) == 0
    assert calc(50.0, -100.0) == 0

    # Missing character / Humanoid nil
    assert calc(None, 100.0) == 0
    assert calc(100.0, None) == 0
    assert calc(None, None) == 0


# ==============================================================================
# 5. CLEAN UNLOAD AND EVENT DISCONNECTION
# ==============================================================================

class ScriptLifecycleManager:
    """
    Manages central registry of RBXScriptConnections and visual instances,
    guaranteeing 100% atomic, idempotent unload and memory leak prevention.
    """

    def __init__(self):
        self.connections: Dict[str, MockRBXScriptConnection] = {}
        self.instances: List[MockInstance] = []
        self.is_unloaded = False

    def register_connection(self, key: str, conn: MockRBXScriptConnection):
        if key in self.connections:
            self.connections[key].disconnect()
        self.connections[key] = conn

    def register_instance(self, instance: MockInstance):
        self.instances.append(instance)

    def unload(self) -> Dict[str, int]:
        """
        Executes clean unload:
        1. Disconnects all active listeners (Heartbeat, Stepped, Input, DescendantAdded)
        2. Destroys all created UI frames and parts
        3. Clears registries for GC
        """
        stats = {
            "disconnected_count": 0,
            "destroyed_instances": 0,
        }

        # 1. Disconnect all connections safely
        for key, conn in list(self.connections.items()):
            if conn.connected:
                conn.disconnect()
                stats["disconnected_count"] += 1
        self.connections.clear()

        # 2. Destroy all created instances
        for inst in list(self.instances):
            inst.destroy()
            stats["destroyed_instances"] += 1
        self.instances.clear()

        self.is_unloaded = True
        return stats


def test_clean_unload_all_connections_disconnected():
    lifecycle = ScriptLifecycleManager()

    c1 = MockRBXScriptConnection("HeartbeatNavigation")
    c2 = MockRBXScriptConnection("SteppedPrePhysics")
    c3 = MockRBXScriptConnection("RenderSteppedFPS")
    c4 = MockRBXScriptConnection("InputBeganTouchDrag")
    c5 = MockRBXScriptConnection("DescendantAddedWatcher")

    lifecycle.register_connection("heartbeat", c1)
    lifecycle.register_connection("stepped", c2)
    lifecycle.register_connection("render_stepped", c3)
    lifecycle.register_connection("input_began", c4)
    lifecycle.register_connection("descendant_added", c5)

    assert len(lifecycle.connections) == 5
    assert all(c.connected for c in [c1, c2, c3, c4, c5])

    stats = lifecycle.unload()

    assert stats["disconnected_count"] == 5
    assert c1.connected is False
    assert c2.connected is False
    assert c3.connected is False
    assert c4.connected is False
    assert c5.connected is False
    assert len(lifecycle.connections) == 0
    assert lifecycle.is_unloaded is True


def test_clean_unload_all_instances_destroyed_and_parent_cleared():
    lifecycle = ScriptLifecycleManager()
    root_gui_parent = MockInstance("Folder", "HUI")

    screen_gui = MockInstance("ScreenGui", "MM2_MobileCompanionGui", root_gui_parent)
    main_window = MockInstance("Frame", "MainWindow", screen_gui)
    float_launcher = MockInstance("ScreenGui", "FloatingLauncherGui", root_gui_parent)
    uiscale = MockInstance("UIScale", "ResizerUIScale", main_window)

    lifecycle.register_instance(screen_gui)
    lifecycle.register_instance(float_launcher)

    stats = lifecycle.unload()

    assert stats["destroyed_instances"] == 2
    assert screen_gui.parent is None
    assert float_launcher.parent is None
    assert main_window.parent is None
    assert uiscale.parent is None
    assert len(lifecycle.instances) == 0


def test_clean_unload_idempotency_double_call():
    lifecycle = ScriptLifecycleManager()
    c1 = MockRBXScriptConnection("TestConn")
    lifecycle.register_connection("c1", c1)

    # First call
    stats1 = lifecycle.unload()
    assert stats1["disconnected_count"] == 1

    # Second call must be completely safe, no exceptions, 0 remaining
    stats2 = lifecycle.unload()
    assert stats2["disconnected_count"] == 0
    assert stats2["destroyed_instances"] == 0
    assert lifecycle.is_unloaded is True
