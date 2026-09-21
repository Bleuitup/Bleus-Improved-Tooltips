# Broader vanilla Lua review — 2026-09-17

## Outcome and scope

This follow-up expands beyond the UI mod. It produced **three additional source-reproduced issue drafts**, listed below. No issue has been posted and no game/mod Lua has been changed.

A broad search covered the 1,254 installed `.lua` files, followed by targeted control-flow review in power/structures, ammo and med pickups, weapon ammo/reload handling, chat/muting, bot decisions, selection, regeneration, recycling, supply, voting, and statistics. This was **not a line-by-line audit of every file**, and no conclusion that the rest of NS2 is bug-free follows from it.

Checks used actual source with a standalone Lua 5.4 harness and engine/service stand-ins. They establish the investigated control flow, not live engine/network/rendering integration. Proposed in-game reproduction steps are clearly labeled as unperformed.

## Existing cooldown report: do not duplicate

Martin correctly pointed out that the cooldown problem is already [Ghoul issue #235, Commander ability cooldowns are not displayed after changing commanders](https://github.com/GhoulofGSG9/ns2-game/issues/235). Its expected behavior covers incoming commanders regardless of who cast the ability.

The mod handoff's empty-seat late-join case is a regression check for incomplete coverage of that existing repair. It is **not a newly discovered, separately reportable vanilla bug**. Retain the mod regression test, cross-reference #235, and do not draft a second upstream cooldown issue.

The existing biomass issue #236 and the earlier notification-overflow draft also remain separate from this follow-up.

## Additional reports

| ID | Suggested priority | Finding | Draft |
| --- | --- | --- | --- |
| VAN-01 | P2 | Power Surge expiry cancels a beacon even after normal power has returned. | [Power Surge / beacon](upstream-power-surge-beacon-draft.md) |
| VAN-02 | P2 | Weapon-specific ammo is consumed without a transfer when the active weapon is full but another weapon needs ammo. | [Weapon ammo pickup](upstream-weapon-ammo-pickup-draft.md) |
| VAN-03 | P3 | Timed text and voice mutes remain active in memory after their six-hour expiry. | [Mute expiry](upstream-mute-expiry-draft.md) |

The first two are the most useful gameplay reports to verify in game first. The mute report explicitly leaves room for maintainers to clarify whether the six-hour limit was intended only for persistence across sessions.

### VAN-01 evidence

Installed `PowerConsumerMixin.lua:150–160` clears the temporary surge and invokes `OnPowerOff()` without checking normal power. Beta/CBM adds a battery guard at 162 but still omits normal power. The Observatory's real callback cancels its real beacon state.

The probe activates a ten-second surge, restores normal power at t=8, sets an active beacon due at t=14, then advances to t=10.1. Result: `GetIsPowered() == true`, yet `distressBeaconTime == nil` and the beacon sound is stopped. A subsequent update without surge expiry leaves a new beacon intact.

Reproduced against installed vanilla, CBM release/dev, downloaded beta/public CBM, and the differing Observatory versions in master and core-only. Infantry Portal's power-off handler also requeues a player, but the probe specifically exercises the Observatory.

### VAN-02 evidence

`AmmoPack:GetIsValidRecipient()` checks all carried clip weapons. `WeaponAmmoPack:GetIsValidRecipient()` checks active weapon class, but not that active weapon's ammo need. `OnTouch()` gives reserves only to that active weapon; `DropPack:OnUpdate()` destroys the pickup regardless of whether ammo moved.

Probe: rifle 200/200, pistol 9/40, rifle-ammo pickup with 50 rounds. The real update destroys the pickup with both ammo counts unchanged. Filling both weapons makes the same pickup ineligible. Reproduced on installed vanilla, both local CBMs, downloaded beta, and the distinct ClipWeapon version on CBM's fixes branch.

### VAN-03 evidence

`Chat.lua:23` establishes six hours and setters write `targetTime`. Text queries never compare that timestamp. The active voice cache is also left set; querying voice after expiry sends no unmute message. Persistence filtering does check timestamps, so active and stored behavior differ.

The probe loads the full actual Chat file, advances a fake system clock past expiry, checks both mute paths, and verifies that explicit unmute still works. The server-message interface is recorded by a stub, not sent to a game server.

## Upstream and CBM comparison

Checked NS2 heads:

| Branch | Commit |
| --- | --- |
| master | `14508c8ed2b4c43b9ebf0ea300ca31e6430ef2bf` |
| beta | `bc7bb36d54d0ab5f63ee1aaf3ecf046f2019cdae` |
| hotfix-344 | `aa55e474e6f6debb2c5f8797ab83deba407de873` |
| bdt-344 | `13c130aee4c746fbf430fb6dbafaf3928d1dddf3` |
| v344.1-CBM-core | `e816f92fed7ad6dfc265d77cf27ff020f99158c1` |
| v344.1-CBM-core-only-notoggle | `5bca83ef07fbd3f6ffe705ca65b05365bfe38796` |

Checked public [CBM fork](https://github.com/GhoulofGSG9/CommunityBalanceMod):
- main: `9c4ae8a769340b1854ab7cfe5c9fe8dfd159fc1a`.
- PR-Vanilla-Bugfixes: `4e2b9cf0adaad2b6fd8cc045d5de4eaa7603f2ab`.
- ghouls-core: `f885aa1d093cf1f9423ec052dbece3e2eaecc253`.

Compared complete, non-truncated source trees and inspected differing relevant code. Useful blob evidence:
- `Chat.lua`: `7ecd14066223a5d6691f0899878b505dad4a62c1` on all six NS2 branches; no Chat replacement in the three CBM trees or local CBM variants.
- `PowerConsumerMixin.lua`: vanilla family `78dc1aa6a624ae479fe15d07b97545d67c26d295`; beta/CBM family `10287915bc7477c082c7bd73dda27b1d2f2a19de`. Both have the expiry problem.
- `AmmoPack.lua`: vanilla family `7621fcf00ce16826b8a92d1801d9d8bd4e6135e0`; beta `62b5790b325ad9f8ae1c5f7a7887e690191cef9f`; CBM family `d025e578a1f69d22adc4f3e364e17a91b52fa95c`. The relevant validation is defective in each.
- Local CBM release's raw file bytes exactly match the public CBM blobs for AmmoPack, DropPack, PowerConsumerMixin, and ClipWeapon. Do not normalize CRLF before comparing Git blob hashes: upstream files include mixed newline conventions.

No fix was found in these inspected variants. This does not claim access to private CBM development or every historical/experimental branch.

All-state issue/PR titles and bodies were searched in Ghoul's NS2 tracker and the accessible CBM tracker. No matching report was found for the three findings. This is a bounded duplicate search, not a guarantee that no differently worded discussion or external Trello card exists. Existing beacon PRs #155/#161 concern destination selection, not surge expiry. Open HUD PR #225 does not change these paths. The ClipWeapon change in open statistics PR #218 only adds a lost-weapon statistic on destruction and does not address ammo transfer/eligibility.

## Candidates deliberately not promoted

- `researchBiomassHive` has a suspicious `not ... ==` condition, but the searched code did not show a consumer for that sense. Do not infer broken bot biomass behavior from unused code.
- Marine bot build selection has another precedence problem, but its executor switches back to the original build target for an already-built socketed node. The condition alone is not sufficient evidence of a gameplay defect.
- Power-source replacement, hot-group cache clearing, and Lerk retreat guards contain suspicious conditions. They need an actual reachable scenario and stronger outcome tests before issue drafts.
- A duplicate-player-name chat-mute scenario was discarded after finding server-side unique-name handling.
- Commander pickup-stat attribution deserves a separate follow-up; it has not been reproduced here or cleared against the open statistics work. No draft included.
- Regeneration, recycling, supply, and voting were sampled; no additional issue was established strongly enough to report from those reads.

## Reproduction and handoff

Files:
- [Probe script](broader-vanilla-probes.lua)
- [Actual probe output](broader-vanilla-probe-results.txt)

Run the script with four arguments: installed vanilla Lua directory, local CBM release Lua directory, local CBM dev Lua directory, and the upstream snapshot directory.

Snapshots are currently in:
`C:\Users\maost\AppData\Local\Temp\bleu-ui-audit-20260917`.

Required downloaded files:
- From the pinned NS2 beta above: `ns2/lua/PowerConsumerMixin.lua`, `Observatory.lua`, `AmmoPack.lua`, `DropPack.lua`, `Chat.lua`, and `Weapons/Marine/ClipWeapon.lua`, saved as `ns2-beta-<basename>`.
- Master Observatory saved as `ns2-master-Observatory.lua`.
- Core-only Observatory saved as `ns2-core-only-Observatory.lua`.
- Public CBM main `src/lua/PowerConsumerMixin.lua` and `Observatory.lua`, saved as `cbm-main-<basename>`.
- Public CBM fixes `src/lua/Weapons/Marine/ClipWeapon.lua`, saved as `cbm-fixes-ClipWeapon.lua`.

The probe loads full source files where practical and extracts complete named functions for selected large engine-dependent files. Its lightweight class helper copies inherited methods, matching the relevant NS2 class behavior. Original sources are read only.

Next useful step is in-game verification of VAN-01 and VAN-02, followed by any wording adjustments before posting. Do not claim those steps were completed based on the standalone test alone.
