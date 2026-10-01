**Title:** Research notifications pushed below the display limit disappear permanently, and that research then completes with no notification and no sound

*Draft for `GhoulofGSG9/ns2-game`, in the repository's bug report template. Not filed. First written
2026-09-17 from the source review; rewritten 2026-09-21 with a concrete tech path per case, each one
checked by driving the shipped notification files directly (see Additional context).*

**Describe the bug**

The research notifications on a field player's HUD are capped: three for aliens and five for
marines, two and three with the NS1 HUD bars. Research past that cap is not queued. When a research
starts that will finish sooner than one already on screen, it takes a place in the list, and the
entry with the most time left is pushed past the cap, faded out, destroyed, and dropped from the
list's own data. Nothing puts it back, although the research is still running.

For that research the team then gets:

- no "in progress" notification for the rest of its duration,
- no green "research complete" state,
- no completion sound, the "trait available" voiceover for aliens and the upgrade sound for marines,
- and no red "research cancelled" warning if it is cancelled instead.

The research itself finishes normally; only the notification is lost. The commander still gets the
research complete alert, which is a separate path, so it is the rest of the team that loses the
information.

It is worth saying which case does **not** break. A research that starts while the list is full but
finishes after everything on screen waits its turn correctly and is shown as soon as a place frees,
and its sound plays then, a moment late. So the loss depends on the order things finish in, not on
the count alone.

Aliens reach it easily, because hive type upgrades (20 s) are much quicker than the abilities (40 to
90 s), so fast upgrades started later push slow abilities out. Six simultaneous researches, three
hive type upgrades and three abilities, was what first showed this in game.

The same loss happens when the HUD is rebuilt while more research is running than can be shown, for
example after a death and respawn, because `GUIEvent:Initialize` queues everything in progress again
in the order `GetResearchInProgressTable` returns, which is not sorted by time left. A round that
had lost nothing can lose a notification at the moment the player respawns.

The same code serves both teams, and CBM inherits it unchanged. CBM makes it easier to reach, as it
adds per-structure upgrades (Fortress structures, Advanced Observatory, Exo Prototype Lab) that run
alongside everything else.

**To Reproduce**

These notifications belong to the field player's HUD, so watch from outside the chair or hive; the
commander does not see this list. Needs Research notifications on (Advanced Options > UI, on by
default) and HUD bars on Default or Centralized, except where NS1 is named. To set the structures up
quickly: `sv_cheats 1`, then `tres`, then `autobuild` to build them, and **turn `autobuild` back off
before starting any research**, since it shortens every research to half a second.

*Aliens, three shown, four researches.* Two built hives, and one +1 biomass upgrade so the team is at
biomass 3. (Biomass upgrades themselves never appear in this list, they are only needed here to
unlock a second ability.) Then start, in this order:

1. Hive 1's evolution chamber: Bile Bomb (40 s)
2. Hive 2's evolution chamber: Metabolize (40 s)
3. Hive 1: upgrade to Crag Hive (20 s)
4. Hive 2: upgrade to Shade Hive (20 s)

Leave the hive and watch the list. The moment the second hive upgrade starts, the Metabolize
notification fades out. It never comes back, and about 35 seconds later Metabolize finishes in
silence, with no notification of any kind.

*Aliens with the NS1 HUD bars, two shown, three researches.* Two built hives, no biomass upgrade
needed: Bile Bomb (40 s), then upgrade Hive 1 to Crag Hive (20 s), then Hive 2 to Shade Hive (20 s).
Bile Bomb is the one lost.

*Marines, five shown, six researches.* One Command Station, two Arms Labs and three Armories:

1. Armory 1: upgrade to Advanced Armory (90 s)
2. Arms Lab 1: Armor 1 (75 s)
3. Arms Lab 2: Weapons 1 (75 s)
4. Command Station: Advanced Marine Support (60 s)
5. Armory 2: Shotguns (30 s)
6. Armory 3: Mines (20 s)

The Advanced Armory notification disappears as soon as Mines starts, and that upgrade finishes in
silence about 80 seconds later.

*Marines with the NS1 HUD bars, three shown, four researches.* One Command Station, one Arms Lab,
two Armories: Advanced Armory (90 s), Armor 1 (75 s), Advanced Marine Support (60 s), then Mines
(20 s). Advanced Armory is the one lost.

*Cancel variant.* Run any of the above, then cancel the research whose notification disappeared. No
red "research cancelled" notification appears, so the team is never told it was cancelled either.

*Respawn variant.* Start the four alien researches in the opposite order, the two hive upgrades
first, so that nothing is lost and the fourth research is correctly waiting its turn. Then die and
respawn. The list is rebuilt and one of the four is dropped for good.

**Expected behavior**

Research that does not fit should wait and be shown when a place frees, which the list already does
for research that finishes last. Nothing in progress should be discarded.

The complete and cancelled states, and the completion sound, should follow the research rather than
whether its notification happened to be on screen at that moment.

**Screenshots**

Not attached.

**System details:**

- NS2 Build: 344.3521.
- The relevant code is unchanged in the inspected upstream master, beta, hotfix and CBM integration
  branches: `GUIEvent.lua`, `GUINotificationItem.lua`, `GUINotificationMixin.lua` and
  `TechTree_Client.lua` have had no commit on beta since 2020.
- CBM checked: installed 3.5, local 3.6 dev, and the accessible GhoulofGSG9/CommunityBalanceMod main
  and PR-Vanilla-Bugfixes source. None of them replaces these files.

**Additional context**

All line numbers are `lua/Hud/GUIEvent.lua` as shipped in 344.

- The caps are `kMaxDisplayedNotificationsMarine` / `Alien` at lines 34 to 35 and the NS1 pair at
  lines 37 to 38, applied in `Initialize` at lines 44 and 73 to 78.
- `InsertNotification` (line 117) keeps `notificationsData` sorted by time left, and `Update` builds
  an item at that index whenever the new research lands within the displayed list (lines 176 to
  188), with no check against `maxNotifications`, so the displayed list can be one longer than the
  cap for one update.
- That extra entry is handled at lines 293 to 297: it is sent through `FadeOut(0.5)` and kept for the
  moment. One update later its fade deadline has passed, so lines 288 to 291 destroy it, and neither
  the item nor its data entry is carried into `remainingNotifications` /
  `remainingNotificationData`. Lines 374 to 383 then keep only the data past the *old* displayed
  count, so the record is gone from `notificationsData` as well and the research is never considered
  again.
- `GUINotificationItem:FadeOut` (`lua/Hud/GUINotificationItem.lua:521-551`) schedules destruction, so
  using it for overflow does more than hide a notification temporarily.
- The completion handling, including `TriggerEffects("upgrade_complete")`, sits in the branch for
  items within the cap (lines 345 to 354), so the sound belongs to the notification rather than to
  the research. A research still waiting its turn gets its sound late, when it is finally shown; a
  dropped one never gets it at all.
- Line 366 also clears `techNode.instances[entityId]` for the pushed out item, so an instanced
  research (hive type upgrades, Advanced Armory, ARC factory) loses its per-entity progress on the
  way out.

A possible approach would separate removing a rendered notification from retiring its research
record: an overflowed item could release its GUI item while its record stays in `notificationsData`,
so the existing "add more notifications if we have not reached our max" path at lines 192 to 204
brings it back when a place frees. Completion and cancellation handling, and the sound, could then
be driven from the research state of every record rather than only the ones on screen. Care is
needed around the per-instance cleanup at lines 366 to 368. The catch-up in `Initialize` (lines 61 to
71) would also be worth sorting by time left before queueing, so a rebuilt HUD starts from the order
the list would have settled into.

How this was checked: the shipped `GUIEvent.lua`, `GUINotificationItem.lua`,
`GUINotificationMixin.lua`, `TechTree_Client.lua` and `TechNode.lua`, plus the tech node message
parsers from `NetworkMessages.lua`, were run directly against GUI and engine stand-ins and driven by
a model of the server side of `ResearchMixin`. Each case above was run that way: the four repro
paths, the cancel and respawn variants, and a control in which the same four researches are started
quickest first and nothing is lost. The alien case was also seen in a live game. This is not a claim
of a fresh in-game test of every case or of every branch listed.

References to the inspected beta commit:

- [GUIEvent update and overflow handling](https://github.com/GhoulofGSG9/ns2-game/blob/bc7bb36d54d0ab5f63ee1aaf3ecf046f2019cdae/ns2/lua/Hud/GUIEvent.lua#L288)
- [Completion sound](https://github.com/GhoulofGSG9/ns2-game/blob/bc7bb36d54d0ab5f63ee1aaf3ecf046f2019cdae/ns2/lua/Hud/GUIEvent.lua#L348)
- [Fade and destruction lifecycle](https://github.com/GhoulofGSG9/ns2-game/blob/bc7bb36d54d0ab5f63ee1aaf3ecf046f2019cdae/ns2/lua/Hud/GUINotificationItem.lua#L521)
