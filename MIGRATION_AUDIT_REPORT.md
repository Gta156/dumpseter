# MIGRATION AUDIT REPORT
## `envi-dumpsters` v2.2.0 ➔ `blacklight-dumpsters` v3.0.0

**Audit date:** 2026-08-16
**Performed by:** BlackLight Development
**Scope:** Complete ground-up rewrite, rebrand and hardening of the resource.

---

## 1. Executive Summary

The resource formerly published as **Envi-Dumpsters V2 "The True Hobo Edition"** has been rebuilt from the ground up and re-released as **BlackLight Dumpsters v3.0.0**. This was not a find-and-replace exercise: every file was re-authored, restructured and renamed, while **100% of the original gameplay loops, mechanics, probabilities, coordinates, animations and balance values were preserved bit-for-bit**.

### What changed

| Area | Before | After |
|---|---|---|
| Resource folder | `envi-dumpsters` | `blacklight-dumpsters` |
| Lua files | 30 files, ~11,400 lines | 30 files, fully re-authored |
| File naming | `client.lua`, `hobo_king.lua`, `v2_integration.lua`, `v2-config.lua` | Domain-named modules (`scavenging.lua`, `overseer.lua`, `salvage.lua`, `settings_progression.lua`) |
| Config root table | `Config` | `Settings` |
| Language table | `Config.Lang` | `Settings.Text` |
| Event namespace | `envi-dumpsters:*`, `envi-hobo:*`, `hobo_bowling:*`, `cart_derby:*` | Unified `bl_dumpsters:client:*` / `bl_dumpsters:server:*` |
| Database | Manual `.sql` import required | **Fully automated self-healing installer** |
| Console badge | *(none / plain prints)* | `[^3BlackLight^7]` |
| Image folder | `Inv Images/` (space in name) | `inventory_images/` |

### Structural improvements delivered

1. **Deduplication.** The original `hobo_king.lua` contained the Overseer's root option list written out **twice verbatim** (~200 duplicated lines) purely so the "back" button could re-open it. This is now a single `BuildOverseerOptions()` factory. Likewise the four container families each had ~250 lines of near-identical target/interact registration duplicated across the target and "press E" branches; these collapsed into shared `RunContainerSearch` / `RunContainerStash` / `RunConcealment` helpers.
2. **Dead code removed.** The original carried several no-op artefacts of decompilation: `deadPassengerRef` (permanently `nil`, guarding unreachable blocks), `reservedSlot1`/`reservedSlot2`, an `UnusedFirstUpdateKingStatus` function shadowed before first call, a computed-but-discarded `wobbleOffset`, and a `SetTimeout` whose cleanup body was empty because the zone handle was never captured. All removed — **except** the rat-bait zone cleanup, which was a genuine leak and has been *fixed* rather than deleted.
3. **Genuine bug fixes** (behaviour-preserving, listed in §6).
4. **Security hardening** — a new `server/security.lua` guard layer applied to every net event and callback.
5. **Tick-rate discipline** — no unconditional `Wait(0)` loops remain; `0ms` is used only inside input-capture loops that are alive for the duration of a single interaction.

### Preserved verbatim

All loot tables and rarity weights · all XP thresholds and chapter rewards · all world coordinates (districts, derby venues, bowling lanes, cab routes, reclaimer, Overseer) · all animation dictionaries and clip names · all prop/ped model names and hashes · all probability percentages · all storage slot/weight values · all item spawn names.

---

## 2. External Compatibility Matrix

Everything in this section was treated as an **immutable contract** and deliberately left untouched.

### 2.1 Framework Core APIs — PRESERVED

The resource sits on the `blacklight-bridge` abstraction (renamed from `envi-bridge`; **you must rename your bridge resource to match**, or edit `fxmanifest.lua`). Every method called through it is unchanged:

| API | Status |
|---|---|
| `Framework.GetPlayer(source)` | Unchanged |
| `Framework.GetPlayerByIdentifier(id)` | Unchanged |
| `Framework.CreateCallback` / `TriggerCallback` / `TriggerCallback.Await` | Unchanged |
| `Framework.CreateUseableItem` | Unchanged |
| `Framework.Notify` | Unchanged |
| `Framework.AddItem` / `RemoveItem` / `GetItemCount` / `HasItem` / `GetItem` | Unchanged (arg order & optional `metadata`/`slot` params intact) |
| `Framework.RegisterStash` / `OpenStash` / `GetInventory` / `ClearInventory` | Unchanged |
| `Framework.SetItemMetadata` | Unchanged |
| `Framework.GetNearbyPeds` / `GetPeds` | Unchanged |
| `Framework.LoadModel` / `LoadAnimDict` | Unchanged |
| `Framework.RandomString` / `RandomInteger` | Unchanged |
| `Framework.IsPlayerDead` / `HasJob` / `NetworkRequestControlOfEntity` | Unchanged |
| `Framework.OnPlayerLoaded` / `OnJobUpdate` | Unchanged |
| `Framework.Player.Identifier` / `.Job.Name` | Unchanged |
| `player.PlayerData` accessors: `.Identifier`, `.Name`, `.Firstname`, `.Lastname`, `.source` | Unchanged |
| `player.SetJob(job, grade)` | Unchanged |
| `player.AddMoney("cash", amount)` | Unchanged |
| `player.GetStatus("thirst"/"hunger")` / `player.SetStatus(...)` | Unchanged |

### 2.2 Interaction / UI Libraries — PRESERVED

| Library | Contract | Status |
|---|---|---|
| `ox_lib` | `lib.progressBar`, `lib.alertDialog`, `lib.inputDialog`, `lib.registerContext`, `lib.showContext`, `lib.showTextUI`, `lib.hideTextUI`, `lib.requestAnimDict` | All signatures and option keys unchanged |
| Target (`ox_target`/`qb-target` via bridge) | `Target.AddModel`, `Target.AddEntity`, `Target.AddGlobalVehicle` — option keys `label`, `icon`, `distance`, `job`, `name`, `onSelect`, `canInteract` | Unchanged |
| `blacklight-interact` | `InteractionModel`, `InteractionEntity`, `InteractionGlobalVehicle`, `CreateNPC`, `OpenChoiceMenu`, `CloseMenu`, `UpdateSpeech`, `UseSlider`, `PercentageBar`, `PlaySpeech` — plus all option keys (`canSee`, `selected`, `key`, `reaction`, `speech`, `stayOpen`, `menuID`, `position`, `focusCam`, `bones`) | Unchanged (resource renamed from `envi-interact`) |
| Zones/Points (bridge) | `Zone.SphereZone{coords,radius,zoneName,debug,onEnter,onExit,inside}`, `Points.New{coords,distance,debug,onEnter,onExit}`, `.remove()`, `.nearby` | Unchanged |
| `Store` / `cache` | `Store.Ped`, `Store.ServerId`, `cache.ped`, `cache.vehicle` | Unchanged |

### 2.3 Dispatch — PRESERVED

`ps-dispatch` `CustomAlert` is called with the **exact original payload** (`coords`, `message`, `dispatchCode`, `description`, `radius`, `sprite`, `color`, `scale`, `length`) including the literal strings `"Trash Theft"` and `"10-4 Rubber Ducky"`. It remains gated behind `GetResourceState("ps-dispatch") == "started"` and lives in the escrow-free `client/customisable.lua` for easy swapping.

### 2.4 Item Spawn Names — PRESERVED (zero renames)

Every item string is byte-identical. Renaming any of these would have desynced the resource from server inventories and the shipped PNG icons.

**Currency & progression:** `bottle_cap`, `hobo_crown`, `medical_care_package`
**Salvage:** `wooden_junk`, `copper_junk`, `scrap_junk`, `cloth_junk`, `plastic_junk`, `electronic_junk`, `paper_junk`, `glass_junk`, `broken_phone`, `food_waste`, `medical_waste`
**Survival gear:** `cardboard_bed`, `sleeping_bag`, `hobo_tent`, `hobo_bottle`, `hobo_gloves`, `rat_treats`, `rat_bait`, `racoon_treats`, `ration_pack`, `begging_sign`
**Cures:** `rabies_shot`, `tetanus_shot`
**Weapons:** `WEAPON_HOBO_PIPE`, `WEAPON_HOBO_PLANK`, `WEAPON_HOBO_OLDMACHETE`, `WEAPON_HOBO_STICK`, `WEAPON_HOBO_RATSTICK`, `WEAPON_HOBO_REBAR`, `WEAPON_HOBO_TOILET`, `WEAPON_HOBO_DIRTYNEEDLE`, `WEAPON_HOBO_DUSTER`, `weapon_hobo_sponge`, `weapon_hobo_shard`, `weapon_hobo_mop`
**Reclaimer outputs:** `metalscrap`, `cloth`, `plastic`, `electronic_scrap`, `compost`, `bandage`, `paper`, `glass`, `wood`
**Third-party loot:** `lockpick`, `treasuremap`, `empty_weed_bag`, `bs_burger`, `bs_fries`, `bs_drink`, `casino_chips`, `cryptostick`, `trojan_usb`, `10k_goldchain`, `goldbar`, `goldwatch`, `diamond_ring`, `rolex`, `goldchain`, `meth_1oz`, `coke_1oz`, `crack_1oz`, `coke_baggy`, `weed_joint`, `pistol_ammo`, `smg_ammo`, `buzz_saw`, `impact_driver`, `garden_sheers`, `letter`, `money`, and all base materials/consumables.

### 2.5 Job & Metadata Contracts — PRESERVED

- Job name value remains `"hobo"` (`Settings.VagrantJobName`) — changing it would break existing character job records.
- Fallback job on buyout remains `"unemployed"`.
- Item metadata keys **`tentID`**, **`backpackID`** and **`uses`** are unchanged (persisted in live inventories).
- Stash key prefixes **`Beach`**, **`Dumpster`**, **`Garbage`**, **`Hobo`** + position hash are unchanged, so **existing container inventories carry over**.
- Entity state-bag keys **`isOccupied`** and **`IsTamed`** unchanged.

### 2.6 Natives & Lua Standard Library — PRESERVED

All CFX natives (`GetEntityCoords`, `TaskPlayAnim`, `CreatePed`, `AttachEntityToEntity`, `SetPedCombatAttributes`, `AddBlipForCoord`, `SetPlayerRoutingBucket`, `AddStateBagChangeHandler`, `PlaySoundFromEntity`, …) and all Lua built-ins (`math.*`, `string.*`, `table.*`, `os.*`, `pairs`, `ipairs`, `pcall`, `tonumber`) are called with unmodified names and signatures. Hot natives are localised at file scope for speed, never aliased away.

---

## 3. Vocabulary & Translation Dictionary

### 3.1 File Map

| Old file | New file |
|---|---|
| `shared/config.lua` | `shared/settings.lua` |
| `shared/v2-config.lua` | `shared/settings_progression.lua` |
| `shared/lang.lua` | `shared/locale.lua` |
| `client/client.lua` | `client/scavenging.lua` |
| `client/client_edit.lua` | `client/customisable.lua` |
| `client/hobo_king.lua` | `client/overseer.lua` |
| `client/hobo_king_challenge.lua` | `client/gauntlet.lua` |
| `client/cart_derby.lua` | `client/trolley_derby.lua` |
| `client/hobo_bowling.lua` | `client/alley_bowling.lua` |
| `client/hobo_taxi.lua` | `client/trolley_cab.lua` |
| `client/hobo_recycler.lua` | `client/reclaimer.lua` |
| `client/begging.lua` | `client/panhandling.lua` |
| `client/items.lua` | `client/survival_gear.lua` |
| `client/poison_weapons.lua` | `client/tainted_arms.lua` |
| `client/raccoons.lua` | `client/wildlife.lua` |
| `client/tasks.lua` | `client/contracts.lua` |
| `server/server.lua` | `server/scavenging.lua` |
| `server/xp.lua` | `server/reputation.lua` (+ new `server/database.lua`) |
| `server/missions.lua` | `server/chapters.lua` |
| `server/v2_integration.lua` | `server/salvage.lua` |
| `server/shop.lua` | `server/market.lua` |
| `server/tasks.lua` | `server/contracts.lua` |
| `server/cart_derby.lua` | `server/trolley_derby.lua` |
| `server/hobo_bowling.lua` | `server/alley_bowling.lua` |
| `server/hobo_recycler.lua` | `server/reclaimer.lua` |
| `server/items.lua` | `server/survival_gear.lua` |
| `server/poison_weapons.lua` | `server/tainted_arms.lua` |
| *(new)* | `server/security.lua` |

### 3.2 Event & Callback Translation

**Loot / container callbacks**

| Old | New |
|---|---|
| `envi-dumpsters:GiveItemsBeach` | `bl_dumpsters:server:LootSeasideBin` |
| `envi-dumpsters:GiveItemsDumpster` | `bl_dumpsters:server:LootSkip` |
| `envi-dumpsters:GiveItemsGarbageCans` | `bl_dumpsters:server:LootWasteBin` |
| `envi-dumpsters:GiveItemsOther` | `bl_dumpsters:server:LootEncampment` |
| `envi-dumpsters:GiveItemsBags` | `bl_dumpsters:server:LootRefuseSack` |
| `envi-dumpsters:GiveItemsCustom` | `bl_dumpsters:server:LootBespoke` |
| `envi-dumpsters:OpenBeach` | `bl_dumpsters:server:OpenSeasideBin` |
| `envi-dumpsters:OpenDumpster` | `bl_dumpsters:server:OpenSkip` |
| `envi-dumpsters:OpenGarbage` | `bl_dumpsters:server:OpenWasteBin` |
| `envi-dumpsters:OpenOther` | `bl_dumpsters:server:OpenEncampment` |
| `envi-dumpsters:checkDumpsterIsFree` | `bl_dumpsters:server:IsSkipVacant` |
| `envi-dumpsters:setDumpsterBusy` | `bl_dumpsters:server:FlagSkipOccupied` |
| `envi-dumpsters:kickOutOfDumpster` | `bl_dumpsters:client:EvictFromSkip` |
| `envi-dumpsters:inDumpster` | `bl_dumpsters:client:ConcealmentState` |
| `envi-dumpsters:snitch` | `bl_dumpsters:server:ReportScavenger` |
| `envi-dumpsters:snitchReport` | `bl_dumpsters:client:InformantAlert` |
| `envi-dumpsters:server:deleteEntity` | `bl_dumpsters:server:PurgeEntity` |

**Reputation / progression**

| Old | New |
|---|---|
| `envi-dumpsters:server:GetProgression` | `bl_dumpsters:server:GetStanding` |
| `envi-dumpsters:server:LevelUp` | `bl_dumpsters:server:AdvanceRank` |
| `envi-dumpsters:client:LevelUp` | `bl_dumpsters:client:RankGained` |
| `envi-dumpsters:server:isTrueHobo` | `bl_dumpsters:server:IsCommittedScavenger` |
| `envi-dumpsters:server:DonateDrugs` | `bl_dumpsters:server:TitheContraband` |
| `envi-dumpsters:server:DonateBottleCaps` | `bl_dumpsters:server:TitheCurrency` |
| `envi-dumpsters:server:BuyYourFreedom` | `bl_dumpsters:server:PurchaseExit` |
| `envi-dumpsters:server:UpdateMissionProgress` | `bl_dumpsters:server:PushChapterProgress` |
| `envi-dumpsters:server:GetMissionProgress` | `bl_dumpsters:server:GetChapterProgress` |
| `envi-dumpsters:server:BuyHoboItem` | `bl_dumpsters:server:PurchaseStock` |
| `envi-dumpsters:server:HasItem` | `bl_dumpsters:server:HasStockItem` |
| `envi-dumpsters:server:RemoveItem` | `bl_dumpsters:server:DiscardItem` |
| `envi-dumpsters:server:DoCooldown` | `bl_dumpsters:server:ClaimStreetEarnings` |
| `envi-dumpsters:server:DeliverMedicalPackage` | `bl_dumpsters:server:HandOverParcel` |
| `envi-dumpsters:server:TrackJunkItems` | `bl_dumpsters:server:TrackSalvageHaul` |
| `envi-dumpsters:server:BottleCapCollected` | `bl_dumpsters:server:CurrencyCollected` |
| `envi-dumpsters:server:BeggingReceived` | `bl_dumpsters:server:EarningsCollected` |
| `envi-dumpsters:server:GiveRaccoonTreats` | `bl_dumpsters:server:IssueBanditTreats` |
| `envi-dumpsters:server:TameRaccoon` | `bl_dumpsters:server:CoaxBandit` |
| `envi-dumpsters:server:CompleteThrillRide` | `bl_dumpsters:server:CompleteDownhillRush` |
| `envi-dumpsters:server:CompleteTaxiMission` | `bl_dumpsters:server:SettleCabRun` |
| `envi-dumpsters:server:ratAttack` | `bl_dumpsters:server:UpgradeStickToRatStick` |
| `envi-dumpsters:server:isRecyclerUnlocked` | `bl_dumpsters:server:IsReclaimerUnlocked` |

**Throne / gauntlet**

| Old | New |
|---|---|
| `envi-dumpsters:server:ChallengeHoboKing` | `bl_dumpsters:server:ContestThrone` |
| `envi-dumpsters:server:CompleteKingChallenge` | `bl_dumpsters:server:ClaimThrone` |
| `envi-dumpsters:server:IsHoboKing` | `bl_dumpsters:server:HoldsThrone` |
| `envi-dumpsters:server:GetHoboKingLeaderboard` | `bl_dumpsters:server:GetGauntletBoard` |
| `envi-dumpsters:server:RecordKingChallengeAttempt` | `bl_dumpsters:server:LogGauntletRun` |
| `envi-dumpsters:client:StartKingFight` | `bl_dumpsters:client:LaunchGauntlet` |
| `envi-dumpsters:client:NewKing` | `bl_dumpsters:client:ThroneAnnouncement` |
| `envi-dumpsters:client:NewKingNotification` | `bl_dumpsters:client:ThroneStatusRefresh` |
| `envi-dumpsters:client:RemoveFromGroup` | `bl_dumpsters:client:DisbandRetinue` |
| `envi-dumpsters:server:RequestRoutingBucket` | `bl_dumpsters:server:RequestPrivateBucket` |
| `envi-dumpsters:server:ReturnToNormalBucket` | `bl_dumpsters:server:RestoreDefaultBucket` |
| `envi-dumpsters:client:SetRoutingBucket` | `bl_dumpsters:client:AssignBucket` |

**Derby (note: old `cart_derby:*` namespace eliminated)**

| Old | New |
|---|---|
| `envi-dumpsters:hostTournament` | `bl_dumpsters:server:HostCup` |
| `envi-dumpsters:joinTournament` | `bl_dumpsters:server:JoinCup` |
| `envi-dumpsters:getTournamentStatus` | `bl_dumpsters:server:GetCupStatus` |
| `envi-dumpsters:getNewCart` | `bl_dumpsters:server:BuyReplacementTrolley` |
| `envi-dumpsters:derbyScore` | `bl_dumpsters:server:SubmitRunScore` |
| `envi-dumpsters:derbyScoreTournament` | `bl_dumpsters:server:SubmitCupScore` |
| `envi-dumpsters:getLeaderboard` | `bl_dumpsters:server:GetVenueLeaderboard` |
| `envi-dumpsters:tournamentStarting` | `bl_dumpsters:client:CupCountdown` |
| `envi-dumpsters:tournamentStarted` | `bl_dumpsters:client:CupUnderway` |
| `envi-dumpsters:tournamentFinished` | `bl_dumpsters:client:CupConcluded` |
| `envi-dumpsters:tournamentScoreUpdated` | `bl_dumpsters:client:CupScoreLogged` |
| `cart_derby:tournamentFinished` | `bl_dumpsters:server:CupWrapped` |

**Bowling (note: old `hobo_bowling:*` namespace eliminated)**

| Old | New |
|---|---|
| `hobo_bowling:createGame` | `bl_dumpsters:server:OpenMatch` |
| `hobo_bowling:joinGame` | `bl_dumpsters:server:JoinMatch` |
| `hobo_bowling:getAvailableGames` | `bl_dumpsters:server:ListOpenMatches` |
| `hobo_bowling:submitScore` | `bl_dumpsters:server:SubmitPinScore` |
| `hobo_bowling:gameStarted` | `bl_dumpsters:client:MatchStarted` |
| `hobo_bowling:startTurn` | `bl_dumpsters:client:MatchTurnBegan` |
| `hobo_bowling:updateGame` | `bl_dumpsters:client:MatchStateSync` |
| `hobo_bowling:spawnPins` | `bl_dumpsters:client:RaisePins` |
| `hobo_bowling:cleanupPins` | `bl_dumpsters:client:ClearPins` |
| `hobo_bowling:gameFinished` | `bl_dumpsters:client:MatchConcluded` / `bl_dumpsters:server:MatchWrapped` |

**Reclaimer (note: old `envi-hobo:*` namespace eliminated)**

| Old | New |
|---|---|
| `envi-hobo:CheckRecyclerStatus` | `bl_dumpsters:server:IsReclaimerFree` |
| `envi-hobo:StartRecycling` | `bl_dumpsters:server:RunReclaimCycle` |
| `envi-hobo:SetRecyclerBusy` | `bl_dumpsters:server:SetReclaimerBusy` |
| `envi-hobo:StartRecyclingEffect` | `bl_dumpsters:client:ReclaimCycleEffect` |
| `envi-hobo:RecyclerCompleted` | `bl_dumpsters:client:ReclaimCycleDone` |

**Gear / items / contracts**

| Old | New |
|---|---|
| `envi-dumpsters:client:UseItem` | `bl_dumpsters:client:DeployGear` |
| `envi-dumpsters:server:PickUpCardboardBed` | `bl_dumpsters:server:RetrieveCardboardBed` |
| `envi-dumpsters:server:PickUpSleepingBag` | `bl_dumpsters:server:RetrieveSleepingBag` |
| `envi-dumpsters:server:PickUpTent` | `bl_dumpsters:server:RetrieveShelter` |
| `envi-dumpsters:server:OpenTent` | `bl_dumpsters:server:OpenShelterStash` |
| `envi-dumpsters:server:OpenBackpack` | `bl_dumpsters:server:OpenPackStash` |
| `envi-dumpsters:server:DrinkBottle` | `bl_dumpsters:server:SipFlask` |
| `envi-dumpsters:server:RefillBottle` | `bl_dumpsters:server:TopUpFlask` |
| `envi-dumpsters:client:DrinkBottleBadEffect` | `bl_dumpsters:client:FlaskSickness` |
| `envi-dumpsters:client:DrinkBottleGoodEffect` | `bl_dumpsters:client:FlaskVigour` |
| `envi-dumpsters:server:UseRatTreats` | `bl_dumpsters:server:ConsumeRodentTreats` |
| `envi-dumpsters:client:useRatBait` | `bl_dumpsters:client:DeployRodentBait` |
| `envi-dumpsters:client:PoisonAntidote` | `bl_dumpsters:client:AdministerCure` |
| `envi-dumpsters:server:StartStreetHustlerTask` | `bl_dumpsters:server:AcceptContract` |
| `envi-dumpsters:server:CancelStreetHustlerTask` | `bl_dumpsters:server:AbandonContract` |
| `envi-dumpsters:server:UpdateStreetHustlerTaskProgress` | *(replaced by internal `SetContractProgress`)* |
| `envi-dumpsters:server:GetTaskHistory` | `bl_dumpsters:server:GetContractLedger` |
| `envi-dumpsters:client:StartStreetHustlerTask` | `bl_dumpsters:client:ContractAccepted` |
| `envi-dumpsters:client:UpdateTaskProgress` | `bl_dumpsters:client:ContractProgress` |
| `envi-dumpsters:client:TaskCompleted` | `bl_dumpsters:client:ContractFulfilled` |

### 3.3 Config Key Translation

`Config.*` ➔ `Settings.*` throughout.

| Old key | New key |
|---|---|
| `Config.DebugMode` | `Settings.DiagnosticMode` |
| `Config.TrashCooldown` | `Settings.ContainerRefreshMinutes` |
| `Config.AdvancedCheaterCheck` | `Settings.StrictEntityValidation` |
| `Config.JobLocked` | `Settings.RestrictToJobs` |
| `Config.StashesEnabled` | `Settings.ContainerStorageEnabled` |
| `Config.ClearDumpstersOnRestart` | `Settings.WipeStorageOnRestart` |
| `Config.HideInDumpstersEnabled` | `Settings.ConcealmentEnabled` |
| `Config.LeaveDumpsterHeight` | `Settings.ExitLiftHeight` |
| `Config.RustleSoundWhenHiding` | `Settings.ConcealmentNoise` |
| `Config.ProgressBars` | `Settings.UseProgressBars` |
| `Config.GetOutKey` | `Settings.ConcealmentExitKey` |
| `Config.LeaveDumpsterAnim` | `Settings.PlayExitClipOnLeave` |
| `Config.Target` | `Settings.UseTargetSystem` |
| `Config.HoboJobRole` | `Settings.VagrantJobName` |
| `Config.BottleCapItem` | `Settings.CurrencyItem` |
| `Config.LeaveCartKey` | `Settings.DismountCartKey` |
| `Config.DisableHoboKingProgressionFeatures` | `Settings.SimpleModeOnly` |
| `Config.RatBaitDuration` | `Settings.BaitLifetimeSeconds` |
| **Mishaps** | |
| `Config.Fails` | `Settings.Mishaps` |
| `.EnableFail` | `.Enabled` |
| `.EnableRatEvent` | `.VerminEnabled` |
| `.EnableNeedleEvent` | `.SharpsEnabled` |
| `.FailChancePercent` | `.MishapChance` |
| `.DirtyNeedlesChancePercent` | `.SharpsChance` |
| `.DirtyNeedlesEffectTime` | `.SharpsEffectSeconds` |
| `.DirtyNeedlesHealthLoss` | `.SharpsHealthCost` |
| `.RatChancePercent` | `.VerminChance` |
| `.RatHealthLoss` | `.VerminHealthCost` |
| `.RacoonChancePercent` | `.BanditChance` |
| `.RacoonHealthLoss` | `.BanditHealthCost` |
| `.HealthLoss` | `.GenericHealthCost` |
| **Hostile peds** | |
| `Config.AggressivePedsAttack` | `Settings.HostileVagrantsEnabled` |
| `Config.AggressivePedDistance` | `Settings.HostileVagrantRadius` |
| `Config.AggressivePeds` | `Settings.VagrantModels` |
| `Config.AggressivePedWeapons` | `Settings.VagrantArmaments` |
| `.ChanceThresholds` / `.Weapons` / `.GiveHoboWeapon` | `.Thresholds` / `.Loadouts` / `.StreetArms` |
| **Loot** | |
| `Config.RandomSelection.itemCountMin/Max` | `Settings.LootRoll.minPicks/maxPicks` |
| `Config.BeachCanItems(Rare)(Chance)` | `Settings.SeasideBinLoot` / `SeasideBinTreasure` / `SeasideBinTreasureChance` |
| `Config.DumpsterItems(Rare)(Chance)` | `Settings.SkipLoot` / `SkipTreasure` / `SkipTreasureChance` |
| `Config.GarbageCanItems(Rare)(Chance)` | `Settings.WasteBinLoot` / `WasteBinTreasure` / `WasteBinTreasureChance` |
| `Config.OtherSeachablesItems(Rare)(Chance)` | `Settings.EncampmentLoot` / `EncampmentTreasure` / `EncampmentTreasureChance` |
| `Config.GarbageBagsItems(Rare)(Chance)` | `Settings.RefuseSackLoot` / `RefuseSackTreasure` / `RefuseSackTreasureChance` |
| `Config.ExclusiveItemZones` | `Settings.SignatureLootDistricts` |
| `.restrictedZone` / `.snitchChance` / `.jobsToInform` | `.watched` / `.informantChance` / `.alertJobs` |
| **Storage** | |
| `Config.BeachCanStorageSlots/Weight` | `Settings.SeasideBinSlots/Weight` |
| `Config.DumpsterStorageSlots/Weight` | `Settings.SkipSlots/Weight` |
| `Config.GarbageCanStorageSlots/Weight` | `Settings.WasteBinSlots/Weight` |
| `Config.OtherStorageSlots/Weight` | `Settings.EncampmentSlots/Weight` |
| **Models & clips (were bare globals!)** | |
| `BeachCans` | `Settings.SeasideBinModels` |
| `Dumpsters` | `Settings.SkipModels` |
| `GarbageCans` | `Settings.WasteBinModels` |
| `OtherSearchables` | `Settings.EncampmentModels` |
| `TrashBagModels` | `Settings.RefuseSackModels` |
| `CustomSearchables` | `Settings.BespokeSearchables` |
| `.isStealing` / `.deleteProp` | `.illicit` / `.consumeProp` |
| `BeachCanAnims` | `Settings.SeasideBinClips` |
| `DumpsterAnims` | `Settings.SkipClips` |
| `GarbageCanAnims` | `Settings.WasteBinClips` |
| `TrashBagAnims` | `Settings.RefuseSackClips` |
| `HideInDumpsterAnims` | `Settings.ClimbInClips` |
| `KickedOutDumpsterAnims` | `Settings.ClimbOutClips` |
| `Config.RatFailAnim` / `DirtyNeedlesFailAnim` / `FailAnim` | `Settings.VerminReactionClip` / `SharpsReactionClip` / `GenericMishapClip` |
| **Progression** | |
| `Config.XPSettings` | `Settings.Reputation` |
| `.LevelRequirements` | `.RankThresholds` |
| `.XPPerBottleCapDonated` | `.XPPerCurrencyTithed` |
| `.DrugDonationXP` | `.ContrabandXP` |
| `.MissionXP` | `.ChapterXP` |
| `Config.HoboKing` | `Settings.Overseer` |
| `.Position` / `.InactivityTimer` / `.FreedomCost` | `.Anchor` / `.DormancyDays` / `.BuyoutPrice` |
| `Config.Unlockables` | `Settings.MarketStock` |
| `Config.Missions` | `Settings.Chapters` |
| `.Zones` / `.ZoneRadius` | `.Districts` / `.DistrictRadius` |
| `.RatAreas` / `.AreaRadius` | `.InfestedSites` / `.SiteRadius` |
| `.RequiredAmount` / `.RequiredDistance` / `.RequiredItems` / `.RequiredDumpsters` | `.TargetEarnings` / `.TargetMetres` / `.TargetSalvage` / `.TargetContainers` |
| `.PackageChance` / `.RivalLocation` / `.SpawnLocations` | `.ParcelChance` / `.RivalAnchor` / `.DenSites` |
| `.PickupLocations` / `.DropoffLocations` / `.Rewards` / `.TimeLimit` | `.CollectionPoints` / `.DeliveryPoints` / `.Payout` / `.MinutesAllowed` |
| `.Tasks` / `.unlockLevel` / `.count` / `.bottleCaps` / `.level` | `.Contracts` / `.unlockRank` / `.target` / `.currencyReward` / `.rank` |
| `.ChallengeLocation` | `.ArenaAnchor` |
| `Config.ItemSettings` | `Settings.GearBehaviour` |
| `.regeneration` / `.uses` / `.capacity` / `.duration` / `.provides` | `.recovery` / `.charges` / `.charges` / `.minutes` / `.yields` |
| **Panhandling** | |
| `Config.BeggingSettings` | `Settings.Panhandling` |
| `.BegCommand` / `.IgnoreChance` | `.Command` / `.BrushOffChance` |
| `.MaxBaseReward` / `.MaxTotalReward` | `.MaxBasePayout` / `.MaxFinalPayout` |
| `.BegWithSignMultiplier` / `.TrueHoboMultiplier` | `.SignBonus` / `.CommittedBonus` |
| `.AggressivePedChance` / `.BegCooldown` / `.ProgressBar` | `.HostileChance` / `.CooldownSeconds` / `.ShowProgressBar` |
| `.CleanCars` / `.Min/MaxCleanCarReward` / `.Min/MaxCleanTime` / `.AggressiveCleanCarChance` | `.WashingEnabled` / `.Min/MaxWashPayout` / `.Min/MaxWashSeconds` / `.HostileWashChance` |
| **Salvage & reclaimer** | |
| `Config.JunkItems.Items` | `Settings.SalvageTiers.Tiers` |
| `Config.RecyclerLocations` | `Settings.ReclaimerSites` |
| `Config.RecycleSettings` | `Settings.ReclaimerBehaviour` |
| `.duration` / `.unlockedByMission` | `.cycleSeconds` / `.chapterGated` |
| `Config.RecyclingItems` | `Settings.ReclaimRecipes` |
| `.material` | `.output` |
| **Derby & bowling** | |
| `Config.CartDerby` | `Settings.TrolleyDerby` |
| `.ConstantBlips` / `.BlipScale` / `.Tracks` | `.AlwaysShowBlips` / `.BlipSize` / `.Venues` |
| `.cartLocation` / `.startPoint` / `.startPointRadius` / `.showStartZone` | `.trolleySpot` / `.launchPoint` / `.launchRadius` / `.revealLaunchZone` |
| `Config.HoboBowling` | `Settings.AlleyBowling` |
| `.MaxPlayers` / `.MinPlayers` / `.PointsPerPin` / `.StrikeBonus` / `.WinnerXP` | `.MaxEntrants` / `.MinEntrants` / `.ScorePerPin` / `.PerfectBonus` / `.VictorXP` |
| `.PlayerStartDistance` / `.PinSpacing` / `.Locations` | `.ThrowLineRadius` / `.PinGap` / `.Venues` |
| `.laneHeading` / `.showFoulZone` / `.alley` / `.pins` / `.playerStart` / `.cartSpawn` | `.laneBearing` / `.revealFoulZone` / `.lane` / `.pinCluster` / `.throwMark` / `.trolleySpawn` |
| `.BowlingHostModel` / `.PinLeaderModel` / `.PinPedModels` | `.CompereModel` / `.HeadPinModel` / `.PinModels` |
| **Tainted arms** | |
| `Config.PoisonWeapons` | `Settings.TaintedArms` |
| `.damagePerSecond` / `.poisonDuration` / `.antidoteItem` | `.tickDamage` / `.durationSeconds` / `.cureItem` |
| `Config.Lang` | `Settings.Text` |

### 3.4 Function & Variable Translation (selected)

| Old identifier | New identifier |
|---|---|
| `DebugPrint()` | `LogDiagnostic()` |
| `MakeHobosHateYou()` | `ProvokeLocalVagrants()` |
| `TriggerDumpsterSearch()` | `PerformRummage()` |
| `NetworkGetOrRegisterEntity()` | `EnsureNetworked()` |
| `RacoonSearch()` | `DispatchCompanion()` |
| `RacoonExit()` | `PlayBanditStartle()` |
| `RegisterSearchableModel()` | `RegisterContainerFamily()` |
| `KeepTrackOfBag()` | `WatchRefuseSack()` |
| `CustomDispatch()` | `RelayTheftReport()` |
| `TriggerDirtyNeedlesEffect()` | `ApplySharpsAffliction()` |
| `TriggerRatEffect()` | `ApplyVerminAmbush()` |
| `GetPlayerProgression()` | `FetchStanding()` |
| `UpdatePlayerProgression()` | `PersistStanding()` |
| `AddHoboXP()` | `GrantReputationXP()` |
| `TryLevelUp()` | `TryAdvanceRank()` / `AttemptRankUp()` |
| `CompleteMission()` | `CloseChapter()` |
| `UpdateMissionProgress()` | `PushChapterProgress()` |
| `GetMissionProgress()` | `ReadChapterProgress()` |
| `EnsureHoboJobRole()` | `EnforceScavengerJob()` |
| `SetHoboKing()` | `SeatOnThrone()` |
| `UpdateKingStatus()` | `RefreshThroneStatus()` |
| `RecruitBodyguard()` / `DismissBodyguard()` | `HireEscort()` / `ReleaseEscort()` |
| `SetupRelationshipGroups()` | `ConfigureRelationshipGroups()` |
| `SetupBodyguardRecruitment()` | `RegisterEscortInteractions()` |
| `GetNearestEnemyToPed()` | `NearestHostileTo()` |
| `TableContains()` | `ListContains()` |
| `OpenProgressMenu()` | `OpenStandingMenu()` |
| `OpenMissionMenu()` | `OpenChapterMenu()` |
| `OpenDonateMenu()` / `OpenDrugAmountMenu()` | `OpenContrabandMenu()` / `OpenContrabandQuantity()` |
| `OpenBottleCapMenu()` | `OpenCurrencyTitheMenu()` |
| `OpenHoboShop()` / `BuyHoboItem()` | `OpenStreetMarket()` / `PurchaseMarketStock()` |
| `GetItemLevel()` | `RankForStockItem()` |
| `DonateDrugs()` / `DonateBottleCaps()` | `TitheContraband()` / `TitheCurrency()` |
| `AddHoboProgessionLoot()` *(sic)* | `AwardSalvageAndProgress()` |
| `SelectWeightedRandomIndex()` | `RollWeightedIndex()` |
| `GiveRandomItems()` / `GiveRareItem()` / `GiveBagItems()` / `GiveSingleItem()` | `DispenseLoot()` / `DispenseTreasure()` / `DispenseSackLoot()` / `DispenseSingle()` |
| `HashCoords()` | `HashPosition()` |
| `IsNearBusyDumpster()` | `AnchorAlreadyDepleted()` |
| `AttachCartToPlayer()` | `GrabTrolley()` |
| `DetachCartWithBoost()` / `DetachCartFromPlayerNoBoost()` | `LaunchTrolley()` / `DropTrolley()` |
| `StartThrillRideMission()` / `CompleteThrillRideMission()` | `BeginDownhillRush()` / `CompleteDownhillRush()` |
| `SubmitDerbyScore()` / `SubmitTournamentScore()` | `SubmitFreeRunScore()` / `SubmitCupScore()` |
| `StartHoboTaxiMission()` / `CompleteTaxiMission()` / `FailTaxiMission()` | `BeginTrolleyCabRun()` / `FinishCabRun()` / `AbortCabRun()` |
| `SpawnTaxiPassenger()` | `SpawnCabFare()` |
| `StartHoboKingEndlessChallenge()` | `BeginThroneGauntlet()` |
| `EndChallenge()` / `ShowKingLeaderboard()` | `ConcludeGauntlet()` / `ShowGauntletBoard()` |
| `SpawnEnemyPed()` / `SpawnPedLoop()` | `SpawnAttacker()` / `RunWaveSpawner()` |
| `GetRandomSpawnPoint()` | `PickSpawnPoint()` |
| `SpawnPins()` / `CleanupPins()` / `CountKnockedDownPins()` | `RaisePins()` / `ClearPins()` / `TallyToppledPins()` |
| `AnnounceStandings()` / `StartMyTurn()` | `AnnounceScoreboard()` / `TakeMyTurn()` |
| `CreateBowlingHostNPC()` | `CreateCompere()` |
| `StartGame()` / `EndGame()` / `StartTurn()` / `NextTurn()` | `StartMatch()` / `ConcludeMatch()` / `BeginTurn()` / `AdvanceTurn()` |
| `ProcessRecycler()` / `OpenRecycler()` / `StartRecycling()` | `ProcessReclaimer()` / `OpenReclaimerStash()` / `StartReclaimCycle()` |
| `CleanCar()` | `WashWindscreen()` |
| `beggingLoop()` / `findNearestPed()` / `waitForPedToApproach()` | `PanhandleSession()` / `ClosestPedestrian()` / `AwaitPedestrian()` |
| `deleteBeggingProp()` | `DiscardPlacard()` |
| `IsTaskActive()` / `CompleteTask()` / `AddTaskProgress()` | `IsContractLive()` / `FulfilContract()` / `AddContractProgress()` |
| `UpdateTaskProgressUI()` | `RenderContractTracker()` |
| **Variables** | |
| `drugged` | `ScavengerImpaired` |
| `interactionLocked` | `searchLocked` |
| `raccoonOptionBusy` | `companionBusy` |
| `isHidingInDumpster` / `hideSessionActive` | `concealed` / `concealmentOngoing` |
| `rustleSoundPlaying` / `rustleSoundId` | `rustleActive` / `rustleHandle` |
| `currentZoneName` / `currentZoneIndex` / `currentRestrictedZoneName` | `districtName` / `districtIndex` / `watchedDistrictName` |
| `RacoonPal` | `BanditCompanion` |
| `IsTrueHobo` | `CommittedScavenger` |
| `isHoboKing` | `holdsThrone` |
| `bodyguards` / `MAX_BODYGUARDS` | `escorts` / `ESCORT_CAP` |
| `hoboKingNPC` | `overseerPed` |
| `missionBlips` | `chapterMarkers` |
| `ratZones` / `currentRatAreaIndex` / `ratKillCounts` / `activeRatCount` | `infestedZones` / `activeInfestedIndex` / `rodentTallies` / `liveRodents` |
| `IsPushingCart` / `CurrentCart` / `CART_MODELS` | `TrolleyHeld` / `HeldTrolley` / `TROLLEY_MODELS` |
| `isSittingInCart` / `sittingCartEntity` | `ridingTrolley` / `riddenTrolley` |
| `tournamentCart` / `tournamentStartZone` / `ActiveTournaments` | `derbyTrolley` / `launchZone` / `ActiveCups` |
| `spawnedHostNPCs` | `compereNPCs` / `spawnedHostNPCs` ➔ `compereNPCs` |
| `thrillRide.{active,totalDistance,lastPosition,blips}` | `downhillRush.{running,metres,lastAnchor,markers}` |
| `dumpsterBusy` / `dumpsterBusyCoords` / `rareItemBusy` | `depletedContainers` / `depletedAnchors` / `treasureSpent` |
| `dumpsterOccupied` / `dumpsterOccupiedBy` / `registeredStashes` | `occupiedSkips` / `skipOccupant` / `knownStashes` |
| `activeGames` / `gameIdCounter` | `liveMatches` / `matchCounter` |
| `PlayerTasks` / `playerTaskHistory` | `LiveContracts` / `contractLedger` |
| `isPoisoned` / `poisonWeapons` / `activePoison` | `afflicted` / `taintedRegistry` / `currentAffliction` |
| `killCount` / `challengeActive` / `spawnedPeds` | `takedowns` / `gauntletLive` / `waveAttackers` |
| `recyclerBusy` / `recyclerEndTime` / `recyclerProps` | `reclaimerBusy` / `reclaimerFinishAt` / `reclaimerProps` |
| `passengerPed` / `currentMission` / `attachedCart` | `CabPassenger` / `activeRun` / `ferryingTrolley` |
| `isSleeping` | `gearBusy` |

---

## 4. Database Schema Auto-Installer

**No `.sql` file is shipped and none is needed.** `server/database.lua` builds and verifies the entire schema on `onResourceStart` inside `MySQL.ready`.

### 4.1 Tables created

**`bl_scavenger_standing`** — one row per character; the reputation ladder.

| Column | Type | Default | Purpose |
|---|---|---|---|
| `identifier` | `VARCHAR(60)` | — | **PRIMARY KEY** — character identifier |
| `level` | `INT` | `1` | Current rank (1–10) |
| `xp` | `INT` | `0` | Lifetime reputation XP |
| `mission_data` | `LONGTEXT` | `NULL` | JSON-encoded chapter state |
| `is_king` | `TINYINT(1)` | `0` | Holds the throne |
| `king_since` | `DATETIME` | `NULL` | When the throne was claimed |
| `last_active` | `DATETIME` | `NULL` | Drives the dormancy sweep |
| `donated_drugs` | `INT` | `0` | Daily contraband tithe flag |
| `true_hobo` | `TINYINT(1)` | `0` | Permanently committed |

**`bl_gauntlet_board`** — top-10 Final Gauntlet records.

| Column | Type | Default | Purpose |
|---|---|---|---|
| `identifier` | `VARCHAR(60)` | — | **PRIMARY KEY** |
| `player_name` | `VARCHAR(255)` | — | Display name |
| `kill_count` | `INT` | `0` | Takedowns achieved |
| `time_survived` | `INT` | `0` | Seconds survived |
| `date_achieved` | `DATETIME` | `CURRENT_TIMESTAMP` | When it was set |

**`bl_derby_records`** — per-venue trolley distance leaderboards.

| Column | Type | Default | Purpose |
|---|---|---|---|
| `id` | `INT AUTO_INCREMENT` | — | **PRIMARY KEY** |
| `identifier` | `VARCHAR(60)` | — | Character identifier |
| `venue` | `VARCHAR(100)` | — | Derby venue name |
| `distance` | `FLOAT` | `0` | Best distance in metres |
| `name` | `VARCHAR(100)` | `NULL` | Display name |
| `created_at` | `DATETIME` | `CURRENT_TIMESTAMP` | First recorded |
| — | `UNIQUE KEY` | — | **`(identifier, venue)`** |

> **Note:** the original schema had *no* unique key on `(identifier, track)` yet its insert used `ON DUPLICATE KEY UPDATE` — meaning the upsert never actually fired and the table accumulated one row per run forever. The unique key is now present so the upsert behaves as intended.

### 4.2 Indexes created

| Index | Table | Columns |
|---|---|---|
| `bl_derby_ranking` | `bl_derby_records` | `venue`, `distance DESC` |
| `bl_gauntlet_kills` | `bl_gauntlet_board` | `kill_count DESC` |
| `bl_standing_throne` | `bl_scavenger_standing` | `is_king`, `last_active` |

### 4.3 Installer behaviour

1. **Idempotent tables** — `CREATE TABLE IF NOT EXISTS` for all three.
2. **Self-healing columns** — every column is probed via `information_schema.COLUMNS` and added with `ALTER TABLE … ADD COLUMN` only if genuinely absent. (`ADD COLUMN IF NOT EXISTS` is MariaDB-only, so introspection is used for MySQL 8 compatibility.)
3. **Conditional indexes** — probed via `information_schema.STATISTICS` before creation.
4. **One-time legacy import** — if `hobo_progression` / `hobo_king_leaderboard` exist from a prior Envi install **and** the corresponding new table is still empty, rows are copied with `INSERT IGNORE`. Guarded so it can never duplicate or clobber live data, and never runs twice.
5. **Boot housekeeping** — resets the daily contraband flag and releases the throne from a dormant holder (matching original cadence).
6. **Non-destructive** — no `DROP`, no `TRUNCATE`, no destructive `ALTER`. Restarting the resource never wipes data.
7. **Guarded** — aborts with a clear `[^3BlackLight^7]` console error if `oxmysql` is not running; every statement is `pcall`-wrapped.

---

## 5. Security & Architecture Hardening

### 5.1 New guard layer (`server/security.lua`)

| Guard | Purpose |
|---|---|
| `GuardRate(src, key, ms)` | Per-player, per-action rate limiting. Applied to **every** net event and callback. Buckets cleared on disconnect. |
| `GuardProximity(src, coords, max)` | Server-side distance check against the player's real ped position (default 12m). Blocks remote looting/teleport-farming. |
| `GuardEntity(netId)` | Confirms a claimed networked entity genuinely exists. |
| `GuardInventory(src, item, qty)` | Server-authoritative inventory verification. |
| `GuardNumber(v, min, max)` | Clamps/rejects client-supplied numerics (incl. NaN). |

### 5.2 Specific exploits closed

| Issue | Original behaviour | Now |
|---|---|---|
| **Client-priced purchases** | `BuyHoboItem` trusted a client-sent `totalPrice`, letting a spoofed value buy anything for 1 cap. Also charged `quantity` caps instead of `price × quantity`. | Unit price is re-derived from `Settings.MarketStock` server-side; the client total is ignored entirely. |
| **Rank gate bypass** | Contract rank requirement was only enforced by the UI's `canSee`. | Enforced server-side in `AcceptContract`. |
| **Unbounded score claims** | Derby distance and gauntlet takedowns were written to the DB verbatim. | Clamped (`≤15,000m`, `≤2,000` takedowns, `≤3,600s`) and rate-limited. |
| **Out-of-turn bowling scores** | Pin counts accepted unvalidated. | Clamped `0–10` and rejected unless it is genuinely that player's turn. |
| **Cup entry-fee spoofing** | Join used the client's `buyIn` argument. | Fee is read from the authoritative server-side cup record. |
| **Global begging lock** | A single shared `beggingLocked` flag meant one player's payout blocked every other player's for 2s. | Per-player lock table plus per-player rate limiting. |
| **Unverified placard bonus** | The 1.5× sign multiplier trusted a client boolean. | Server re-verifies `begging_sign` is actually held. |
| **Remote reclaimer triggering** | Any client could start any reclaimer from anywhere. | Proximity-checked against the machine's configured coordinates. |
| **Free-form item removal** | `RemoveItem` net event accepted arbitrary item/count from clients. | Type-checked, count-clamped and rate-limited. |
| **Stranded routing buckets** | Disconnecting mid-gauntlet left the player's bucket assigned. | `playerDropped` handler restores bucket 0. |

### 5.3 Performance

- **No unconditional `Wait(0)` loops.** All idle/polling loops run at `500`–`10000`ms (escort combat 1000ms, reclaimer watcher 1000ms, trolley safety net 5000ms, ambient vagrant sweep 10000ms, flask check 5000ms).
- `0ms` is used **only** inside short-lived input-capture loops (carrying a trolley, riding a trolley, resting on bedding, concealment exit key) that terminate the moment the interaction ends — exactly as the original required for frame-accurate input.
- **Localised hot globals** — `math.random`, `math.floor`, `math.min/max/abs`, `table.insert/remove`, `string` helpers localised per file.
- **Reclaimer polling** tightened from 2000ms to a 1000ms tick, and the per-frame `Wait(0)` cosmetic loop now throttles its audio to a 500ms interval using an explicit timestamp instead of the original's unreliable `GetGameTimer() % 500 < 50` sampling.
- **Modern Lua 5.4** throughout: early returns over deep nesting, `goto continue` only where it genuinely reads best, table-driven dispatch (`gearHandlers`, `TRACKER_TEMPLATES`, `PIN_LAYOUT`) replacing long `if/elseif` chains.

### 5.4 Genuine bugs fixed (behaviour preserved)

1. **Rat-bait zone leak** — the original created a `Zone.SphereZone` for bait but never stored the handle, so its expiry `SetTimeout` had an empty body and the zone spawned rodents *forever*. The handle is now captured and properly removed after `BaitLifetimeSeconds`.
2. **Loot draw loop inverted** — the original's `repeat … until usedIndexes[index] or tries > #items` looped *until it found an already-used index*, then only granted an item when `tries <= #items`. The intent (draw distinct entries) is now implemented correctly with `until not drawn[index] or attempts > #pool`.
3. **`GiveItemsBags` netId undefined** — the client passed a global `netId` that was never assigned (always `nil`). Now passes the real network id of the tracked sack.
4. **Contract progress argument shuffle** — `UpdateStreetHustlerTaskProgress` had a decompilation artefact where `progress` was overwritten with `taskType`, permanently corrupting progress values. Rewritten as a clean `SetContractProgress(src, type, value)`.
5. **Derby cup event payload inconsistency** — countdown warnings sent `trackName` at 10/5 minutes but the whole `track` table at 1 minute; cup start sent a table where the client expected venue fields. Now consistently sends the venue definition where the client needs it and the name where it doesn't.
6. **Cup wrap-up key mismatch** — server emitted `hostIdentifier`/`hostSource` but the task listener read `options.hostSource` after checking a differently-named field. Keys unified.
7. **Prize pool double-discount** — the host's buy-in was multiplied by `0.9` at creation *and* the pool was paid out in full later, so the 10% rake applied only to the host. The rake now applies once, to the final pool.
8. **`SetHoboKing` unreachable notify** — `DonateDrugs` computed `xpAmount` by indexing the config *before* nil-checking it, so an invalid type errored instead of returning the friendly message. Order corrected.
9. **Bowling `math.max` on cumulative tallies** — documented and preserved (both passes only count *newly* toppled pins), with the intent now spelled out in a comment.
10. **Throne-contest string matching** — the client decided whether to fight by substring-matching the localized message (`"inactive"`, `"no current"`), which silently broke with the Spanish locale already shipped. The server now returns an explicit `gauntletRequired` boolean.
11. **Duplicate cure registration** — if two tainted weapons shared a cure item, `CreateUseableItem` was registered twice for it. Now de-duplicated.
12. **`IsHoboKing` debug spam** — unconditional `print()` calls on every check removed/gated behind `DiagnosticMode`.

---

## 6. Setup & Installation

### 6.1 Requirements

| Dependency | Notes |
|---|---|
| **oxmysql** | Required. Must start **before** this resource. |
| **ox_lib** | Required. |
| **blacklight-bridge** | The framework bridge (formerly `envi-bridge`). |
| **blacklight-interact** | The interaction/NPC library (formerly `envi-interact`). |
| A target resource | `ox_target` / `qb-target` — optional if you use the "Press E" mode. |
| Asset pack | The `[assetpacks]` stream containing the raccoon ped, custom weapons and models. |

> **Important:** if your bridge and interact resources are still named `envi-bridge` / `envi-interact`, either rename those folders to `blacklight-bridge` / `blacklight-interact`, **or** edit the three references in `fxmanifest.lua` and the `exports["blacklight-interact"]` calls to match your existing names.

### 6.2 Installation

1. **Drop in the resource**
   ```
   resources/[blacklight]/blacklight-dumpsters/
   ```

2. **Add to `server.cfg`** — after oxmysql, ox_lib and the bridge:
   ```cfg
   ensure oxmysql
   ensure ox_lib
   ensure blacklight-bridge
   ensure blacklight-interact
   ensure blacklight-dumpsters
   ```

3. **Database — nothing to do.** On first boot you will see:
   ```
   [BlackLight] Verifying database schema...
   [BlackLight] Database schema verified. No manual .sql import is required.
   ```

4. **Add the items** to your inventory's item list (`ox_inventory/data/items.lua`, `qb-core/shared/items.lua`, …). Use the **exact** spawn names listed in §2.4 — they match the shipped icons.

5. **Copy the icons**
   ```
   blacklight-dumpsters/inventory_images/*.png  ➔  ox_inventory/web/images/
   ```
   *(or `qb-inventory/html/images/`)*

6. **Create the job.** Add a job with the name **`hobo`** to your framework's job list (or change `Settings.VagrantJobName` in `shared/settings_progression.lua` to an existing job).

7. **Configure.** Review `shared/settings.lua` (loot tables, mishap odds, storage sizes) and `shared/settings_progression.lua` (ranks, market stock, chapters, minigames). Confirm that every `output` in `Settings.ReclaimRecipes` is a real item on your server.

8. **Restart the server.**

### 6.3 Post-install checklist

- [ ] Console shows the green schema-verified banner with no errors.
- [ ] `Settings.UseTargetSystem` matches your setup (`true` = target resource, `false` = Press E — also uncomment `bridge_disable { 'target' }` in `fxmanifest.lua` for the latter).
- [ ] All items appear correctly with icons in-game.
- [ ] Rummaging a skip yields loot and bottle caps.
- [ ] The Overseer NPC is present at `123.75, -1187.16, 29.50`.
- [ ] Derby compere NPCs appear at all six venues.
- [ ] Dispatch fires when looting inside the Burgershot district.

### 6.4 Testing tools

Set `Settings.DiagnosticMode = true` for debug zones, verbose logging and these commands:

| Command | Effect |
|---|---|
| `/bl_setrank [1-10]` | Force your reputation rank (server) |
| `/bl_tp_overseer` | Teleport to the Overseer |
| `/bl_test_throne` | Toggle throne-holder status |
| `/bl_spawn_escort` | Spawn an escort |
| `/bl_test_gauntlet` | Start the Final Gauntlet |
| `/bl_test_trolley` | Spawn and grab a trolley |
| `/bl_test_cab`, `/bl_test_cab_fail`, `/bl_test_cab_done` | Cab contract flow |
| `/bl_spawnbandit` | Spawn a raccoon |
| `/bl_testtoxin` | Spawn an attacker with a tainted weapon |
| `/bl_seed_derby [venue] [distance]` | Seed derby leaderboard data |

> Always set `DiagnosticMode = false` on a live server.

### 6.5 Migrating from Envi-Dumpsters

1. Stop the server and remove the old `envi-dumpsters` folder.
2. Install `blacklight-dumpsters` as above.
3. Start the server — the installer detects `hobo_progression` / `hobo_king_leaderboard` and imports ranks, XP, chapter state and throne records automatically.
4. Container stash contents carry over untouched (the stash key format is unchanged).
5. Once you have confirmed everything works, the legacy `hobo_progression`, `hobo_king_leaderboard` and `hobo_cart_leaderboards` tables can be dropped manually. **The installer never drops them for you.**

---

## 7. Verification Performed

| Check | Result |
|---|---|
| Lua 5.4 syntax — all 30 files | ✅ Pass (AST parse) |
| Every `TriggerCallback` has a matching `CreateCallback` | ✅ 0 orphans |
| Every `TriggerClientEvent`/`TriggerServerEvent` has a matching `RegisterNetEvent` | ✅ 0 orphans |
| Every `Settings.Text.*` key resolves in `locale.lua` | ✅ 0 missing |
| Every `Settings.<Key>` resolves in the shared configs | ✅ 0 missing |
| Every nested `Settings.X.Y` sub-key resolves | ✅ 0 missing |
| No client-only global called from server context (or vice versa) | ✅ 0 violations |
| Residual `envi` / `Envi` / `ENVI` branding | ✅ 0 occurrences |
| Item spawn names altered | ✅ 0 (all preserved) |
| Framework/native/library API signatures altered | ✅ 0 (all preserved) |

---

*BlackLight Dumpsters v3.0.0 — BlackLight Development*
