# Review evidence — 2026-09-17

## Local state

- Mod commit: `16f078808555d84f7d9f13cfe2db9ef2bc089361`, branch `refactor/cleanup`.
- Existing Lua checker: `check_mod: OK, 34 files`.
- Source/output comparison: zero missing, different or extra files.
- Game log inspected in this task: build 344.3521.
- Installed CBM: revision 3.5 at `D:\SteamLibrary\steamapps\workshop\content\4920\2934445221`.
- Local CBM development copy: revision 3.6, build_tag dev, at `G:\My Drive\[01] Martin\[03] Gaming\NS2 Server\Workshop Mods\Community Balance Mod (dev)`.
- No live NS2 reproduction or performance profile was run during this audit.

## Source-level probes

[audit-probes.lua](audit-probes.lua) executes the actual mod state files, actual upstream GUIEvent update code, and the actual GUINotificationItem fade/destruction methods. Engine services and drawing operations are stubbed. This is a control-flow reproduction under Lua 5.4, not a GUI or networking integration test.

Observed:
1. Occupied commander seat: joining player receives clear + current cooldown with original timing.
2. Empty commander seat: the same resync sends only clear.
3. Marine team join: receives clear + a populated alien Hive snapshot.
4. Notification overflow: an active research pushed below the display limit is removed from both GUI and data list after fade; it stays absent when space frees and its later completion produces no sound.
5. The notification probe reproduces on four independently fetched upstream branch files (identical blobs).

The probe uses a display cap of two to keep the scenario small. This is a real supported alien NS1-HUD configuration; the same code handles caps of three and five. The production fix must also be checked with actual game timing and rendering.

Run (Lua and source paths can be adjusted):
```text
lua audit-probes.lua "<Bleus-Improved-Tooltips repo>" "<upstream snapshot directory>"
```

Snapshots from this audit are temporarily stored at:
`C:\Users\maost\AppData\Local\Temp\bleu-ui-audit-20260917`.

If that directory has expired, fetch the four GUIEvent versions below as:
`ns2-beta-GUIEvent.lua`, `ns2-master-GUIEvent.lua`, `ns2-core-GUIEvent.lua`, `ns2-devnull-GUIEvent.lua`,
plus beta `ns2/lua/Hud/GUINotificationItem.lua` as `ns2-beta-GUINotificationItem.lua`.
Use commit-pinned URLs, not moving branches, to reproduce the reviewed revision.

## Ghoul's NS2 repository

Repository: [GhoulofGSG9/ns2-game](https://github.com/GhoulofGSG9/ns2-game).

The following branch heads all have the same `ns2/lua/Hud/GUIEvent.lua` blob:
`9bd0d5ef0bcfeda71dc0a8e31ff582d37a0345e3`.

| Branch | Head at inspection |
| --- | --- |
| master | 14508c8ed2b4c43b9ebf0ea300ca31e6430ef2bf |
| beta | bc7bb36d54d0ab5f63ee1aaf3ecf046f2019cdae |
| hotfix-344 | aa55e474e6f6debb2c5f8797ab83deba407de873 |
| bdt-344 | 13c130aee4c746fbf430fb6dbafaf3928d1dddf3 |
| v344.1-CBM-core | e816f92fed7ad6dfc265d77cf27ff020f99158c1 |
| v344.1-CBM-core-only-notoggle | 5bca83ef07fbd3f6ffe705ca65b05365bfe38796 |
| devnull-enhancedhud | 21238033442da69dc7920fa707e6b096cadca5f0 |

Relevant code:
- [Overflow fade, destruction, and queue retention](https://github.com/GhoulofGSG9/ns2-game/blob/bc7bb36d54d0ab5f63ee1aaf3ecf046f2019cdae/ns2/lua/Hud/GUIEvent.lua#L288).
- [Completion sound tied to displayed notification handling](https://github.com/GhoulofGSG9/ns2-game/blob/bc7bb36d54d0ab5f63ee1aaf3ecf046f2019cdae/ns2/lua/Hud/GUIEvent.lua#L348).
- [FadeOut sets a destruction deadline](https://github.com/GhoulofGSG9/ns2-game/blob/bc7bb36d54d0ab5f63ee1aaf3ecf046f2019cdae/ns2/lua/Hud/GUINotificationItem.lua#L521).
- [Already-fixed biomass dirty-flag typo](https://github.com/GhoulofGSG9/ns2-game/blob/bc7bb36d54d0ab5f63ee1aaf3ecf046f2019cdae/ns2/lua/AlienTeam.lua#L313).

The all-state issues/PR collection was paginated and filtered across titles and bodies for GUIEvent, notifications, research sounds and upgrade_complete. Only open PR #225 matched the notification search. Its branch retains the same GUIEvent file; it is not a fix for this queue loss. The current open PR list was also reviewed. This is a bounded search, not a guarantee that no differently worded discussion exists.

## CBM verification

The old ns2-bdt/CommunityBalanceMod link returns 404 to both web access and the authenticated GitHub CLI. Its old public ancestor ailmanki/CommunityBalanceMod is from 2023 and was deliberately NOT treated as current CBM.

A current accessible fork is [GhoulofGSG9/CommunityBalanceMod](https://github.com/GhoulofGSG9/CommunityBalanceMod), pushed 2026-09-14.
- main head: `9c4ae8a769340b1854ab7cfe5c9fe8dfd159fc1a`.
- PR-Vanilla-Bugfixes head: `4e2b9cf0adaad2b6fd8cc045d5de4eaa7603f2ab`.
- ghouls-core head: `f885aa1d093cf1f9423ec052dbece3e2eaecc253`.

Complete recursive trees for main and PR-Vanilla-Bugfixes contain no GUIEvent, GUINotificationItem, GUINotificationMixin or TechTree_Client replacement. Their FileHooks file is identical, with no hooks for these notification files. The ghouls-core FileHooks blob also matches:
`9a586b943a465d52573a3d321664be59bc205085`.

Local CBM 3.5 and dev 3.6 likewise have no replacement or FileHooks interception of this notification path, so they inherit vanilla behavior. The accessible CBM fork's all-state tracker search found no matching report.

Conclusion: no fix was found in the installed CBM variants or inspected public upstream branches. This does not claim access to unpublished/private CBM development.

## Scope discipline

No duplicate drafts for #235 or #236. No draft for the already-fixed biomass typo. The notification symptoms were known in Claude's local notes; the new work is the upstream comparison and repeatable reproduction. No other previously undocumented vanilla issue was verified to report.
