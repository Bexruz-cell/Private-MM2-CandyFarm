# 🔒 Security & Privacy Policy — Private MM2 Candy Farm

## 1. Executive Summary

This project enforces strict security standards to ensure user account safety, privacy preservation, and device stability. All source code is written in human-readable, auditable Luau with zero external network dependencies.

---

## 2. Static Analysis of Reference Script (`RockHubCandyFarm_New-obfuscated.txt`)

- **File Analyzed:** `C:\Users\soul\Downloads\RockHubCandyFarm_New-obfuscated.txt` (379,331 bytes).
- **Protection Identified:** Luraph Obfuscator v14.9.
- **Characteristics Observed:**
  - Emulated virtual machine (LVM) with virtual registers and custom opcode dispatch.
  - Opaque control flow flattening using nested loops and pseudo-random integer state variables.
  - Bitwise mathematical operations coupled with LCG PRNG multipliers.
  - Encrypted bytecode streams unpacked dynamically via `string.unpack`.
- **Verdict:** **Completely untrusted.** 
  In accordance with project security rules, zero code from this obfuscated file was executed, deobfuscated, or incorporated into this repository. All features were independently developed clean-room.

---

## 3. Mandatory Security Standards

| Standard | Implementation in Private Candy Farm | Verification Method |
| :--- | :--- | :--- |
| **Zero External Loadstrings** | No `loadstring()`, `game:HttpGet()`, or `httpget()`. All modules are compiled in-line. | Automated regex scan (`tests/bundle_and_verify.py`) |
| **Zero Outbound Webhooks** | No Discord webhooks, pastebin uploads, or third-party HTTP endpoints. | Automated regex scan (`tests/bundle_and_verify.py`) |
| **Zero Credential Access** | No queries to `.ROBLOSECURITY`, cookies, passwords, or personal account data. | Codebase inspection & token scanner |
| **Zero Obfuscation** | 100% human-readable Luau code in both `src/` and `dist/PrivateCandyFarm.lua`. | Manual & static inspection |
| **Non-Blocking Execution** | Every while-loop contains non-blocking yields (`task.wait()` or `Heartbeat:Wait()`). | Static loop AST analyzer |
| **Singleton Scope Isolation** | Encapsulated inside `do ... end` block with `_G.PrivateMM2CandyFarmCleanup` handler. | Clean reload verification |

---

## 4. Automated Verification Gate Log

```text
[1/3] Security Audit Results for dist/PrivateCandyFarm.lua:
  [PASS] Discord Webhook URL: 0 matches
  [PASS] DiscordApp Webhook URL: 0 matches
  [PASS] Dynamic Remote Code Loader (loadstring): 0 matches
  [PASS] Executor HTTP Get Request: 0 matches
  [PASS] HttpService Outbound Request: 0 matches
  [PASS] Roblox Cookie Exfiltration Pattern: 0 matches
  [PASS] Environment Hijacking (setfenv): 0 matches
  [PASS] Environment Inspection (getfenv): 0 matches
```

All security checks passed with 0 violations.
