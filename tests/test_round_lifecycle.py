#!/usr/bin/env python3
"""
test_round_lifecycle.py
Targeted regression tests for the Fail-Closed MM2 Round State Machine:
1. Joining MM2 directly into the lobby (stale map in workspace)
2. Intermission & voting periods
3. Confirmed round start and active movement authorization
4. Immediate movement cancellation upon round end
5. Mid-round join evaluation (spectator vs active player)
"""

import unittest
from dataclasses import dataclass
from typing import Optional

@dataclass
class SimulatedMM2Environment:
    has_map: bool = False
    has_coin_container: bool = False
    is_lobby_map: bool = False
    player_in_lobby_zone: bool = True
    player_alive_attribute: Optional[bool] = None
    timer_gui_visible: bool = False
    round_start_remote_received: bool = False
    round_end_remote_received: bool = False

class SimulatedMapManager:
    def __init__(self, env: SimulatedMM2Environment):
        self.env = env
        self.round_state = "WAITING"

    def evaluate_round_state(self) -> str:
        # Negative Gate 1: No map or no CoinContainer or is Lobby
        if not self.env.has_map or not self.env.has_coin_container or self.env.is_lobby_map:
            return "WAITING"

        # Negative Gate 2: Server fired RoundEndFade
        if self.env.round_end_remote_received:
            return "ENDING"

        # Negative Gate 3: Player is in lobby zone
        if self.env.player_in_lobby_zone:
            return "WAITING"

        # Positive Gate 1: RoundStart received and round has not ended
        if self.env.round_start_remote_received and not self.env.round_end_remote_received:
            if self.env.player_alive_attribute is True or self.env.timer_gui_visible:
                return "ACTIVE"
            if self.env.player_alive_attribute is False:
                return "ENDING"
            return "ACTIVE"

        # Positive Gate 2: Joining mid-round verification
        if self.env.player_alive_attribute is True and self.env.timer_gui_visible:
            return "ACTIVE"

        if self.env.player_alive_attribute is False or self.env.player_alive_attribute is None:
            return "WAITING"

        return "UNKNOWN"

    def is_round_active(self) -> bool:
        self.round_state = self.evaluate_round_state()
        return self.round_state == "ACTIVE"

class TestRoundLifecycle(unittest.TestCase):
    def test_join_directly_into_lobby_with_stale_map(self):
        """Regression test for user-reported bug:
        When launching in the main lobby, even if workspace has a pre-loaded map
        with CoinContainer, the farm MUST NOT start moving."""
        env = SimulatedMM2Environment(
            has_map=True,
            has_coin_container=True,
            is_lobby_map=False,
            player_in_lobby_zone=True,           # Player is in main lobby
            player_alive_attribute=None,         # Not spawned into a round
            timer_gui_visible=False,             # Timer not visible in lobby
            round_start_remote_received=False,
            round_end_remote_received=False,
        )
        mgr = SimulatedMapManager(env)
        state = mgr.evaluate_round_state()
        self.assertEqual(state, "WAITING", "Lobby state must be WAITING, not ACTIVE!")
        self.assertFalse(mgr.is_round_active(), "Movement must be strictly blocked in lobby!")

    def test_intermission_and_voting(self):
        """During intermission/voting between rounds, movement must remain blocked."""
        env = SimulatedMM2Environment(
            has_map=False,
            has_coin_container=False,
            player_in_lobby_zone=True,
            player_alive_attribute=False,
            timer_gui_visible=False,
            round_start_remote_received=False,
            round_end_remote_received=True,
        )
        mgr = SimulatedMapManager(env)
        self.assertFalse(mgr.is_round_active())
        self.assertEqual(mgr.evaluate_round_state(), "WAITING")

    def test_confirmed_round_start(self):
        """When RoundStart fires and player is spawned outside lobby as Alive, movement is authorized."""
        env = SimulatedMM2Environment(
            has_map=True,
            has_coin_container=True,
            is_lobby_map=False,
            player_in_lobby_zone=False,          # Teleported into map
            player_alive_attribute=True,         # Server marks Alive = true
            timer_gui_visible=True,              # In-game countdown visible
            round_start_remote_received=True,
            round_end_remote_received=False,
        )
        mgr = SimulatedMapManager(env)
        self.assertEqual(mgr.evaluate_round_state(), "ACTIVE")
        self.assertTrue(mgr.is_round_active(), "Confirmed round must be ACTIVE")

    def test_round_end_immediate_cancellation(self):
        """When RoundEndFade fires, active round terminates immediately."""
        env = SimulatedMM2Environment(
            has_map=True,
            has_coin_container=True,
            player_in_lobby_zone=False,
            player_alive_attribute=True,
            timer_gui_visible=True,
            round_start_remote_received=True,
            round_end_remote_received=False,
        )
        mgr = SimulatedMapManager(env)
        self.assertTrue(mgr.is_round_active())

        # RoundEndFade arrives
        env.round_end_remote_received = True
        self.assertEqual(mgr.evaluate_round_state(), "ENDING")
        self.assertFalse(mgr.is_round_active(), "State must immediately become inactive on RoundEndFade!")

    def test_mid_round_join_spectator_vs_active(self):
        """A player joining mid-round who is spectating from the lobby must NOT farm,
        but an active player joining/reloading mid-round should be recognized as ACTIVE."""
        # Spectator:
        spectator_env = SimulatedMM2Environment(
            has_map=True,
            has_coin_container=True,
            player_in_lobby_zone=True,
            player_alive_attribute=False,
            timer_gui_visible=False,
        )
        mgr_spec = SimulatedMapManager(spectator_env)
        self.assertFalse(mgr_spec.is_round_active())

        # Active player mid-round:
        active_env = SimulatedMM2Environment(
            has_map=True,
            has_coin_container=True,
            player_in_lobby_zone=False,
            player_alive_attribute=True,
            timer_gui_visible=True,
            round_start_remote_received=False,   # Missed the initial RoundStart event
            round_end_remote_received=False,
        )
        mgr_active = SimulatedMapManager(active_env)
        self.assertEqual(mgr_active.evaluate_round_state(), "ACTIVE")
        self.assertTrue(mgr_active.is_round_active())

if __name__ == "__main__":
    unittest.main()
