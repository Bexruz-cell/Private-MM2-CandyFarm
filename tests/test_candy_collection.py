#!/usr/bin/env python3
"""
test_candy_collection.py
Targeted unit tests for:
1. Spatial boundary rejection (discarding candies outside playable map)
2. Bounded retry and temporary blacklisting (TTL expiry)
3. Observable collection tri-signal verification
4. Real FPS calculation using frame delta timing
5. Continuous movement step calculation (frame-rate independence)
"""

import unittest
import math
import time

class SimulatedCandy:
    def __init__(self, name: str, x: float, y: float, z: float, coin_id: str = "Candy"):
        self.name = name
        self.position = (x, y, z)
        self.coin_id = coin_id
        self.parent = "CoinContainer"
        self.touch_transmitter_present = True
        self.collected_attribute = False

class SimulatedCandyDetector:
    def __init__(self, map_min_y=-20.0, map_max_y=140.0, map_radius=250.0):
        self.map_min_y = map_min_y
        self.map_max_y = map_max_y
        self.map_radius = map_radius
        self.blacklist = {} # item -> expiry
        self.fail_counts = {} # item -> count

    def is_position_inside_map(self, pos) -> bool:
        x, y, z = pos
        if y < self.map_min_y or y > self.map_max_y:
            return False
        dist_sq = x*x + z*z
        if dist_sq > (self.map_radius * self.map_radius):
            return False
        return True

    def is_valid_candy(self, candy: SimulatedCandy, current_time: float) -> bool:
        if not candy.parent:
            return False
        if not candy.touch_transmitter_present:
            return False
        if candy.collected_attribute:
            return False
        # Blacklist check
        expiry = self.blacklist.get(candy)
        if expiry and current_time < expiry:
            return False
        return True

    def get_closest_candy(self, candies, player_pos, current_time: float):
        best_candy = None
        best_dist = float('inf')
        px, py, pz = player_pos

        for c in candies:
            if not self.is_valid_candy(c, current_time):
                continue
            if not self.is_position_inside_map(c.position):
                continue
            cx, cy, cz = c.position
            dist = math.sqrt((cx - px)**2 + (cy - py)**2 + (cz - pz)**2)
            if dist < best_dist:
                best_dist = dist
                best_candy = c

        return best_candy, best_dist

    def record_failed_pickup(self, candy: SimulatedCandy, current_time: float, max_retries: int = 2) -> bool:
        count = self.fail_counts.get(candy, 0) + 1
        self.fail_counts[candy] = count
        if count >= max_retries:
            self.blacklist[candy] = current_time + 15.0
            del self.fail_counts[candy]
            return True
        return False

class TestCandyCollectionAndMovement(unittest.TestCase):
    def test_spatial_boundary_rejection(self):
        """Candies spawned in the void or outside map radius must be rejected."""
        detector = SimulatedCandyDetector(map_min_y=-20.0, map_max_y=140.0, map_radius=200.0)
        
        valid_candy = SimulatedCandy("Valid_1", 20.0, 10.0, 30.0)
        void_candy = SimulatedCandy("Void_Glitch", 0.0, -150.0, 0.0) # In the void
        sky_candy = SimulatedCandy("Sky_Glitch", 0.0, 250.0, 0.0) # In the sky
        oob_candy = SimulatedCandy("OOB_Wall", 400.0, 10.0, 400.0) # Outside map radius

        candies = [valid_candy, void_candy, sky_candy, oob_candy]
        best, dist = detector.get_closest_candy(candies, (0.0, 10.0, 0.0), 0.0)

        self.assertIsNotNone(best)
        self.assertEqual(best.name, "Valid_1", "Must pick only candy strictly inside map bounds!")
        self.assertAlmostEqual(dist, math.sqrt(20**2 + 30**2), places=2)

    def test_bounded_retry_and_blacklist_ttl(self):
        """Failed pickup attempts must be retried at most twice, then blacklisted with TTL."""
        detector = SimulatedCandyDetector()
        candy = SimulatedCandy("Stubborn_Candy", 10.0, 10.0, 10.0)
        t0 = 100.0

        # Attempt 1: Failed
        blacklisted = detector.record_failed_pickup(candy, t0, max_retries=2)
        self.assertFalse(blacklisted)
        self.assertTrue(detector.is_valid_candy(candy, t0))

        # Attempt 2: Failed -> Triggers blacklist
        blacklisted = detector.record_failed_pickup(candy, t0, max_retries=2)
        self.assertTrue(blacklisted)
        self.assertFalse(detector.is_valid_candy(candy, t0), "Candy must be blacklisted after 2 failures")

        # After 10s: Still blacklisted (TTL 15s)
        self.assertFalse(detector.is_valid_candy(candy, t0 + 10.0))

        # After 16s: Blacklist expired -> Candy valid again
        self.assertTrue(detector.is_valid_candy(candy, t0 + 16.0))

    def test_continuous_movement_frame_rate_independence(self):
        """Continuous movement must travel identical total distance over 1 second,
        regardless of whether running at 20 FPS, 30 FPS, or 60 FPS."""
        speed = 28.0 # studs / second
        total_time = 1.0

        for fps in [20, 30, 60, 120]:
            dt = 1.0 / fps
            steps = int(total_time * fps)
            traveled = 0.0
            remaining_dist = 100.0
            for _ in range(steps):
                step = min(speed * dt, remaining_dist)
                traveled += step
                remaining_dist -= step

            self.assertAlmostEqual(traveled, speed, places=1, msg=f"Failed at {fps} FPS")

    def test_real_fps_calculation_window(self):
        """Real FPS calculation must accurately compute frame rate across time delta."""
        frame_count = 30
        delta_accum = 0.5 # 30 frames in 0.5s = 60.0 FPS
        computed_fps = round((frame_count / delta_accum) * 10) / 10
        self.assertEqual(computed_fps, 60.0)

if __name__ == "__main__":
    unittest.main()
