# 🎃 Private MM2 Candy Farm (Delta Executor Edition)

A high-performance, autonomous, completely clean-room Murder Mystery 2 Candy Farm script engineered specifically for the **Delta Executor** on Android mobile devices and Windows.

---

## ⚡ Highlights

- **RockHub Feature Parity:** 100% independent re-implementation of verified RockHub Candy Farm capabilities (Speed control, Anti-AFK, Performance Mode, Safe Platform, Bag Auto-Reset, Auto-Resume).
- **Mobile-First Touch Ergonomics:** Built specifically for Android phone screens with smooth touch dragging, automatic screen-boundary clamping, and a floating launcher capsule.
- **100% Standalone & Self-Contained:** Single distribution file (`dist/PrivateCandyFarm.lua`), zero external `loadstring()` calls, zero external GitHub downloads.
- **Ironclad Security:** Zero webhooks, zero telemetry, zero credential/cookie sniffing, and zero obfuscation.
- **Fail-Safe Watchdogs:** Timeout-based anti-stuck detection and dynamic blacklists prevent infinite loops or desync stalling.

---

## 📊 RockHub Feature Parity Matrix

| Feature | RockHub Original | Private MM2 Farm | Status | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Coin & Candy Autofarm** | Verified | Implemented | **TESTED** | Full Start/Stop lifecycle with zero thread leakage |
| **Farm Speed Control** | Verified (5–25 m/s) | Implemented (Normal: 28, Fast: 38, Instant) | **TESTED** | Distance-scaled linear tweening / step-lerp |
| **Performance Mode (FPS Booster)** | Verified | Implemented | **TESTED** | Strips shadows, particles, fog for potato Android phones |
| **Anti-AFK Protection** | Verified | Implemented | **TESTED** | Dual-layer: `getconnections(Idled)` + `VirtualUser` |
| **Safe Platform Parking** | Verified | Implemented | **TESTED** | Anchored underground platform (Y = -120) when bag full |
| **Bag Capacity Auto-Detect** | Verified (40 / 50 Elite) | Implemented | **TESTED** | Listens to `Remotes.Gameplay.CoinCollected` + GUI fallback |
| **Respawn Auto-Recovery** | Verified | Implemented | **TESTED** | Seamless recovery on `CharacterAdded` without duplicate loops |
| **Anti-Stuck Watchdog** | Incomplete / Flawed | Implemented | **TESTED** | Aborts stalled paths after 2.5s and blacklists target for 12s |
| **Touch Screen Boundary Clamping** | Unsupported (Off-screen loss) | Implemented | **TESTED** | Clamps UI within mobile viewport bounds |
| **Mini HUD Floating Capsule** | Unsupported | Implemented | **TESTED** | Shows live candy bag count (`🍬 38/40`) when minimized |
| **Settings Persistence** | Unsupported | Implemented | **TESTED** | Saves configuration locally via `readfile` / `writefile` JSON |
| **Clean Unload & Exit** | Incomplete | Implemented | **TESTED** | Destroys UI, disconnects signals, restores collisions |
| **Discord Webhook Exfiltration** | Present in RockHub | Omitted by design | **UNSUPPORTED** | Prohibited for privacy and account security |
| **Kill All / Fling Murderer** | Present in RockHub | Omitted by design | **UNSUPPORTED** | Out of scope for dedicated private candy farming |

---

## 🛠️ Project Structure

```text
Private-MM2-CandyFarm/
├── src/
│   ├── main.luau            # Modular entry point
│   ├── core/
│   │   ├── State.luau        # Central reactive state store
│   │   ├── MapManager.luau   # Active map discovery & round remotes
│   │   ├── CandyDetector.luau# Candy filtering, distance sort & blacklist
│   │   ├── Movement.luau     # TweenService, lerp, noclip & timeout watchdog
│   │   ├── Performance.luau  # 3D rendering & particle stripper
│   │   └── Persistence.luau  # Delta readfile/writefile JSON config
│   ├── ui/
│   │   └── MobileUI.luau     # 100% pure Luau GUI with touch & clamping
│   └── utils/
│       ├── Maid.luau         # Strict connection & task lifecycle cleaner
│       └── AntiAFK.luau      # Disables 20-min Roblox AFK kick
├── tests/
│   ├── bundle_and_verify.py  # Single-file packager & security scanner
│   └── test_farm_logic.py    # Unit tests (selection, clamping, blacklist)
├── dist/
│   └── PrivateCandyFarm.lua  # Ready-to-execute single-file distribution
├── README.md
├── SECURITY.md
└── VERIFICATION_REPORT_RU.md
```

---

## 📱 How to Run in Delta Executor

1. Copy the entire contents of [`dist/PrivateCandyFarm.lua`](dist/PrivateCandyFarm.lua).
2. Open **Roblox** via **Delta Executor** on Android or Windows.
3. Join **Murder Mystery 2**.
4. Paste the script into Delta's script editor and press **Execute**.
5. Control the farm via the floating capsule pill or the compact dashboard!
