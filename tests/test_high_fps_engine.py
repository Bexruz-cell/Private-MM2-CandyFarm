"""
Unit tests for MM2 High FPS Engine & Performance Telemetry
Role: Subagent 5: Performance Engineer
"""

import math
import pytest


class RingBufferFPSCalculator:
    def __init__(self, window_size=16, min_dt=0.0005, max_dt=0.2):
        self.window_size = window_size
        self.min_dt = min_dt
        self.max_dt = max_dt
        self.delta_buffer = [1.0 / 60.0] * window_size
        self.buffer_index = 0
        self.buffer_count = 0
        self.delta_sum = 0.0

    def step(self, dt: float):
        clamped_dt = max(self.min_dt, min(dt, self.max_dt))
        if self.buffer_count < self.window_size:
            self.buffer_count += 1
            self.delta_sum += clamped_dt
            self.delta_buffer[self.buffer_index] = clamped_dt
        else:
            self.delta_sum = self.delta_sum - self.delta_buffer[self.buffer_index] + clamped_dt
            self.delta_buffer[self.buffer_index] = clamped_dt

        self.buffer_index = (self.buffer_index + 1) % self.window_size

        avg_dt = self.delta_sum / self.buffer_count
        rolling_fps = 1.0 / avg_dt
        instant_ms = round(clamped_dt * 1000, 1)
        avg_ms = round(avg_dt * 1000, 1)
        clamped_fps = max(1, min(360, round(rolling_fps)))

        return clamped_fps, instant_ms, avg_ms


def test_fps_rolling_average_calculation():
    calc = RingBufferFPSCalculator(window_size=16)

    # 1. Steady 60 FPS
    dt_60 = 1.0 / 60.0
    for _ in range(30):
        fps, instant_ms, avg_ms = calc.step(dt_60)
    assert fps == 60
    assert abs(instant_ms - 16.7) <= 0.1
    assert abs(avg_ms - 16.7) <= 0.1

    # 2. Step to 30 FPS over 16 frames
    dt_30 = 1.0 / 30.0
    for _ in range(16):
        fps, instant_ms, avg_ms = calc.step(dt_30)
    assert fps == 30
    assert abs(instant_ms - 33.3) <= 0.1
    assert abs(avg_ms - 33.3) <= 0.1

    # 3. Step to 120 FPS
    dt_120 = 1.0 / 120.0
    for _ in range(16):
        fps, instant_ms, avg_ms = calc.step(dt_120)
    assert fps == 120
    assert abs(instant_ms - 8.3) <= 0.1
    assert abs(avg_ms - 8.3) <= 0.1


def test_fps_spike_clamping():
    calc = RingBufferFPSCalculator(window_size=16, min_dt=0.0005, max_dt=0.2)
    # Severe OS hitch (dt = 1.5s)
    fps, instant_ms, avg_ms = calc.step(1.5)
    # Clamped to max_dt = 0.2s -> 200.0 ms
    assert instant_ms == 200.0


class MockInstance:
    def __init__(self, name, class_name, parent=None):
        self.Name = name
        self.ClassName = class_name
        self.Parent = parent
        self.children = []
        if parent:
            parent.children.append(self)

    def IsA(self, class_name):
        return self.ClassName == class_name

    def FindFirstChildOfClass(self, class_name):
        for child in self.children:
            if child.ClassName == class_name:
                return child
        return None


def is_protected_instance(inst: MockInstance, workspace: MockInstance) -> bool:
    if not inst:
        return True
    name = inst.Name.lower()
    if "coin" in name or "candy" in name or "gun" in name:
        return True
    if inst.FindFirstChildOfClass("TouchTransmitter"):
        return True
    curr = inst.Parent
    while curr and curr != workspace:
        p_name = curr.Name.lower()
        if "coin" in p_name or "candy" in p_name or "gun" in p_name:
            return True
        if curr.Name in ("CoinContainer", "Coin_Server", "Coins"):
            return True
        if curr.FindFirstChildOfClass("Humanoid"):
            return True
        curr = curr.Parent
    return False


def test_coin_candy_model_protection():
    ws = MockInstance("Workspace", "Workspace")
    map_model = MockInstance("Normal", "Model", parent=ws)
    coin_container = MockInstance("CoinContainer", "Folder", parent=map_model)

    # 1. Candy model inside container
    candy_model = MockInstance("CandyDrop", "Model", parent=coin_container)
    candy_part = MockInstance("CandyPart", "Part", parent=candy_model)
    candy_sparkle = MockInstance("Sparkles", "Sparkles", parent=candy_part)
    assert is_protected_instance(candy_sparkle, ws) is True

    # 2. Coin part with TouchTransmitter
    coin_part = MockInstance("GoldCoin", "Part", parent=ws)
    MockInstance("TouchTransmitter", "TouchTransmitter", parent=coin_part)
    assert is_protected_instance(coin_part, ws) is True

    # 3. Unrelated environment light / particle
    street_lamp = MockInstance("StreetLamp", "Model", parent=map_model)
    lamp_light = MockInstance("PointLight", "Light", parent=street_lamp)
    assert is_protected_instance(lamp_light, ws) is False
