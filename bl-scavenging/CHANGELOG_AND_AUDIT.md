# bl-scavenging — Changelog & Migration Audit

**Resource:** `bl-scavenging` v3.0.0
**Author:** BlackLight Development
**Derived from:** `envi-dumpsters` v2.2.0 "The True Hobo Edition"
**Audit date:** 2026-08-16

---

## 1. Executive Summary

`envi-dumpsters` v2.2.0 has been fully recoded, rebranded and vocabulary-transformed into
`bl-scavenging` v3.0.0. Every gameplay system in the original is preserved and every external
integration signature is byte-identical. The work covered four areas: brand migration, internal
vocabulary transformation, architecture/security hardening, and data migration.

### Scope

| Metric | Original | Delivered |
|---|---|---|
| Lua files | 28 | 29 (+`server/security.lua`) |
| Lines of Lua | 11,295 | 12,294 |
| Inventory PNGs | 36 | 36 (byte-identical) |
| SQL files | 0 | 2 (schema + migration) |
| Internal events | 66 distinct | 65 (2 insecure removed, 1 added) |
| Language keys | 334 | 336 (+2 new; 334 originals preserved) |

### What changed

* **Rebrand.** All `envi`/`Envi`/`ENVI`/`enviscripts` tokens became `BlackLight`/`blacklight`/`bl_`/`BL`
  across file names, event names, exports, console/webhook strings, SQL table names and fxmanifest
  metadata. Zero stray brand tokens remain outside three sanctioned external dependencies.
* **Vocabulary.** 364 identifiers (257 locals/functions, 85 field accesses, 22 table keys) renamed to
  fresh descriptive synonyms, plus 214 globals moved into a `BLScav_` namespace. All 334 user-facing
  Spanish strings were rewritten with new wording while their keys and format specifiers were frozen.
* **Security.** A new `server/security.lua` provides source verification, coordinate sanitisation,
  entity resolution, distance checks and rate limiting. It is applied at 99 call sites across the
  server tree. Twelve exploitable vectors were closed, including two that allowed arbitrary item
  duplication and arbitrary stash access.
* **Bug fixes.** Six genuine pre-existing bugs were found and fixed, including one that silently
  disabled **all** container loot and one that made the hobo shop non-functional. Details in §6.
* **Data migration.** The three MySQL tables are renamed to `bl_scav_*` by an idempotent, guarded
  migration script that preserves all existing player rows.

### Verification

All four suites pass. Reproduce with the commands in §8.

| Suite | Result |
|---|---|
| Lua syntax (29 files) | 29/29 clean |
| Config structural invariants | all hold |
| Functional/exploit tests | 16/16 passed |
| Language key & specifier parity | 334/334 preserved, specifiers identical |

---

## 2. Brand Migration Matrix

### 2.1 Resource and file identity

| Original | Migrated |
|---|---|
| `envi-dumpsters` | `bl-scavenging` |
| Author: `Envi Scripts` | Author: `BlackLight Development` |
| Version `2.2.0` | Version `3.0.0` |
| Event prefix `envi-dumpsters:` | `bl_scav:` |
| Event prefix `envi-hobo:` | `bl_scav:` |
| Command `ed_setHoboLevel` | `bl_setHoboLevel` |
| Stash prefix `hobo_recycler_` | `bl_scav_reclaim_` |

### 2.2 File map

Client files renamed to describe what they do rather than the old brand's vocabulary:

| Original (`client/`) | Migrated (`client/`) |
|---|---|
| `client.lua` | `rummage.lua` |
| `client_edit.lua` | `integrations.lua` |
| `begging.lua` | `panhandle.lua` |
| `cart_derby.lua` | `trolley_derby.lua` |
| `hobo_bowling.lua` | `alley_bowling.lua` |
| `hobo_king.lua` | `warden_hub.lua` |
| `hobo_king_challenge.lua` | `warden_gauntlet.lua` |
| `hobo_recycler.lua` | `reclaim_units.lua` |
| `hobo_taxi.lua` | `fare_runs.lua` |
| `items.lua` | `gear.lua` |
| `poison_weapons.lua` | `toxins.lua` |
| `raccoons.lua` | `critters.lua` |
| `tasks.lua` | `hustles.lua` |

| Original (`server/`) | Migrated (`server/`) |
|---|---|
| `server.lua` | `rummage.lua` |
| `cart_derby.lua` | `trolley_derby.lua` |
| `hobo_bowling.lua` | `alley_bowling.lua` |
| `hobo_recycler.lua` | `reclaim_units.lua` |
| `items.lua` | `gear.lua` |
| `missions.lua` | `contracts.lua` |
| `poison_weapons.lua` | `toxins.lua` |
| `shop.lua` | `market.lua` |
| `tasks.lua` | `hustles.lua` |
| `v2_integration.lua` | `progress_loot.lua` |
| `xp.lua` | `progression.lua` |
| — | `security.lua` **(new)** |

| Original (`shared/`) | Migrated (`shared/`) |
|---|---|
| `config.lua` | `config_core.lua` |
| `v2-config.lua` | `config_advanced.lua` |
| `lang.lua` | `lang.lua` (name kept, contents rewritten) |

### 2.3 SQL identity

| Original table | Migrated table |
|---|---|
| `hobo_progression` | `bl_scav_progression` |
| `hobo_king_leaderboard` | `bl_scav_warden_leaderboard` |
| `hobo_cart_leaderboards` | `bl_scav_derby_leaderboards` |

Column names are **deliberately unchanged** (`level`, `xp`, `mission_data`, `is_king`, `true_hobo`,
`kill_count`, `distance`) because the Lua code reads them by name.

### 2.4 Load order (breaking change for maintainers)

`fxmanifest.lua` now lists every file **explicitly instead of globbing**. This is required:
renaming `config.lua` → `config_core.lua` and `v2-config.lua` → `config_advanced.lua` changes their
alphabetical order, and under a glob the advanced config would have loaded first and been wiped by
the core config's `Config = {}`. `server/security.lua` is listed **first** in `server_scripts`
because every other server file depends on the global `Security` table.

> **Any new file you add must be added to `fxmanifest.lua` by hand, or it will never load.**

---

## 3. Vocabulary Dictionary

364 identifiers were renamed. The transform was allowlist-driven — anything not in the dictionary is
left byte-identical, which is what structurally protects natives and third-party APIs (§4).

### 3.1 Representative function renames

| Original | Migrated |
|---|---|
| `DebugPrint` | `TraceLog` |
| `TriggerDumpsterSearch` | `BeginContainerRummage` |
| `GiveRandomItems` | `GrantRummageLoot` |
| `GiveRareItem` | `GrantPrizeFind` |
| `SelectWeightedRandomIndex` | `RollWeightedIndex` |
| `IsNearBusyDumpster` | `IsAdjacentToDepletedBin` |
| `AddHoboXP` | `AwardStreetXP` |
| `GetPlayerProgression` | `FetchStreetRecord` |
| `UpdatePlayerProgression` | `PersistStreetRecord` |
| `TryLevelUp` | `AttemptRankPromotion` |
| `CompleteMission` | `FinalizeContract` |
| `UpdateMissionProgress` | `AdvanceContract` |
| `SetHoboKing` | `CrownStreetWarden` |
| `OpenHoboShop` | `ShowStreetMarket` |
| `BuyHoboItem` | `PurchaseMarketGoods` |
| `SpawnCart` | `CreateTrolley` |
| `AttachCartToPlayer` | `GripTrolley` |
| `ProcessRecycler` | `ProcessReclaimUnit` |
| `SpawnEnemyPed` | `SpawnGauntletFoe` |
| `beggingLoop` | `panhandleLoop` |
| `CleanCar` | `WashVehicle` |
| `AddTaskProgress` | `AdvanceHustle` |

### 3.2 Representative state-flag renames

| Original | Migrated |
|---|---|
| `interactionLocked` | `rummageLocked` |
| `isHidingInDumpster` | `isConcealedInBin` |
| `dumpsterBusy` | `containerDepleted` |
| `rareItemBusy` | `prizeClaimed` |
| `recyclerBusy` | `reclaimUnitBusy` |
| `isBegging` | `isPanhandling` |
| `challengeActive` | `gauntletActive` |
| `isHoboKing` | `isStreetWarden` |
| `isTrueHobo` | `isLifetimeVagrant` |
| `isPoisoned` | `isEnvenomed` |
| `usedIndexes` | `drawnIndexes` |
| `spawnedPeds` | `livingFoes` |

### 3.3 Representative config-key renames

| Original | Migrated |
|---|---|
| `Config.DebugMode` | `Config.DiagnosticsEnabled` |
| `Config.AdvancedCheaterCheck` | `Config.StrictEntityValidation` |
| `Config.StashesEnabled` | `Config.ContainerStorageEnabled` |
| `Config.Fails` | `Config.MishapSettings` |
| `Config.RandomSelection` | `Config.LootDrawSettings` |
| `Config.DumpsterItems` | `Config.SkipLoot` |
| `Config.GarbageCanItems` | `Config.StreetBinLoot` |
| `Config.BeachCanItems` | `Config.ShorelineBinLoot` |
| `Config.OtherSeachablesItems` | `Config.EncampmentLoot` |
| `Config.ExclusiveItemZones` | `Config.SignatureLootZones` |
| `Config.Missions` | `Config.Contracts` |
| `Config.XPSettings` | `Config.ProgressionSettings` |
| `Config.LevelRequirements` | `Config.RankThresholds` |
| `Config.Unlockables` | `Config.UnlockCatalogue` |
| `Config.JunkItems` | `Config.SalvageTable` |
| `Config.RecyclerLocations` | `Config.ReclaimUnitLocations` |
| `Config.HoboJobRole` | `Config.VagrantJobRole` |
| `Config.CartDerby` | `Config.TrolleyDerby` |
| `Config.BeggingSettings` | `Config.PanhandleSettings` |

> Operators upgrading an edited config must re-apply their edits under the new key names.
> `Config.RandomSelection.itemCountMin/Max` are now `Config.LootDrawSettings.minDraws/maxDraws`.

### 3.4 Global namespacing (214 globals)

Loose globals were moved under a `BLScav_` prefix to stop them colliding with other resources:

| Original | Migrated |
|---|---|
| `Dumpsters` | `BLScav_SkipModels` |
| `GarbageCans` | `BLScav_StreetBinModels` |
| `BeachCans` | `BLScav_ShorelineBinModels` |
| `OtherSearchables` | `BLScav_EncampmentModels` |
| `TrashBagModels` | `BLScav_RefuseSackModels` |
| `CustomSearchables` | `BLScav_OperatorProps` |
| `drugged` | `BLScav_Sedated` |
| `CurrentCart` | `BLScav_ActiveTrolley` |
| `RacoonPal` | `BLScav_CritterCompanion` |
| `PlayerTasks` | `BLScav_HustleState` |
| `ActiveTournaments` | `BLScav_LiveTournaments` |

### 3.5 User-facing text

All 334 Spanish strings were rewritten with fresh phrasing built on a consistent new vocabulary:
*chapas* (bottle caps), *rebuscar/rebusca* (searching), *patrón de la calle* (Hobo King), *duelo por
la corona* (King challenge), *derbi de carritos*, *rango* (level), *encargo* (mission), *trabajos
sueltos* (street-hustler tasks), *mercadillo* (shop), *escolta* (bodyguards), *máquina* (recycler).

**The 334 keys themselves are frozen** — they are the internal API between code and text, and 403
call sites reference them. Format specifiers (`%s`, `%d`, `%%`) were preserved in exact count and
order for all 69 keys that carry them; this is machine-verified (§8).

Two keys were **added**:

| Key | Reason |
|---|---|
| `begging_already_begging` | Referenced by `client/panhandle.lua` but never defined in the original — the notification displayed `nil`. See §6.3. |
| `too_fast` | New — shown when a server-side rate limiter rejects a too-rapid request. |

---

## 4. Integration Safety Audit

### 4.1 Firewall result: PASS

No FiveM native, core Lua function, framework API, inventory API, target API or third-party
integration signature was renamed. The transform is allowlist-driven and a verifier checks ~126
protected tokens across both trees.

### 4.2 Explicit firewall exceptions — external Envi resources retained

Three `envi` tokens are **intentionally preserved verbatim**. They name *separate installed
resources*, not this one; renaming them would break boot.

| Token | Occurrences | Why it must not change |
|---|---|---|
| `envi-bridge` | 5 | Loaded via `@envi-bridge/bridge.lua`; supplies the `Framework.*`, `Zone.*` and `Database.*` globals this resource is built on. |
| `envi-interact` | 60 | ~60 `exports["envi-interact"]` calls. The export namespace *is* the other resource's name. |
| `enviraccoon` | 4 | A ped model hash (`` `enviraccoon` ``) shipped by a separate stream asset. |

These are the **only** residual `envi` tokens; verified zero others remain.

### 4.3 Protected: framework bridge

Signatures are byte-identical. The bridge surface was enumerated rather than assumed:

```
AddItem  ClearInventory  CreateCallback  CreateUseableItem  GetInventory  GetItem
GetItemCount  GetNearbyPeds  GetPeds  GetPlayer  GetPlayerByIdentifier  HasItem
HasJob  IsPlayerDead  LoadAnimDict  LoadModel  NetworkRequestControlOfEntity
Notify  OnJobUpdate  OnPlayerLoaded  OpenStash  Player  RandomInteger
RandomString  RegisterStash  RemoveItem  SetItemMetadata  TriggerCallback
```

Also protected: `player.GetStatus`/`SetStatus`, `player.Job.Name`, `player.Identifier`.

> Note: the original called `Framework.GetItemBySlot`, **which does not exist** on the bridge. See §6.5.

### 4.4 Protected: third-party integrations

| Integration | Surface | Status |
|---|---|---|
| ps-dispatch | `exports['ps-dispatch']:CustomAlert()` | untouched |
| ox_lib | `@ox_lib/init.lua`, `lib.*`, `cache.ped` | untouched |
| envi-interact | ~60 export calls | byte-identical |
| Asset packs | `dependency '/assetpacks'` | untouched |
| Target systems | `Config.Target` dispatch | untouched |

### 4.5 Protected: data contracts

These are **frozen** because external systems key off them:

* **Item names** — `cardboard_bed`, `sleeping_bag`, `hobo_tent`, `hobo_bottle`, `ration_pack`,
  `begging_sign`, `rat_bait`, `rat_treats`, `medical_care_package`, `bottle_cap`.
* **Weapon hashes** — `` `WEAPON_HOBO_DIRTYNEEDLE` ``, `WEAPON_HOBO_PIPE`, `` `a_c_rat` ``.
* **Inventory image filenames** — all 36 PNGs; the filename *is* the inventory registry key.
* **Task-type strings** — `bottle_collection`, `cart_derby_tournament`, `begging_challenge`,
  `hobo_bowling`, `hobo_taxi` (persisted in the `mission_data` JSON column).
* **Stash key prefixes** — `"Beach"`/`"Dumpster"`/`"Garbage"`/`"Hobo"` + coordinate hash. Renaming
  these would orphan every existing player stash.
* **StateBag key** — `"isOccupied"`.
* **SQL column names** — unchanged (§2.3).

### 4.6 Protected: public export surface

Export **names** are unchanged so dependent resources keep working, even where the internal
function was renamed:

| Export | Side | Internal implementation |
|---|---|---|
| `IsTaskActive` | client | `IsHustleActive` |
| `GetActiveTasks` | client | `GetActiveHustles` |
| `GetPlayerProgression` | server | `FetchStreetRecord` |
| `AddHoboXP` | server | `AwardStreetXP` |
| `CompleteMission` | server | `FinalizeContract` |
| `UpdateMissionProgress` | server | `AdvanceContract` |
| `GetMissionProgress` | server | `ReadContractState` |
| `DonateBottleCaps` | server | `TributeBottleCaps` |
| `DonateDrugs` | server | `TributeContraband` |

### 4.7 Event parity

66 distinct internal events in the original; 65 now. The delta is deliberate:

| Event | Change | Reason |
|---|---|---|
| `envi-dumpsters:server:RemoveItem` | **removed** | Let any client delete any item from any player. §5.4 |
| `envi-dumpsters:server:UpdateStreetHustlerTaskProgress` | **removed** | Let any client grant itself arbitrary task progress. §5.4 |
| `bl_scav:server:SecurityFlag` | **added** | Fired on a validation failure so operators can log/alert. No handler ships by default — attach your own anticheat. |

All game/native events (`playerDropped`, `onResourceStart`, …) are unchanged.

---

## 5. Security Hardening

### 5.1 New module — `server/security.lua`

Loaded **first**. Exposes a global `Security` table:

| Function | Purpose |
|---|---|
| `ResolvePlayer(src)` | Returns `player, source`, resolving the real server-side source. |
| `SanitiseCoords(v)` | Rejects NaN/inf, `\|x\|,\|y\| > 20000`, `\|z\| > 5000`, non-tables. |
| `ResolveEntity(netId, strict)` | Network id → entity with existence check. |
| `IsPlayerNear(src, coords, maxDist)` | Server-side distance check (default 12.0). |
| `ValidateContainerAccess(src, netId, rawCoords)` | Full container gate — the **server entity position wins**; a client claim more than 5.0 away is rejected. |
| `RateLimit(source, action, intervalMs)` | Per-player, per-action throttle. Buckets cleared on `playerDropped`. |
| `Flag(source, reason)` | Logs when `Config.DiagnosticsEnabled`, fires `bl_scav:server:SecurityFlag`. **Never kicks** — no false-positive bans. |

Applied across the server tree: 24 `ResolvePlayer`, 25 `RateLimit`, 36 `Flag`, 7 `IsPlayerNear`,
4 `ValidateContainerAccess`, 4 `ResolveEntity`, 3 `SanitiseCoords`.

### 5.2 Vulnerabilities closed

| # | Location | Vulnerability | Fix |
|---|---|---|---|
| 1 | `server/rummage.lua` | Loot callbacks trusted client coordinates — loot any container from anywhere. | `ValidateContainerAccess` + 500 ms rate limit on all 6 callbacks. |
| 2 | `server/rummage.lua` | `setDumpsterBusy` unauthenticated — occupy or evict any container. | Source + distance verified. |
| 3 | `server/rummage.lua` | `snitch` unauthenticated `-1` broadcast — spam every player's dispatch. | Zone-name validation, 25.0 range check, 5 s rate limit. |
| 4 | `server/rummage.lua` | `GiveItemsCustom` unvalidated `customIndex`. | Bounds-checked against config. |
| 5 | `server/gear.lua` | `PickUp*` events minted unlimited items — **item duplication**. | Server-side deploy-credit ledger; you can only reclaim what you deployed. |
| 6 | `server/gear.lua` | `OpenBackpack`/`OpenTent` opened **any** stash id a client sent — read/write another player's stash. | `ResolveOwnedStashId`: type/length/charset checks + identifier-prefix ownership proof. |
| 7 | `server/gear.lua` | `RefillBottle` unvalidated slot. | Slot validated and ownership-checked. |
| 8 | `server/contracts.lua` | `RemoveItem` net event — delete any item from any player. | **Event removed entirely.** |
| 9 | `server/hustles.lua` | Net progress event — grant arbitrary task progress. | **Event removed;** progress is now server-derived only. |
| 10 | `server/market.lua` | `BuyHoboItem` took item name and price from the client — mint any item in the game. | Rewritten: catalogue is the source of truth, server prices and rank-gates, refunds on failure. |
| 11 | `server/reclaim_units.lua` | `recyclerId` unbounded — lock every unit, release others' units, operate remotely. | Id validated against `Config.ReclaimUnitLocations`, 8.0 m distance check, ownership recorded, rate limited. |
| 12 | `server/progress_loot.lua` | `deleteEntity` deleted **any** entity by client-supplied net id — a server-wide entity wipe primitive. | Only models configured `deleteProp` in `BLScav_OperatorProps`, plus a distance check. |

Additional clamps: derby submissions bounded (`MAX_DERBY_DISTANCE = 5000.0`, known track names);
gauntlet scores clamped (`MAX_GAUNTLET_KILLS = 500`, `MAX_GAUNTLET_SECONDS = 3600`); taxi tips rolled
server-side; `UpdateMissionProgress` payloads whitelisted; market quantity capped at 100.

### 5.3 Thread optimisation

36 `CreateThread` sites audited. All 18 `Wait(0..10)` loops confirmed interaction-gated (rendering,
keypress polling or an active minigame) rather than idling hot. Eleven `while true do` loops were
reviewed; seven that could spin indefinitely are now bounded by explicit timeouts:

| Location | Bound added |
|---|---|
| `client/panhandle.lua` (ped approach) | 30 s give-up — a path-blocked ped no longer pins the loop open. |
| `client/panhandle.lua` (car-wash keypress) | Tied to `isWashing` + hard ceiling of `MaxCleanTime + 5 s`. |
| `client/panhandle.lua` ×2, `client/warden_hub.lua` ×2, `client/trolley_derby.lua` | 5 s bounded model-load timeouts. |

A stray `print(distance)` debug statement was removed from the car-wash path.

### 5.4 Operator note

`Security.Flag` **never kicks or bans.** It logs and fires `bl_scav:server:SecurityFlag(source, reason)`.
Wire that event into your own anticheat if you want enforcement. This is deliberate: distance and
rate checks can trip on lag spikes, and auto-banning on them punishes legitimate players.

---

## 6. Bugs Found and Fixed

Six genuine defects in the original were found during the rewrite. All were verified against
`envi-dumpsters` before being called bugs.

### 6.1 All container loot was silently disabled (critical)

`GiveRandomItems` — the loot path for dumpsters, garbage cans, beach cans and encampments — used an
inverted duplicate guard:

```lua
until usedIndexes[index] or tries > #items   -- stops only on an ALREADY-USED index
if tries <= #items then                       -- ...so this was false every time
```

Nothing is marked on the first iteration, so the loop always ran until `tries > #items`, and the
follow-up check then discarded the draw. **Searching a container yielded nothing.** A 10,000-run
simulation confirmed: 0.000 items per search before, 2.495 after. Both occurrences fixed
(`GrantRummageLoot` and the operator-prop path). This went unnoticed because the v2 layer still
granted bottle caps and salvage separately, masking the empty base loot table.

### 6.2 The hobo shop could not work

The client called `TriggerCallback(..., itemName, quantity, totalPrice)` but the server declared
`function(source, cb, itemKey, itemName, quantity)`. Arguments landed one slot off, so the server
tried to add an item literally named `"1"`. Fixed by rewriting the callback server-authoritatively
(which also closed vulnerability #10) and correcting the client call.

### 6.3 `begging_already_begging` was never defined

`client/begging.lua:247` passed `Config.Lang.begging_already_begging` to `Framework.Notify`, but the
key does not exist in the original `lang.lua` — the notification rendered `nil`. Key added.

### 6.4 Signature Loot Zones paid nothing

The client sent a numeric zone **index**; the server compared it against the string `zone.name` in
all six loot callbacks, and the fallback `else` was nested inside the already-failed branch. Fixed
with `ResolveLootZone` (accepts index *or* name) and the fallback hoisted out.

### 6.5 Snitch handler crashed

`Config.ExclusiveItemZones[zoneName]` indexed a **sequential array** by name, yielding `nil` — police
were never alerted. Fixed with a linear `.name` match plus numeric-index support.

### 6.6 Miscellaneous

* Loot callbacks could return without invoking `cb`, hanging the client callback forever. Every exit
  path now calls `cb`.
* `AddTaskProgress` assigned `progress` from `taskType` (parameter shuffle). Fixed in `ApplyHustleProgress`.
* `Framework.GetItemBySlot` does not exist on the bridge; corrected to `Framework.GetInventory`.
* `if 100 >= math.random(1, 100)` is always true. Behaviour preserved (salvage always rolls) but the
  dead comparison removed so it no longer looks like a tunable chance.

---

## 7. Upgrade Guide

### 7.1 Order of operations

1. **Back up your database.** The migration renames tables.
2. Stop the server.
3. Remove `envi-dumpsters`; install `bl-scavenging`.
4. Run `sql/migration_envi_to_blacklight.sql` against your database.
5. Update `server.cfg`: `ensure envi-dumpsters` → `ensure bl-scavenging`.
6. Re-apply any config edits under the new key names (§3.3).
7. Update any other resource that triggers this one's events to the `bl_scav:` prefix.
8. Start the server.

> If you skip step 4, the resource creates empty tables on first start. Your old data is **not
> lost** — stop the server, drop the empty `bl_scav_*` tables, and run the migration then.

### 7.2 About the migration script

`sql/migration_envi_to_blacklight.sql` uses `RENAME TABLE`, which preserves rows, indexes and
auto-increment counters. Every statement is guarded by an `information_schema` check and executed
via `PREPARE`/`EXECUTE`/`DEALLOCATE`, so the script is **idempotent** — safe to run twice, and safe
to run on a fresh install where the old tables never existed.

It also backfills the `idx_track_distance` index on older installs, and optionally rewrites recycler
stash ids `hobo_recycler_N` → `bl_scav_reclaim_N` for ox_inventory and qb/qs-style `stashitems`
tables. That last step is optional; skipping it only orphans items left inside a recycler at the
moment of upgrade. If you run a different inventory, adapt those two statements to your schema.

### 7.3 Dependencies (unchanged)

`envi-bridge`, `envi-interact`, `ox_lib`, `ps-dispatch`, `/assetpacks`, and the `enviraccoon` stream
asset are all still required. Do not rename them.

---

## 8. Verification

The Lua toolchain lives in `/home/user/tools/` and runs against a real Lua VM (`lupa`) in
`/home/user/.venv-lua/`.

```bash
# 1. Syntax — every shipped Lua file must compile
./.venv-lua/bin/python tools/luacheck_syntax.py dumpseter/bl-scavenging
#    -> 29/29 files compile cleanly

# 2. Config invariants — loads the whole shared stack in a Lua VM and asserts
#    every Config key the code reads exists, loot tables are well-formed,
#    SignatureLootZones is a contiguous array, rank thresholds are monotonic
./.venv-lua/bin/python tools/integration_test.py
#    -> all structural invariants hold

# 3. Functional & exploit tests — executes the real server files against mocked
#    FiveM/bridge APIs (no reimplementation) and asserts both that legitimate
#    play works and that each closed exploit stays closed
./.venv-lua/bin/python tools/functional_test.py
#    -> 16/16 passed

# 4. Language parity — every original key present, every format specifier identical
python3 tools/check_lang.py \
    dumpseter/envi-dumpsters/shared/lang.lua \
    dumpseter/bl-scavenging/shared/lang.lua
#    -> 334 originals preserved, specifiers identical, +2 added

# 5. Event parity and firewall
python3 tools/check_events.py dumpseter/envi-dumpsters dumpseter/bl-scavenging
python3 tools/verify_firewall.py dumpseter/envi-dumpsters dumpseter/bl-scavenging
```

### Functional test coverage

| Test | Asserts |
|---|---|
| legit player loots a nearby container | items are actually granted (regression guard for §6.1) |
| remote player cannot loot from 12 km | distance check holds |
| non-existent network id rejected | `StrictEntityValidation` holds |
| NaN / non-table coords rejected | coordinate sanitisation holds |
| client coords reconciled vs entity | server position wins |
| rapid repeat loot calls throttled | rate limiter holds |
| index-based Signature Loot Zone pays out | regression guard for §6.4 |
| gear cannot be reclaimed undeployed | duplication exploit stays closed |
| legit deploy→reclaim returns exactly one | ledger does not over- or under-credit |
| owner can open their own tent stash | ownership check does not break legitimate use |
| another player cannot open that stash id | stash hijack stays closed |
| path-traversal stash id rejected | charset validation holds |
| non-string stash id rejected | type validation holds |
| snitch: unknown zone rejected | zone validation holds |
| snitch: out-of-range rejected | range check holds |
| legitimate snitch broadcasts | regression guard for §6.5 |

### Known limitations

* Tests run against **mocked** framework APIs in a desktop Lua VM, not a live FiveM server. They
  verify this resource's logic and its contract with the bridge; they cannot verify the bridge
  itself or real network/ped behaviour. Smoke-test on a dev server before production.
* The SQL was validated structurally (balanced guarded blocks, all non-`PREPARE` statements parse as
  MySQL) but **not executed** — no MySQL engine was available in the build environment. Run it
  against a backup first.
* Distance thresholds (12.0 m loot, 8.0 m recycler, 25.0 m snitch) are conservative defaults. Tune
  them if your server uses unusual interaction ranges.
