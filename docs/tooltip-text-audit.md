# Commander tooltip text audit

Planning only: nothing here is implemented yet. Branch `feature/tooltip-text-audit`, a candidate for a
release after 1.06. First pass reviewed with the user on 2026-09-15.

The full review, with today's text, what the code does and the proposed text per row, is
[tooltip-audit.html](tooltip-audit.html) (also published as a private artifact,
https://claude.ai/artifact/J293NPGx4kzuTL2eHw9MKT). `tools/extract_tooltips.lua` dumps every tech
entry with a tooltip and its English text, for vanilla or for a merged CBM tree.

## Decisions

- **Scope:** every written tooltip a commander sees, in vanilla and CBM dev. CBM's own rewritten text
  is corrected too, except where noted (M10).
- **Length:** a rewrite may be at most one line longer than today's text, counted at the tooltip's
  37-character wrap width.
- **Live numbers:** figures are read from the running game, like the stat row, so CBM, B2TP and other
  balance mods show their own values.
- **Distances** are rounded to whole meters (Rupture's 8.7 m shows as 9 m).
- **Multipliers** are written x2.5, not 2.5x.
- **Fire labels** are a red line of their own under the description, outside the one-line budget.
- **Mechanism (planned):** replace the text through `Locale.substitutions`, the same route CBM uses
  (`core/lua/Locale.lua`, `CommunityBalanceMod/Locale.lua`), without touching game files. Ruleset
  detection for rows that differ: CBM sets `kCBMaddon = true` in its Balance.lua.
- **Still open:** one term for fire across rows and labels, "burning" or "on fire".

## Fire, as the code has it

Two separate properties:

- **Flammable** (extra fire damage, `GetIsFlameAble`): any Flame-type damage does x2.5, with direct
  hits doing x5 to cysts and x7 to clogs; burning damage over time is always x2.5. Commander-built:
  Cyst, Egg (every kind). Also Hydra, Clog, Web, Babbler. Contamination and Bone Wall are explicitly
  not flammable. Nothing marine is flammable.
- **Stops while burning** (`GetIsOnFire`): Crag heal and Heal Wave, Shade cloak and Ink, Shift
  energize and Echo, Whip attacks, Hydra attacks, Hive healing, Contamination bile. Burning aliens heal
  at 50% (`kOnFireHealingScalar`). Burning does **not** slow energy regeneration
  (`kOnFireEnergyRecuperationScalar = 1` in both rulesets).
- **Sources:** Flamethrower (ignites), Welder (Flame damage, never ignites), CBM exo flamer.
- **Cluster grenades do NOT ignite** (corrected 2026-09-15; the first pass said they did).
  `ClusterGrenade:BurnEntities` and `:BurnNearbyAbilities` exist but nothing calls them, in vanilla or
  CBM, so no burning and no clearing of spores, umbra or bile. Instead the blast's damage type
  (ClusterFlame) fakes the fire: x0.2 on players and exos, x2.5 on structures (CBM x2.875), and a
  flammable target gets a flat bonus of one flamethrower burn (8/s x 2.1 s = 16.8) times its
  flammable multiplier, added after distance falloff. The 8 fragments (20 each) get the player and
  structure multipliers but no fire bonus. The damage-type comment in DamageTypes.lua ("5x vs
  flammable, 50% player reduction") is stale in both rulesets.

## Approved rows

Text in braces is a live value; a line starting with ! is the red fire label. "v" is vanilla, "c" is
CBM; one line means both.

| ID | Tooltip | Proposed |
| --- | --- | --- |
| M01 | Nano Shield | Target takes {32%} less damage for {3 s} on a player or {5 s} on a structure. |
| M02 | Med Pack | Restores {50} player health: {25} at once, then {25} more over time. |
| M03 | Catalyst Pack | v: For {5 s}: sprint about {20%} faster, and reloads and weapon actions {25%} faster. c: ...reloads, weapon actions and welding {25%} faster. |
| M04 | Scan | Reveals cloaked units and gives sight in a {20 m} radius for {10 s}, anywhere. (not yet commented on) |
| M05 | Drop Flamethrower | Burning alien structures stop their abilities, and burning aliens heal at half rate. !Fire: sets targets alight · extra damage vs flammable |
| M06 | Drop Welder | Repairs Marine and Exo armor and structures. The fastest way to repair power nodes. !Fire damage: extra vs flammable |
| M08 | Drop Mines | Drops {1} proximity mine that deals {130} damage. (Normal damage, so no type named) |
| M09 | Drop Heavy Machine Gun | Machine Gun with a large magazine. Inaccurate at mid-long range. Low base damage against structures, {+50%} against players. |
| M10 | Weapons #1 to #3 | v: Weapons do {10%} more damage (shotgun {7.8%}, grenade launcher and flamethrower {7%}). c: unchanged, CBM's own text (exactly right under B2TP). |
| M11 | Armor #1 to #3 | Gives Marines {20} extra armor and Exos {30}. |
| M12 | Observatory | Reveals cloaked aliens within {22 m}. Casts Distress Beacon. |
| M13 | Sentry Battery (v) | Powers up to {3} sentries within {4 m}. One per room. |
| M14 | Sentry (v) | Automated gun with {20 m} range. Needs a Sentry Battery nearby. |
| M15 | Infantry Portal | Respawns a Marine every {9} seconds. Can only be built near a Command Station. Max {3} per Command Station. |
| A01 | Heal Wave / Shield Wave | v: For {8 s} the Crag nearest your view heals {30%} more. c: For {8 s} the nearest Crag shields aliens within {14 m} each second ({20%} of max health). !Burning Crags can't cast it |
| A02 | Ink | v: Ink cloud around the Shade nearest your view, for aliens to hide in. c: ...around the nearest usable Shade... !Burning Shades can't ink |
| A03 | Bone Wall | Wall for {6 s} that blocks movement and attacks. Gains {100} health per biomass. (CBM {140}) |
| A04 | Contamination | Spreads infestation anywhere for {20 s} and sprays bile {3} times, {2 s} apart. !Burning stops its bile |
| A05 | Nutrient Mist | For {15 s}: structures mature and aliens evolve {66%} faster, and disconnected cysts take no damage. |
| A06 | Rupture | Bursts after {1.25 s}: marines within {9 m} lose vision briefly and are parasited for {10 s}. |
| A07 | Crag · Heal | Every {2 s} heals aliens and structures within {14 m}, about half a Hive's rate. More Crags don't stack. !Burning stops healing |
| A08 | Shade · Cloak | Cloaks alien structures and players within {17 m}. !Burning stops cloaking |
| A09 | Shift · Energize | Aliens within {17 m} gain {15} energy per second. (CBM {7.5}) !Burning stops energize |
| A10 | Whip · Bombard | Lobs {250} corrosive damage ({6 m} splash): full vs structures, armor only on marines. !Burning stops attacks |
| A11 | Mucous Membrane | Aliens within {5 m} get a shield of {20%} max health for {5 s}. (CBM {7.5 m}) |
| A12 | Enzyme Cloud | A {3 s} cloud: aliens inside attack {25%} faster. |
| A13 | Drifter Celerity | Drifters move {18%} faster |
| A14 | Cyst | Today's text unchanged. !Flammable: {x5} fire damage |
| A15 | Egg, lifeform eggs | Today's text unchanged. !Flammable: {x2.5} fire damage |

M07 (Research Hand Grenades) was dropped: left untouched.

## Facts worth keeping

- Commander Heal Wave and Ink pick the structure nearest the commander's camera position, anywhere on
  the map (`AlienCommander.lua` `GetNearest`). CBM's `GetNearestValid` skips unbuilt, consuming and
  burning ones, and needs the matching hive or an Advanced (Fortress) structure.
- Crag heal: no target cap (`Crag.kMaxTargets` is unused). Lifeforms get 10 / 15 / 16 / 25 / 80 per
  2 s, everything else 4.2% of max health (7 to 42). One 2 s timer per target shared by all Crags.
- Hive heal: players and eggs only, every 1 s, max(10, 8% of max health), 12.7 m. Crag vs Hive per
  second on players: Skulk 5 / 10, Gorge 7.5 / 12.8, Lerk 8 / 14.4, Fade 12.5 / 20, Onos 40 / 56.
- CBM Shield Wave has no extra healing: `Crag:TryHeal` comments out `kHealWaveMultiplier`.
- Nano Shield: 32% for everything; 3 s on players (Exo is a Player), 5 s on structures.
- Weapon upgrades: vanilla 10% (shotgun 7.84%, GL and flamethrower 7%). CBM removes GL and FT from
  the per-weapon tables (so 10% / 20%); B2TP brings the shotgun to 10% / 20%.
- HMG: 7 damage (rifle 10), no structure bonus, x1.5 vs players and exos; spread 3.2° vs rifle 2.8°.
- Cat Pack adds 1.125 m/s to a 5.75 m/s sprint before weight scaling: about 20%.
- Sentries: `kSentriesPerBattery = 3` is counted per room; battery range 4 m.
- Two Crag tooltips: the building (CRAG_TOOLTIP, "Heals and protects nearby friendly units.", build
  menu) and the Heal button on a selected Crag (CRAG_HEAL_TOOLTIP, the one with "max 3 targets"). A07
  is the button; A16 (proposed, not yet approved) is the building: "Heals players and structures
  within {14 m}. Can cast Heal Wave." (CBM: Shield Wave). "Protects" dates from Crag Umbra.
- Shifts don't stack: Energize counts each Shift in range but caps the level at 1
  (`kMaxEnergizeLevel = 1` in EnergizeMixin.lua; CBM uses the same file).

## Not yet checked

Power Surge extras, Distress Beacon, Shift Hatch and Echo, Whip Slap, Drifter Regeneration, Cyst
Camouflage / Celerity / Carapace, vanilla Hallucination Cloud, lifeform research (Leap, Xenocide, Bile
Bomb, Umbra, Spores, Metabolize, Stab, Bone Shield, Stomp, Web), tunnels, Hive, Harvester, chambers,
and everything CBM-only (Advanced Crag / Shift / Shade / Whip and abilities, A-MAC and fields, SPARC,
Cargo Gate, Linked Power Battery, Purification Protocol, SMG, Scan Grenade, Exosuit Core tech,
Advanced Observatory). Then the fire wording pass.

## Idea: flame glyph (user, 2026-09-15)

A small flame icon to mark the fire labels, proposed for 1.07. Not designed yet. Notes for when it is:

- It would lead the red label line ("[flame] Flammable: x5 fire damage"), drawn at the label's text
  height and tinted the label red, so the glyph and the words read as one unit.
- The icon sheet `ui/bleu_tooltip_icons.dds` has 7 cells (448x64): 0 hourglass, 1 stopwatch,
  2 marine speed, 3-6 health, armor, ready, not ready. A flame would be cell 7, widening the sheet to
  512x64. `build_icons.ps1` then needs its protected-cell check bounded to cells 3-6 (it currently
  compares from x = 192 to the end), and the new cell gets the same soft glow recipe as cells 0-2.
- White art like the rest of the sheet, tinted at runtime.
- Open question: whether the "burning stops ..." labels get the flame too, or only flammable targets
  and fire weapons.

## Armory and Prototype Lab buy menu (checked 2026-09-15)

Player-facing, not commander tooltips: `GUIMarineBuyMenu.lua` shows a description (`*_BUYDESCRIPTION`),
hand-set stat bars (`kTechIdStats`, not computed from balance values) and "Special" boxes.

- **Accurate:** Pistol, Rifle, Shotgun, Grenade Launcher (x4 vs structures), Axe (Structural, x2 vs
  structures), Mines, Jetpack, Dual Minigun ("effective against armor": Heavy damage), Gas grenade
  (armor only, alien targets only, players and structures alike), Scan grenade (CBM).
- **Flamethrower + Burn special:** accurate. Burning does disable alien structure abilities, and
  `BurnSporesAndUmbra` does clear spores, umbra, bile bombs and whip bombs.
- **Cluster grenade:** accurate as far as it goes; doesn't mention the flammable bonus (and never
  claims fire, correctly).
- **Welder:** accurate but omits that it deals damage (30/s Flame, x2 vs structures, flammable bonus).
- **HMG:** "long range weapon" vs the commander tooltip's "Inaccurate at mid-long range": the two
  texts contradict. Spread is 3.2° vs the rifle's 2.8°; range 100 m (CBM 41, the relevancy cap).
- **Pulse grenade + Electrify special:** "greatly slowing attack speed" is 20% slower in vanilla (30%
  in CBM). Omits vanilla's 70% energy regen and 50 damage; CBM also electrifies alien structures
  (SetElectrified on Crag, Hive, Hydra, Shade, Shell, Shift, Spur, Veil, Whip) and adds damage over
  time, while "enemy players" says players only.
- **Dual Railgun:** fine in vanilla (charge 140). CBM sets charge damage equal to base (35/35), so
  "massive burst damage" needs a look at CBM's railgun code before judging.
- **Massive special:** egg smashing, knockdown immunity (no StunMixin), spore immunity (no vaporous
  damage) and no Distress Beacon are all true. "Cannot use Phase Gates" is true in vanilla (no
  PhaseGateUserMixin); CBM's Exo does include PhaseGateUserMixin (Cargo Gates), normal gates unchecked.
- **CBM SMG:** 10.5 vs rifle 10 (+5%), melee 30 vs 10, weight 0.05 vs 0.13: accurate; typo "assualt".
- **Stat bars:** identical in CBM although CBM changed GL (65), flamethrower (9) and pulse (15) damage.

**Knock-on for the commander audit:** Drop Exosuit (EXOSUIT_TOOLTIP) says "can be beaconed". False in
vanilla and CBM: `Observatory:GetPlayersToBeacon` only takes `isa("Marine")`, and Exo isn't one.
