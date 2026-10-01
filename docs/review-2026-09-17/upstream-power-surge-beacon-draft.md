# Power Surge expiry cancels an Observatory beacon even when normal power has been restored

**Describe the bug**
An Observatory can cancel an active Distress Beacon when Power Surge expires, even if its room's Power Node has already been repaired and the Observatory still has normal power.

The expiry path sends a power-off callback without checking whether the structure remains powered. The Observatory interprets that callback as a real power loss and cancels its beacon.

This was reproduced with the actual source functions in a standalone test harness, including the installed vanilla game, CBM release/dev, and Ghoul's beta source. A fresh in-game reproduction has not yet been performed.

**To Reproduce**
Suggested in-game reproduction:
1. Have Power Surge researched and a built Observatory in a room whose Power Node is destroyed.
2. Use Power Surge on the Observatory.
3. Repair the room's Power Node before Power Surge expires.
4. Start a Distress Beacon late enough in the surge that its countdown will still be running when the surge expires.
5. Observe whether the beacon is canceled at surge expiry, despite the repaired Power Node remaining operational.

A source-level reproduction restores normal power at t=8 during a ten-second surge, gives the beacon a completion time of t=14, and runs the update at t=10.1. The beacon is canceled while `GetIsPowered()` still returns true.

**Expected behavior**
Expiring one power source should not interrupt a beacon if the Observatory still has another valid source of power.

**Screenshots**
None attached; verification so far is source-level.

**System details:**
- Installed NS2 Build: 344.3521.
- Also reproduced against local CBM 3.5 and CBM dev 3.6 source.
- The same behavior remains in the inspected upstream vanilla/CBM code.

**Additional context**
In installed vanilla, `lua/PowerConsumerMixin.lua:150–160` clears `powerSurge` and calls `OnPowerOff()` unconditionally when the surge expires. The current beta/CBM version at lines 154–163 adds a battery check, but still does not check normal power.

`Observatory:OnPowerOff()` then calls `CancelDistressBeacon()`. Infantry Portals also have a consequential power-off callback that requeues their pending player; that is another affected consumer worth checking, although this reproduction exercises the Observatory.

A potential fix would be to base callbacks on transitions in the structure's effective power state, accounting for normal power, Power Surge, and the CBM battery where applicable. Ending a surge while `GetIsPowered()` remains true should not generate a power-loss event. The corresponding power-on behavior may be worth reviewing for the same transition principle.

Relevant beta source:
- [Power Surge expiration](https://github.com/GhoulofGSG9/ns2-game/blob/bc7bb36d54d0ab5f63ee1aaf3ecf046f2019cdae/ns2/lua/PowerConsumerMixin.lua#L154).
- [Observatory power-off callback](https://github.com/GhoulofGSG9/ns2-game/blob/bc7bb36d54d0ab5f63ee1aaf3ecf046f2019cdae/ns2/lua/Observatory.lua#L489).
- [Beacon cancellation](https://github.com/GhoulofGSG9/ns2-game/blob/bc7bb36d54d0ab5f63ee1aaf3ecf046f2019cdae/ns2/lua/Observatory.lua#L313).
