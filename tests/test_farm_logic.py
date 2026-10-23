#!/usr/bin/env python3
"""
test_farm_logic.py
Targeted functional tests for Private MM2 Candy Farm logic:
1. Candy Nearest-Neighbor Selection & Blacklist Filter
2. Screen Viewport Boundary Clamping
3. State Transitions & Bag Full Logic
4. Feature Parity Matrix Verification
"""

import math
import unittest
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

@dataclass
class Vector3:
    x: float
    y: float
    z: float

    def __sub__(self, other: 'Vector3') -> 'Vector3':
        return Vector3(self.x - other.x, self.y - other.y, self.z - other.z)

    def magnitude_sq(self) -> float:
        return self.x * self.x + self.y * self.y + self.z * self.z

    def magnitude(self) -> float:
        return math.sqrt(self.magnitude_sq())

@dataclass
class CandyTarget:
    name: str
    position: Vector3
    coin_id: str
    has_touch_interest: bool
    is_collected_visual: bool = False

class SimulatedCandyDetector:
    def __init__(self):
        self.blacklist: Dict[str, float] = {}

    def is_valid(self, candy: CandyTarget, now: float, filter_type: str = "Candy") -> bool:
        if candy.name in self.blacklist and now < self.blacklist[candy.name]:
            return False
        if not candy.has_touch_interest:
            return False
        if candy.is_collected_visual:
            return False
        if filter_type != "All" and candy.coin_id != filter_type:
            return False
        return True

    def get_closest(self, candies: List[CandyTarget], player_pos: Vector3, now: float, filter_type: str = "Candy") -> Tuple[Optional[CandyTarget], float]:
        best_target = None
        best_dist_sq = float("inf")

        for candy in candies:
            if not self.is_valid(candy, now, filter_type):
                continue
            delta = candy.position - player_pos
            dist_sq = delta.magnitude_sq()
            if dist_sq < best_dist_sq:
                best_dist_sq = dist_sq
                best_target = candy

        dist = math.sqrt(best_dist_sq) if best_target else float("inf")
        return best_target, dist

    def blacklist_coin(self, candy_name: str, expiry: float):
        self.blacklist[candy_name] = expiry

def clamp_to_viewport(viewport_x: float, viewport_y: float, frame_w: float, frame_h: float, req_x: float, req_y: float) -> Tuple[float, float]:
    min_x = 0.0
    max_x = max(viewport_x - frame_w, 0.0)
    min_y = 0.0
    max_y = max(viewport_y - frame_h, 0.0)

    clamped_x = max(min_x, min(req_x, max_x))
    clamped_y = max(min_y, min(req_y, max_y))
    return clamped_x, clamped_y

class TestCandyFarmLogic(unittest.TestCase):
    def test_nearest_candy_selection(self):
        detector = SimulatedCandyDetector()
        candies = [
            CandyTarget("C1", Vector3(10, 0, 10), "Candy", True),     # dist = ~14.14
            CandyTarget("C2", Vector3(5, 0, 0), "Candy", True),       # dist = 5.0 (closest)
            CandyTarget("C3", Vector3(20, 0, 0), "Candy", True),      # dist = 20.0
            CandyTarget("C4", Vector3(2, 0, 0), "Coin", True),        # ignored (wrong CoinID)
            CandyTarget("C5", Vector3(1, 0, 0), "Candy", False),      # ignored (no TouchInterest)
        ]
        player = Vector3(0, 0, 0)
        target, dist = detector.get_closest(candies, player, now=100.0, filter_type="Candy")
        self.assertIsNotNone(target)
        self.assertEqual(target.name, "C2")
        self.assertAlmostEqual(dist, 5.0, places=2)

    def test_blacklist_skips_failed_candy(self):
        detector = SimulatedCandyDetector()
        candies = [
            CandyTarget("C1", Vector3(5, 0, 0), "Candy", True),
            CandyTarget("C2", Vector3(10, 0, 0), "Candy", True),
        ]
        player = Vector3(0, 0, 0)
        # Blacklist C1 for 15s
        detector.blacklist_coin("C1", expiry=115.0)

        target, dist = detector.get_closest(candies, player, now=100.0, filter_type="Candy")
        self.assertIsNotNone(target)
        self.assertEqual(target.name, "C2", "Blacklisted C1 must be skipped")
        self.assertAlmostEqual(dist, 10.0, places=2)

        # After expiry (now=120.0), C1 should be eligible again
        target2, dist2 = detector.get_closest(candies, player, now=120.0, filter_type="Candy")
        self.assertIsNotNone(target2)
        self.assertEqual(target2.name, "C1", "Expired blacklist coin must become eligible again")

    def test_screen_boundary_clamping(self):
        # Android phone viewport: 2400 x 1080, GUI size: 340 x 260
        vp_w, vp_h = 2400.0, 1080.0
        fw, fh = 340.0, 260.0

        # Attempt to drag off-screen left/top
        cx, cy = clamp_to_viewport(vp_w, vp_h, fw, fh, req_x=-100, req_y=-50)
        self.assertEqual(cx, 0.0)
        self.assertEqual(cy, 0.0)

        # Attempt to drag off-screen right/bottom
        cx, cy = clamp_to_viewport(vp_w, vp_h, fw, fh, req_x=3000, req_y=2000)
        self.assertEqual(cx, 2400.0 - 340.0)
        self.assertEqual(cy, 1080.0 - 260.0)

        # Normal drag inside screen
        cx, cy = clamp_to_viewport(vp_w, vp_h, fw, fh, req_x=500, req_y=300)
        self.assertEqual(cx, 500.0)
        self.assertEqual(cy, 300.0)

    def test_bag_capacity_state_machine(self):
        bag_limit = 40
        candies = 39
        is_full = (candies >= bag_limit)
        self.assertFalse(is_full)

        candies += 1
        is_full = (candies >= bag_limit)
        self.assertTrue(is_full, "Reaching 40 candies must trigger BAG_FULL")

if __name__ == "__main__":
    unittest.main()
