# Timed text and voice mutes remain active after their expiry during the current session

**Describe the bug**
The mute system assigns an expiry time six hours after muting a player, but its active in-memory mute state is not expired consistently.

Text mute queries continue to return true after the stored `targetTime`. Voice mute state likewise remains set, and the expiry path does not send an unmute message to the server. Saving/loading persistent mutes filters expired entries, so the persistent-file handling and current-session behavior disagree.

This was reproduced by running the actual `Chat.lua` functions with a controlled clock and a recorded network-message interface. It was not tested through a six-hour live game session.

**To Reproduce**
Suggested in-game verification:
1. Mute another player's text and voice through the scoreboard.
2. Keep the same client session active until the mute's six-hour expiry has passed, without manually toggling the mute.
3. Check whether text remains hidden and the player remains voice-muted.

Source-level reproduction:
1. At time T, call the normal text and voice mute setters.
2. Advance the test clock to T + six hours + one second.
3. Call the text-mute getter and the voice-channel/mute queries.
4. Observe that text and voice mute state remain true and that no voice-unmute message is sent.
5. Explicitly unmuting still works, confirming that the missing transition is automatic expiry.

**Expected behavior**
If `targetTime` defines when a mute expires, text and voice mutes should stop applying after that time in the current session as well as after persistent state is reloaded.

If the intended design is instead to keep mutes for the entire connection and only limit persistence between sessions, that distinction should be made explicit; the current timestamp handling suggests timed expiration.

**Screenshots**
None attached; verification so far is source-level.

**System details:**
- Installed NS2 Build: 344.3521.
- The same `Chat.lua` blob is present in all six inspected Ghoul NS2 branches.
- Local CBM release/dev and the inspected public CBM branches inherit this chat path.

**Additional context**
In `lua/Chat.lua`:
- Line 23 sets the six-hour duration.
- Lines 130 and 151 store voice/text expiry times.
- `ChatUI_GetSteamIdTextMuted()` at lines 156–162 checks the mute flag but never checks `targetTime`.
- `ChatUI_GetClientMuted()` at lines 135–136 returns the cached voice flag.
- `ChatUI_GetVoiceChannelForClient()` at lines 87–100 reapplies still-valid persistent voice mutes, but has no corresponding expired-mute cleanup/unmute path.
- Save/load processing does check expiry.

The voice network message contains a client index and a boolean, not an expiry timestamp, so the server is not given the information needed to expire that mute independently.

A potential fix would be a shared expiry check for active mute queries, clearing expired entries and sending the corresponding voice-unmute update when required. Keep explicit manual unmute behavior and persistence consistent with that check.

Relevant source:
- [Mute storage, expiry handling, and queries](https://github.com/GhoulofGSG9/ns2-game/blob/bc7bb36d54d0ab5f63ee1aaf3ecf046f2019cdae/ns2/lua/Chat.lua#L23).
- [Text mute query](https://github.com/GhoulofGSG9/ns2-game/blob/bc7bb36d54d0ab5f63ee1aaf3ecf046f2019cdae/ns2/lua/Chat.lua#L156).
