# Dropped weapon ammo can be consumed while that weapon is full if another weapon needs ammo

**Describe the bug**
A Marine holding a weapon with full reserve ammunition can consume that weapon's dropped ammo pack if another carried weapon is short of reserve ammo.

For example, a Marine with full rifle reserves but depleted pistol reserves can pick up rifle ammo. The pack disappears, yet neither weapon gains ammunition: the rifle is already full, and the pack only refills the active rifle.

This concerns the weapon-specific ammo dropped with a weapon, rather than commander-dropped general ammo packs.

The behavior was reproduced using the actual pickup and ammunition functions in a standalone source test, including vanilla, local CBM release/dev, and Ghoul's beta source. A fresh in-game reproduction has not yet been performed.

**To Reproduce**
Suggested in-game reproduction:
1. Play as a Marine with full rifle reserve ammunition.
2. Fire the pistol and reload it so that its reserve ammunition is below maximum.
3. Switch back to the rifle.
4. Have another Marine drop a rifle containing reserve ammo, creating a rifle-ammo pickup.
5. Walk over the rifle-ammo pickup while keeping the full rifle equipped.
6. Observe whether the ammo pickup disappears without increasing either weapon's ammunition.

The source test uses a rifle at 200/200 reserve ammo, a pistol at 9/40, and a rifle-ammo pickup containing 50 rounds. The pickup is accepted and destroyed; both ammo counts remain unchanged. As a control, filling the pistol reserve too causes the same pickup to be rejected.

**Expected behavior**
A weapon-specific ammo pickup should only be consumed if its matching weapon can receive ammunition. A shortage in an unrelated weapon should not make the pickup eligible.

**Screenshots**
None attached; verification so far is source-level.

**System details:**
- Installed NS2 Build: 344.3521.
- Also reproduced against local CBM 3.5 and CBM dev 3.6 source.
- The relevant behavior remains in the inspected upstream vanilla/CBM branches.

**Additional context**
`WeaponAmmoPack:GetIsValidRecipient()` in `lua/AmmoPack.lua:125–132` first calls the general `AmmoPack:GetIsValidRecipient()`, which accepts a Marine if **any** carried ClipWeapon needs reserve ammo. The subsequent checks establish the active weapon's class and the presence of `ammoPackSize`, but not whether that particular weapon needs ammo.

`WeaponAmmoPack:OnTouch()` only calls `GiveReserveAmmo()` on the active weapon. That method clamps the transfer to the available reserve space. `DropPack:OnUpdate()` nevertheless destroys the pickup after calling `OnTouch()`.

A potential fix would be to validate ammo need on the matching weapon itself. It may also be useful for the pickup path to distinguish a successful transfer from a no-op, so a pack is not consumed when no ammo was accepted. The general commander ammo-pack behavior should retain its ability to refill multiple carried weapons.

Relevant beta source:
- [Recipient validation and weapon-specific pickup](https://github.com/GhoulofGSG9/ns2-game/blob/bc7bb36d54d0ab5f63ee1aaf3ecf046f2019cdae/ns2/lua/AmmoPack.lua#L83).
- [Pickup destruction](https://github.com/GhoulofGSG9/ns2-game/blob/bc7bb36d54d0ab5f63ee1aaf3ecf046f2019cdae/ns2/lua/DropPack.lua#L202).
- [Reserve transfer and ammo-need check](https://github.com/GhoulofGSG9/ns2-game/blob/bc7bb36d54d0ab5f63ee1aaf3ecf046f2019cdae/ns2/lua/Weapons/Marine/ClipWeapon.lua#L321).
