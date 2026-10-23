# MM2 Candy Farm — Security & Anti-Malware Audit Report

**Auditor:** Security & Anti-Malware Auditor (MM2 Candy Farm Council)  
**Date:** October 2026  
**Target Codebases:**
- Obfuscated Target: `C:\Users\soul\Downloads\RockHubCandyFarm_New-obfuscated.txt`
- Research Reference Scripts:
  - `research/NoCapital_Christmas.lua`
  - `research/NoCapital_Halloween.lua`
  - `research/Zynic_FreeScript.lua`
- Destination Project: `Private-MM2-CandyFarm`

---

## 1. Static Analysis of RockHub Obfuscated Script (`RockHubCandyFarm_New-obfuscated.txt`)

### 1.1 File Overview
- **Path:** `C:\Users\soul\Downloads\RockHubCandyFarm_New-obfuscated.txt`
- **File Size:** 379,331 bytes (~379 KB)
- **Header Signature:**
  ```lua
  -- This file was protected using Luraph Obfuscator v14.9 [https://lura.ph/]
  ```

### 1.2 Identified Obfuscation Mechanisms & Characteristics
1. **Custom Lua Virtual Machine (LVM):**
   - The file contains a complete virtual machine implementation inside Lua. It declares custom opcode fetch-decode-execute routines, virtual registers, stack pointers, and program counters.
2. **Control Flow Flattening (CFF):**
   - Linear program flow has been shattered into massive, non-linear dispatch loops:
     ```lua
     while true do if f < 0x56 and f > 0B1001_1 then ... elseif f > 0x56 then ...
     ```
   - Control states are driven by pseudo-random integer state variables (`0B1111010`, `0x2C85`, `0x4C`), completely destroying call graphs, abstract syntax trees (ASTs), and control-flow graphs (CFGs).
3. **Heavy Bitwise Operations & LCG PRNG Obfuscation:**
   - Ubiquitous usage of Lua 5.2 / Luau `bit32` primitives:
     `bit32.band`, `bit32.bor`, `bit32.bxor`, `bit32.lrotate`, `bit32.rrotate`, `bit32.countlz`, `bit32.countrz`, `bit32.bnot`, `bit32.lshift`, `bit32.rshift`.
   - Linear Congruential Generator (LCG) pseudo-random constants (e.g., multiplier `93177`, modulus `16777216`, increments) used to calculate dynamic jump offsets and register lookups at runtime.
4. **Dynamic Bytecode Serialization & String Packing:**
   - Byte stream reading functions: `string.unpack`, `readu8`, `readi16`, `readi32`, `readf32`, `readf64`, and custom base-85/binary string deserializers. Strings and symbol tables are encrypted and unpacked dynamically in memory.
5. **Anti-Tampering, Anti-Debugging & Environment Integrity Checks:**
   - Checks on `debug.getinfo`, `getfenv`, `setfenv`, coroutine state inspections (`coroutine.yield`, `coroutine.wrap`), and checksum validations designed to crash or enter infinite loops upon tampering.

### 1.3 Security Assessment & Ruling
- **Critical Risk:** The Luraph bytecode payload is 100% opaque without a complete reverse-engineering / de-virtualization pipeline. Within this 379 KB bytecode stream, the author can trivially embed:
  - Hidden HTTP exfiltration (`request`, `http_request`, `syn.request`)
  - Discord webhooks logging Roblox user credentials, JobId, IP address, HWID, or account inventory
  - Stealers targeting `.ROBLOSECURITY` cookies or local executor storage
  - Remote kill switches or dynamic backdoor droppers
- **Verdict: ZERO-TOLERANCE REJECTION.**  
  Under no circumstances may any chunk of `RockHubCandyFarm_New-obfuscated.txt` or any other obfuscated script be committed, imported, or executed within `Private-MM2-CandyFarm`. All code in our repository must be 100% transparent, readable, and auditable Luau.

---

## 2. Security Audit of Reference Research Scripts

### 2.1 `research/NoCapital_Christmas.lua` (10.8 KB, 404 lines)
- **External Dependencies:**
  - Line 16: `GuiLibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/elfandtears/GuiLibrary/main/source.lua"))()`
  - **Risk:** Remote code execution via third-party GitHub URL. If the external repository is compromised or deleted, our script executes hostile code or fails.
- **Malicious Patterns (Webhooks / Stealers):**
  - **Result: CLEAN.** No Discord webhooks, no cookie access, no `request()` calls.
- **Mechanics Analysis:**
  - Detects event tokens via `v:GetAttribute("CoinID") == "SnowToken"`.
  - Movement: Combines raw CFrame teleportation for long distances (`> 150` studs) with TweenService interpolation (`TweenInfo.new(dds[2] / 20)`).
  - Safety hazard: Instant teleportation above 150 studs (`PcallTP`) is an anti-cheat detection flag on MM2 servers.

### 2.2 `research/NoCapital_Halloween.lua` (11.8 KB, 424 lines)
- **External Dependencies:**
  - Line 7: `loadstring(game:HttpGet("https://raw.githubusercontent.com/NoCapital2/MM2Autofarm/refs/heads/main/ChristmasAutofarm"))()`
  - Line 25: `GuiLibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/elfandtears/GuiLibrary/main/source.lua"))()`
  - **Risk:** Redirection wrapper. It immediately downloads and evaluates remote code from an unpinned branch.
- **Malicious Patterns:**
  - **Result: CLEAN of static backdoors**, but completely dependent on external network integrity.

### 2.3 `research/Zynic_FreeScript.lua` (64.2 KB, 1631 lines)
- **External Dependencies:**
  - Lines 10, 15: `Octree = loadstring(httpget("https://raw.githubusercontent.com/Sleitnick/rbxts-octo-tree/main/src/init.lua", true))()`
  - Lines 11, 16: `library = loadstring(httpget("https://raw.githubusercontent.com/Zyn-ic/MM2-AutoFarm/refs/heads/main/UI-Library/XSX.lua", true))()`
  - Lines 12, 17: `Iris = loadstring(httpget("https://raw.githubusercontent.com/x0581/Iris-Exploit-Bundle/2.0.4/bundle.lua"))().Init(game.CoreGui)`
- **Network / HTTP Activity:**
  - Line 1019:
    ```lua
    local req = request({Url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true", PlaceId)})
    local body = rt.HttpService:JSONDecode(req.Body)
    ```
  - **Risk Evaluation:** This request targets official public Roblox APIs (`games.roblox.com`) strictly for server-hopping. It does not send credentials, cookies, or user identifiers. However, using executor `request()` creates a potential network surface and executor dependency.
- **Global Scope Pollution:**
  - Pollutes `getgenv().OldPos`, `getgenv().AutoFarmSettings`.
- **Malicious Patterns:**
  - **Result: CLEAN.** No Discord webhooks, no telemetry beacons, no credential theft.

---

## 3. Strict Security Standards for Private Candy Farm

To ensure total safety, reliability, and privacy, `Private-MM2-CandyFarm` must adhere strictly to the following architectural rules:

1. **Zero External Dependencies / Zero Loadstrings:**
   - Absolute ban on `loadstring()`, `game:HttpGet()`, `httpget()`, or fetching code from raw GitHub, Pastebin, or CDN endpoints at runtime.
   - All libraries (UI components, Octree spatial partitioning, Maid/Janitor lifecycle management, tween helpers) must be implemented locally or vendored cleanly in plain Luau source code.
2. **Zero Webhooks, Telemetry, or Analytics:**
   - Absolute ban on Discord webhook calls (`discord.com/api/webhooks/`, `discordapp.com`).
   - No analytics pings, no server logging, no outbound telemetry of player usernames, user IDs, HWIDs, or IP addresses.
3. **Zero Credential or Storage Snooping:**
   - No calls attempting to access `.ROBLOSECURITY`, authorization cookies, browser session stores, or private account data.
   - No unauthorized clipboard tampering (`setclipboard`/`getclipboard`) unless explicitly initiated by the user for a benign action (e.g., copying settings).
4. **Complete Self-Containment:**
   - The final output (`dist/PrivateCandyFarm.lua`) must be 100% self-contained in a single deployable file.
   - It must execute flawlessly in an offline / sandbox environment without requiring outbound HTTP access.
5. **Private Lexical Scoping & Sandbox Hygiene:**
   - Encapsulate the entire codebase inside a private closure (`do ... end` or IIFE).
   - Do not pollute `_G` or `getgenv()` with state that could be probed by game scripts or other running exploits.
6. **Anti-Detection & Safe Physics:**
   - Avoid instant CFrame snaps over long distances across map geometry.
   - Implement smooth TweenService interpolation or physics velocity steering with randomized human-like jitter, obstacle raycasting, and collection cooldowns matching MM2 server validation limits.

---

## 4. Threat Assessment Matrix

| Threat ID | Threat Description | Likelihood | Impact | Mitigation Strategy |
|---|---|:---:|:---:|---|
| **T-01** | **Supply Chain Hijack** (External GitHub script tampered with or deleted) | High | Critical | **100% Self-Containment:** All modules bundled locally. Zero `loadstring` / `HttpGet`. |
| **T-02** | **Account / Credential Theft** (Malicious webhook / cookie stealer) | Critical (in public scripts) | Fatal | **Zero HTTP Network Calls:** Ban all outbound requests. Audited code gate. |
| **T-03** | **Server-Side Anti-Cheat Detection** (Speed/teleport heuristics in MM2) | High | High | **Natural Movement Engine:** Tweening with distance-scaled duration, raycast collision checks, no instant map-wide CFrame jumps. |
| **T-04** | **Client Memory Leaks & Freezes** (Dangling connections, event leaks) | High | Medium | **Maid Lifecycle Management:** All event connections (`CoinCollected`, `RoundStart`, `Heartbeat`) registered with `Maid` and cleared on round transition. |
| **T-05** | **Anti-AFK Crash / Ineffective Hooking** (Roblox 20-minute idle kick) | Medium | Medium | **Dual-layer Anti-AFK:** Safely disable `Idled` via `getconnections` with fallback to `VirtualUser:ClickButton2` without mutating global metatables. |

---

## 5. Security Verification Gate & Checklist for `PrivateCandyFarm.lua`

Before `dist/PrivateCandyFarm.lua` can be released or executed, it must pass this automated verification gate:

### 5.1 Static Pattern Ban (Fail if any match found)
```powershell
# Prohibited functions and strings check
$prohibited = @(
    "loadstring",
    "HttpGet",
    "httpget",
    "api/webhooks",
    "discord.com",
    "discordapp.com",
    "ROBLOSECURITY",
    "setfenv",
    "getfenv"
)
```

### 5.2 Mandatory Security Checklist
- [x] **Zero Obfuscation:** Code is 100% plain, readable Luau with descriptive variable and function names.
- [x] **Zero External Loadstrings:** No calls to `game:HttpGet` or dynamic module loaders.
- [x] **Zero Outbound HTTP:** No webhooks, analytics, telemetry, or server logging.
- [x] **Single-File Bundling:** Self-contained in `dist/PrivateCandyFarm.lua` with local UI and spatial indexing.
- [x] **Encapsulated Scope:** All runtime state is strictly confined to local closures; no public `_G` or `getgenv()` leakage.
- [x] **Anti-Cheat Resilience:** Motion utilizes continuous tweening / raycast clearance to avoid server-side teleport flags.
- [x] **Lifecycle Cleanup:** Clean teardown of all event connections via `Maid` pattern upon script stop or player respawn.
