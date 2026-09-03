# AoE4RPG SCAR Module Reference

Author: Hikitomi

## IDE workflow

The repository includes VS Code workspace files under `.vscode/`.

- Open the repository folder as the workspace root.
- Install the recommended Lua extension when prompted; `.scar` files are associated with Lua syntax for navigation and highlighting.
- Use the Command Palette or **Terminal → Run Task** to run `SCAR: list root modules` and `SCAR: find imports`.
- Keep `.aoe4-mcp-runtime` excluded from search and editing; it is local tooling rather than game source.

SCAR is loaded by the game/editor runtime, so these tasks provide source navigation and lightweight checks rather than compiling or launching the game.

## Class value and entity lifecycle

`AoE4RPG_CLASS_InitializeValueRegistry()` builds one profile for every
civilization/class pair at match start. Each profile stores the blueprint-backed
Base Attribute, civilization-specific growth, class growth, level-zero
attributes, and derived-stat preview. It also owns a sparse `entity_ids` map;
each entry stores the live EntityID's synchronized RPG progress.

The entity tracker performs class/blueprint discovery only on startup, on a
successful production event while a hero slot or elite capacity remains, and on
the narrow post-tier conversion rebind. A tracked EntityID is registered in its
class profile with its `damage_dealt`, level, and pending-level progress, then
receives the cached values and entity modifiers. The record is removed from both
registries on death. Selection UI reads the EntityID-to-profile map;
it does not rediscover classes or scan blueprints. Riders remain attachment-only
and are excluded from class membership and selection.

This design follows the ScarDoc lifecycle constraints: entity modifiers return
handles that must be removed explicitly, EntityIDs must be treated as invalid
after death or conversion, and presentation code should read synchronized state
rather than mutate gameplay state. The local ScarDoc package contains the API
index/tree used for this validation; final behavior still requires an in-game
runtime test because the extracted documentation does not include every native
function signature.

## Runtime optimization and extension points

`AoE4RPG_runtime_helpers.scar` centralizes compatibility-safe PlayerID,
EntityID, live-entity, synchronized-time, deep-copy, sorted-key, and recursive
blueprint traversal helpers. Feature modules retain local fallbacks, but new
modules should use these shared helpers instead of adding another copy.

`AoE4RPG_CLASS_MonitorRuntimeFeatures()` is the extension point for class
behavior that refreshes every 0.25 seconds. It walks the tracked human EntityID
list once, dispatches only the matching class behavior, and reuses the Commander
snapshot for aura processing. Legacy per-feature start and stop functions remain
available for compatibility, while the bootstrap starts only the consolidated
rule.

Human and AI trackers cache their sorted EntityID lists and rebuild those lists
only when membership changes. Blueprint initialization also builds direct
blueprint-to-tracking and blueprint-to-civilization maps. Melee hunt effects use
the bounded per-player nearby-entity query when available and preserve the
all-world query only as a compatibility fallback.

Function counts include global functions, nested local functions, and anonymous callbacks. The active import tree currently contains **248 function declarations**: **235 named/local functions** and **13 anonymous callbacks** across 19 project modules. This reference covers the active root import tree; generated copies under `AoE4RPG_Scar/` are not loaded by the IDE bootstrap.

| Root module | Functions | Main responsibility |
|---|---:|---|
| `AoE4RPG_runtime_helpers.scar` | 7 | Shared compatibility-safe identifiers, time, copying, deterministic table order, and blueprint traversal. |
| `AoE4RPG_blueprints.scar` | 21 | Blueprint, civilization, hero-slot, and elite-limit configuration and lookup. Blueprints helpers. Use to help looking up specific entity bp. This will be updated whenever new Civilization and Heroes Added. |
| `AoE4RPG_economic_blueprints.scar` | 6 | Animal food and Mongol Ovoo resource blueprint registry, one-time animal EntityID guards, and blueprint-scoped Ovoo stone modifiers. |
| `AoE4RPG_bootstrap.scar` | 13 | Module imports, lifecycle hooks, initialization, and shutdown. Cardinal scar, edit it to work on crafted maps. |
| `AoE4RPG_classes.scar` | 29 | Class-value registry, native damage-upgrade hiding, elite detection, XP specialization, class growth, modifiers, and strategist ability effects. |
| `AoE4RPG_core.scar` | 38 | RPG records, cached profile application, XP, levels, derived stats, modifiers, native XP, and death penalties. |
| `AoE4RPG_conversion.scar` | 14 | Conversion ability recognition, range-scoped ownership-change tracking, population-cap death fallback, and conversion XP awards. |
| `AoE4RPG_ability_cost.scar` | 9 | Manual hero/elite HP-cost registry and Debug state-model health synchronization. Native ability resource costs remain in XML. |
| `AoE4RPG_effects.scar` | 18 | Shared projectile/entity marker effects, ally/enemy filtering, weapon-slot fallback, area targeting, passive registration, and effect monitoring. |
| `AoE4RPG_effects_list.scar` | 7 | Named reusable damage, skill-level scaling, armor-ignoring attack/projectile-hit, healing, weapon-slot, and effect-dispatch implementations. |
| `AoE4RPG_ability_list.scar` | 2 | Manual ability-to-effect name and value registry. |
| `AoE4RPG_ability_effects_core.scar` | 0 | Ability/effect manifest that loads the declarative registries before runtime dispatch and its projectile/health-cost adapters. |
| `AoE4RPG_debug_cheat.scar` | 3 | Debug level-up cheat registration and execution. |
| `AoE4RPG_entity_tracker.scar` | 29 | Event-driven hero/elite discovery, class-profile membership, modifier cleanup, death reopening, and special respawns. |
| `AoE4RPG_hero_ui.scar` | 12 | Selected-unit attributes and tracked hero/elite progress display. Using non-background boxes to put them onto Unit's Info box. |
| `AoE4RPG_random_bonus.scar` | 16 | Typed bracket choices: listed bonus, calculated primary-attribute gain, and Ability_List skill/skill-level selection. |
| `AoE4RPG_random_bonus_ui.scar` | 6 | Three-choice bonus UI state and selection forwarding, Co-op Crucible Style |
| `AoE4RPG_ui.scar` | 11 | Selection monitoring and coordination of the RPG UI. Uses constant-time tracked EntityID/profile lookup. |
| `AoE4RPG_settings.scar` | 5 | Standalone AoE4RPG settings bridge for the IDE/bootstrap workflow. |
| `AoE4RPG_ui_panel.scar` | 5 | Shared UI panel lifecycle and data-context helpers. |
| `AoE4RPG_ui_main.scar` | 0 | UI manifest that loads the panel, selection, hero, and bonus presenters. |

## `AoE4RPG_blueprints.scar` — 18 functions

| Function | Use |
|---|---|
| `AoE4RPG_NormalizeBlueprintName(value)` | Converts an engine blueprint value or path into the normalized short name used by registry lookups. |
| `AoE4RPG_BlueprintRegistryValueExists(value)` | Recursively checks whether a registry row contains at least one usable blueprint. |
| `AoE4RPG_CreateHeroClassRemainingChecks(civilization)` | Creates the per-class `1` or `0` hero discovery state for a civilization. |
| `AoE4RPG_GetEliteTrackingLimitKey(class_name)` | Converts a class name into its independent `elite_<class>` capacity key. |
| `AoE4RPG_GetDynamicEliteLimitRule(civilization, class_name)` | Returns the live-resource elite rule configured for a civilization and class. |
| `AoE4RPG_GetEliteLevelOverride(civilization, class_name)` | Returns an optional elite-only level-cap override without changing elite classification or concurrent limits. |
| `AoE4RPG_GetRiderRule(civilization, class_name)` | Returns the optional `rider = true` rule used to infer attachment-only rider class membership without a rider registry table. |
| `AoE4RPG_IsConfiguredRider(entity, civilization, class_name)` | Tests the native rider type and the configured civilization/class rider rule. |
| `AoE4RPG_GetEliteRule(civilization, class_name)` | Returns the optional `elite = true` rule used to classify native elites without an elite blueprint table. |
| `AoE4RPG_IsConfiguredElite(entity, civilization, class_name)` | Tests native elite identity and the configured civilization/class elite rule. |
| `AoE4RPG_IsClassFlaggedElite(civilization, class_name)` | Promotes class-table blueprints to the elite role for Roamer, Duelist, Skirmisher, or Technician when `elite = true` is configured. |
| `AoE4RPG_IsEntityDynamicElite(entity, civilization, class_name)` | Tests whether an entity has the unit type required by a dynamic elite rule. |
| `AoE4RPG_GetDynamicEliteAvailableResource(player, dynamic_rule)` | Reads the player's current configured elite-capacity resource, including named-table fallbacks. |
| `AoE4RPG_GetEliteConcurrentTrackingLimit(civilization, class_name, player, tracked_count)` | Returns a fixed elite limit or calculates a live limit from tracked elites plus available resource. |
| `AoE4RPG_RebuildBlueprintTrackingLookup()` | Rebuilds the constant-time blueprint-to-civilization/class/role lookup table. |
| `add_blueprint_value(value, entry)` *(local)* | Recursively adds every blueprint variant from one registry row to the reverse lookup. |
| `AoE4RPG_GetBlueprintTrackingEntryForEntity(entity)` | Resolves an entity directly to its registered civilization, class, unit type, and role. |
| `AoE4RPG_IsRegisteredEntityBlueprint(entity)` | Reports whether an entity's current blueprint exists anywhere in the RPG registry. |
| `contains_blueprint(value)` *(local)* | Recursively searches one registry value for the entity blueprint used by the registration test. |
| `AoE4RPG_GetBlueprintStep(level)` | Maps an internal RPG level to its configured blueprint progression step. |
| `AoE4RPG_GetBlueprintForUnit(unit_type, civilization, level)` | Selects the appropriate blueprint variant for a unit type, civilization, and level. |
| `select_blueprint(raw_value)` *(local)* | Interprets a string, tier table, or structured blueprint row and selects its usable variant. |
| `AoE4RPG_GetUnitCivilization(entity, owner)` | Resolves civilization from the owning player's race, with registered-blueprint fallback. |
| `AoE4RPG_GetUniqueGrowthForClass(civilization, class_name)` | Returns civilization-specific attribute growth layered onto the class growth values. |
| `AoE4RPG_GetRegisteredHeroEntryForEntity(entity)` | Resolves a live entity to a registered hero/elite entry for systems that need role-filtered blueprint lookup. |

## `AoE4RPG_bootstrap.scar` — 9 functions

| Function | Use |
|---|---|
| `AoE4RPG_SetupSettings(options)` | Accepts host options and stores the module's initial settings. |
| `AoE4RPG_AdjustSettings()` | Applies supported setting adjustments after setup. |
| `AoE4RPG_UpdateModuleSettings()` | Propagates current settings to the initialized RPG modules. |
| `AoE4RPG_Initialize()` | Performs the main one-time initialization sequence. |
| `AoE4RPG_EarlyInitializations()` | Runs systems that must exist before ordinary play initialization. |
| `AoE4RPG_LateInitializations()` | Initializes UI and other systems that depend on earlier modules. |
| `AoE4RPG_OnPlay()` | Handles the match-start lifecycle, scans existing units, and activates runtime systems. |
| `AoE4RPG_OnGameOver()` | Removes registered events and interval rules during match shutdown. |
| `AoE4RPG_RegisterHooks()` | Connects AoE4RPG lifecycle callbacks to the host/UAGS hook tables. |
| `AoE4RPG_InitializePlayableUI()` | Creates the playable HUD presenters and starts the interval-driven selection monitor. |
| `AoE4RPG_OnInit()` | Cardinal initialization callback that starts simulation-safe RPG initialization. |
| `AoE4RPG_Start()` | Native Cardinal start callback that enters the playable RPG lifecycle. |

## `AoE4RPG_classes.scar` — 29 functions

| Function | Use |
|---|---|
| `AoE4RPG_CLASS_GetClassForEntity(entity)` | Resolves an entity's RPG class from ordered unit-type checks. |
| `AoE4RPG_ClassIsElite(entity)` | Determines whether an entity is a bodyguard elite whose class permits elite status. |
| `AoE4RPG_CLASS_GetExpMultiplier(entity, unit_data, mode)` | Returns `1.0` for a class-specific action and `0.5` for other actions before the separate human/AI match multiplier. |
| `AoE4RPG_CLASS_GetInitiatorGrowthProfile(entity)` | Selects Initiator growth for melee, ranged, or hybrid weapon profiles. |
| `AoE4RPG_CLASS_InitializeValueRegistry()` | Builds every civilization/class profile from blueprint-backed base and growth data at match start. |
| `AoE4RPG_CLASS_GetValueProfile(civilization, class_name)` | Returns the cached class profile used by live EntityIDs. |
| `AoE4RPG_CLASS_RegisterEntity(entity, civilization, class_name)` | Adds an eligible EntityID and its synchronized progress record to a class profile. |
| `AoE4RPG_CLASS_UnregisterEntity(entity_id)` | Removes a dead or replaced EntityID from its class profile. |
| `AoE4RPG_CLASS_GetEntityProfile(entity_or_id)` | Resolves an active EntityID to its cached civilization/class profile. |
| `AoE4RPG_CLASS_GetEntityProgress(entity_or_id)` | Returns the EntityID-owned `damage_dealt`, level, and pending-level state stored in the class profile. |
| `AoE4RPG_CLASS_GetPendingLevelCount(entity, unit_data)` | Calculates how many ordinary level thresholds the tracked `damage_dealt` value can currently pay. |
| `AoE4RPG_CLASS_SyncEntityProgress(entity, unit_data)` | Mirrors XP and level state into the class profile and tracker record after XP, spawn, or level-up changes. |
| `AoE4RPG_CLASS_ReapplyEntityBonuses(entity, unit_data)` | Rebuilds cached class modifiers and reapplies already-selected bonuses after a level increase. |
| `AoE4RPG_CLASS_GetEntityValues(entity, unit_data)` | Combines cached class values with the entity's level and persistent bonuses for UI. |
| `AoE4RPG_CLASS_ApplyCachedProfileToEntity(entity, unit_data, profile)` | Rebuilds class modifiers and derived state for a fresh or converted entity. |
| `AoE4RPG_CLASS_RemoveEntityModifiers(entity_id, unit_data)` | Removes tracked class modifier handles before death or rebind. |
| `AoE4RPG_CLASS_ApplyGrowth(entity, class_name, level)` | Applies one level of class and civilization attribute growth plus class-specific effects. |
| `AoE4RPG_CLASS_BindUnit(entity)` | Stores the resolved class and civilization on an entity's RPG data record. |
| `AoE4RPG_CLASS_GetAbilityTotalCost(player, ability)` | Reads and totals an ability's reported resource costs for strategist health-cost conversion. |
| `AoE4RPG_CLASS_ApplyStrategistAbilityEffects(entity, ability, owner)` | Applies incremental recharge, delay, cast, and channeling effects for observed strategist abilities. |
| `AoE4RPG_CLASS_ReapplyStrategistAbilityEffects(entity, unit_data)` | Reapplies only the difference for previously observed abilities after strategist growth. |

## `AoE4RPG_core.scar` — 29 functions

| Function | Use |
|---|---|
| `AoE4RPG_GetUnitData(entity_id)` | Creates or returns the persistent RPG record for an entity ID. |
| `AoE4RPG_MarkUnitDataChanged(unit_data)` | Increments the record revision used to avoid unnecessary UI refreshes. |
| `AoE4RPG_EnableCriticalHits(entity)` | Applies the one-time engine modifier that enables configured critical hits. |
| `AoE4RPG_EnableCriticalHitsForRegisteredUnits()` | Enables critical-hit support for all currently registered RPG entities. |
| `AoE4RPG_ExperienceRequired(level)` | Calculates the XP threshold required to advance from an internal level. |
| `AoE4RPG_GetPrimaryStatBonus(class_name)` | Returns the class definition's primary-stat coefficient. |
| `AoE4RPG_TranslateAttributesToStats(unit_data)` | Converts accumulated attributes and bonuses into the record's derived statistics. |
| `AoE4RPG_AssignEntityRole(entity, unit_data)` | Resolves and stores mutually exclusive hero/elite role flags. |
| `AoE4RPG_ApplyDeathPenalty(entity, unit_data)` | Applies hero XP loss, elite level loss, or the applicable role-specific death rule. |
| `AoE4RPG_GetSpecialLevelingRule(entity, unit_data)` | Returns the civilization/class rule for Jeanne or four-tier Khan progression. |
| `AoE4RPG_GetLevelBracketsForUnit(entity, unit_data)` | Selects ordinary five-bracket or special four-bracket progression. |
| `AoE4RPG_GetLevelBracketStep(level, entity, unit_data)` | Converts an internal level into its current bonus/upgrade bracket number. |
| `AoE4RPG_ApplyAttributeStats(entity, unit_data)` | Applies translated attributes and class damage changes to the live entity. |
| `AoE4RPG_GetEffectiveLevelLimit(entity, unit_data)` | Returns the elite, normal hero, or special-unit level cap. |
| `AoE4RPG_ApplySingleLevelIncrease(entity, owner, unit_data, grant_bonus, play_sound)` | Performs one level increase, growth application, bracket reward, bonus offer, and optional sound. |
| `AoE4RPG_GetNativeExperienceTargetLevel(total_experience, leveling_rule)` | Maps Jeanne's native cumulative XP into the corresponding internal RPG level. |
| `AoE4RPG_SynchronizeNativeExperience(entity, owner, unit_data)` | Reads native Jeanne XP and mirrors its level into AoE4RPG without replacing native progression. |
| `AoE4RPG_MonitorNativeExperience()` | Periodically synchronizes every tracked entity using native experience. |
| `AoE4RPG_InitializeNativeExperienceMonitor()` | Starts the native-experience interval rule once when needed. |
| `AoE4RPG_ShutdownNativeExperienceMonitor()` | Removes the native-experience interval rule. |
| `AoE4RPG_PlayLevelUpSound(owner, reached_new_bracket)` | Plays the correct local level-up or bracket-up sound. |
| `AoE4RPG_LevelUp(context)` | Handles positive damage events, awards attacker/victim XP, applies the configured human/AI XP multiplier, and checks levels. |
| `AoE4RPG_CalculateAttackerExp(attacker, victim, damage, attacker_owner, victim_owner, unit_data)` | Calculates damage XP and the killing-blow bonus while updating damage and kill counters. |
| `AoE4RPG_CalculateVictimExp(victim, attacker, damage, victim_owner, attacker_owner, unit_data)` | Calculates XP awarded for taking damage. |
| `AoE4RPG_CheckAndApplyLevelUp(entity, owner, unit_data, grant_bonus)` | Consumes XP thresholds, preserves overflow, and applies as many earned levels as allowed. |
| `AoE4RPG_CalculateClassDamageBonus(entity, unit_data)` | Calculates the aggregate class damage bonus from primary stats and live state. |
| `AoE4RPG_ApplyBracketUpgrade(entity, owner, class_name, bracket_index)` | Applies each bracket's one-time weapon-damage modifier. |
| `AoE4RPG_ApplyStatModifier(entity, stat_name, value)` | Converts logical attack-speed, armor, health, or damage gains into engine modifiers. |
| `AoE4RPG_OnEntityKilled(context)` | Forwards tracker death handling and applies the victim's RPG death penalty. |
| `AoE4RPG_AddExperience(unit_data, amount, entity_id)` | Adds ordinary combat/support XP to `damage_dealt` and synchronizes the tracked EntityID progress record. |

## `AoE4RPG_conversion.scar` — 15 functions

| Function | Use |
|---|---|
| `AoE4RPG_CONVERSION_Initialize()` | Caches the supported conversion ability blueprints and their XML-defined ranges. |
| `AoE4RPG_CONVERSION_GetAbilityPbgid(ability)` | Resolves an executed ability object or pbgid to a supported conversion ability identifier. |
| `AoE4RPG_CONVERSION_GetAbilityRange(ability_pbgid)` | Returns the configured conversion range for a supported ability. |
| `AoE4RPG_CONVERSION_IsEligibleCaster(entity)` | Allows registered heroes/elites while excluding normal and combat monks. |
| `AoE4RPG_CONVERSION_ResolveCaster(context, ability_pbgid)` | Uses the event executor first, then resolves one unambiguous matching owner from stored hero/elite EntityIDs and its entity/squad ability. |
| `AoE4RPG_CONVERSION_GetElapsedTime()` | Returns the conversion monitor's deterministic elapsed time. |
| `AoE4RPG_CONVERSION_GetDistance(first_entity, second_entity)` | Calculates the distance between the caster and a possible conversion victim. |
| `AoE4RPG_CONVERSION_GetExperienceValue(entity)` | Converts a victim's maximum health into the 50% conversion XP award. |
| `AoE4RPG_CONVERSION_GrantExperience(cast, entity)` | Adds one victim's conversion XP to the caster's canonical `damage_dealt` field and prevents duplicates. |
| `AoE4RPG_CONVERSION_OnAbilityExecuted(context)` | Starts a range- and time-limited conversion tracking window for an eligible caster. |
| `AoE4RPG_CONVERSION_IsPending(cast)` | Tests whether a recorded conversion cast is still inside its tracking window. |
| `AoE4RPG_CONVERSION_MonitorOwnerChanges()` | Detects nearby enemy-to-caster ownership changes produced by the conversion state tree. |
| `AoE4RPG_CONVERSION_OnEntityKilled(context)` | Awards conversion XP for nearby population-cap deaths that have no combat killer. |
| `AoE4RPG_CONVERSION_StartMonitor()` | Starts the ownership-change polling rule once. |
| `AoE4RPG_CONVERSION_StopMonitor()` | Removes the polling rule and clears pending conversion state at match end. |
| `EGroup_ForEach callback(group_id, index, entity)` *(anonymous)* | Processes each world entity during ownership-change detection. |

## `AoE4RPG_ability_list.scar` — 3 functions

Register each RPG ability in `AoE4RPG.ABILITY_LIST`. Keep the ability's
`hp_cost` and effect fields in the same row so the cost and effect data can be
looked up together. For example:

```lua
{ ability_name = "hero_ability", hp_cost = 50,
  skill_type = "passive",
  effect_name = "damage", amount = 50, radius = 3,
  affects = "enemies" },
``` 

For an attack-count armor shred, use `track_attack_counts` with a nested
`armor_shred` effect. With `required_attacks = 3`, levels 1/2/3+ trigger after
3/2/1 landed damage events respectively. Set `damage_type` explicitly for fire;
melee, ranged, and siege can also be inferred from the attacker:

```lua
{ ability_name = "hero_armor_shred", hp_cost = 0,
  skill_type = "passive", marker_type = "owner",
  effect_name = "track_attack_counts", required_attacks = 3,
  effect_id = "hero_armor_shred", effect_level = 1,
  apply_effect = "armor_shred",
  apply_effect_data = { amount = 1, damage_type = "melee" } },
```

Use `skill_type = "passive"` for passive skills. Use `skill_type = "unique"` for unique skills; they are supplied by their XML/Squad loadout and use the hero's current bracket for effect level, cost, and cooldown scaling. Mongol and Golden Horde
Khan restrictions in `AoE4RPG_blueprints.scar` only allow those rows.

| Function | Use |
|---|---|
| `AoE4RPG_ABILITY_LIST_Get(ability)` | Looks up an ability row by name, PBGID, or resolved blueprint. |
| `AoE4RPG_ABILITY_LIST_GetEffectLevel(entry, owner)` | Resolves the selected skill level for an ability-list row. |
| `AoE4RPG_ABILITY_LIST_GetEffectData(ability)` | Returns a copy of the complete ability row, including `hp_cost` and effect values. |

## `AoE4RPG_ability_cost.scar` — 8 functions

HP costs are configured as `hp_cost` in `AoE4RPG.ABILITY_LIST`; this module
resolves those rows and synchronizes the Debug state-model health resource.
The direct `hp_cost` number is removed from maximum health for the verified
hero/elite that casts the registered ability; no percentage conversion is
applied.

| Function | Use |
|---|---|
| `AoE4RPG_ABILITY_COST_CalculateEntryTotalCost(entry, owner)` | Returns `hp_cost` scaled by 20% for each additional effect level. |
| `AoE4RPG_ABILITY_COST_Initialize()` | Resolves registered ability blueprints for HP-cost lookup. |
| `AoE4RPG_ABILITY_COST_GetEntry(ability)` | Looks up a registered cost row by ability blueprint. |
| `AoE4RPG_ABILITY_COST_GetTotalCost(ability, owner)` | Returns the level-scaled total, or `nil` when the ability is not registered. |
| `AoE4RPG_ABILITY_COST_SyncHealthResource(entity)` | Writes current HP to the existing `Debug` entity state-model float. |
| `AoE4RPG_ABILITY_COST_SyncTrackedHealthResources()` | Synchronizes the state-model float for every tracked hero/elite. |
| `AoE4RPG_ABILITY_COST_StartHealthResourceMonitor()` | Starts the 0.125-second health-resource synchronization interval. |
| `AoE4RPG_ABILITY_COST_StopHealthResourceMonitor()` | Stops the health-resource synchronization interval at game over. |

## `AoE4RPG_debug_cheat.scar` — 3 functions

| Function | Use |
|---|---|
| `AoE4RPG_DebugCheat_IDDQD(player_id, data)` | Debug-cheat handler that grants selected eligible units enough RPG XP for the next level. I love Doom. Realllllyyyyyy much.|
| `grant_required_exp(group_id, index, squad_id)` *(local)* | Processes one selected squad and routes the required XP through normal level-up logic. |
| `AoE4RPG_DebugCheat_Init()` | Registers the AoE4RPG IDDQD cheat handler. |

## `AoE4RPG_entity_tracker.scar` — 25 functions

| Function | Use |
|---|---|
| `AoE4RPG_ENTITY_TRACKER_GetPlayerIdentifier(player)` | Normalizes a player object or number into a numeric player ID. |
| `AoE4RPG_ENTITY_TRACKER_ResolveLocalPlayer()` | Caches the local player, civilization, hero checks, and elite-only class exclusions. |
| `AoE4RPG_ENTITY_TRACKER_HasRemainingHeroChecks()` | Reports whether any configured hero class still needs discovery. |
| `AoE4RPG_ENTITY_TRACKER_GetHeroClassRemainingCheck(class_name)` | Returns a class's strict remaining hero state of `1` or `0`. |
| `AoE4RPG_ENTITY_TRACKER_HasRemainingEliteClassCapacity(class_name)` | Checks fixed elite capacity or keeps a dynamic-resource class event-ready. |
| `AoE4RPG_ENTITY_TRACKER_HasAnyRemainingEliteCapacity()` | Reports whether production events may still produce a trackable elite. |
| `AoE4RPG_ENTITY_TRACKER_ShouldCheckNewEntity()` | Combines outstanding hero discovery and elite capacity into the event prefilter. |
| `AoE4RPG_ENTITY_TRACKER_TrackEntity(entity)` | Validates, classifies, records, initializes, and restores one hero or elite. |
| `AoE4RPG_ENTITY_TRACKER_ScanExistingLocalPlayerEntities()` | Performs the one-time local-player scan for heroes/elites already on the map. |
| `AoE4RPG_ENTITY_TRACKER_OnBuildItemComplete(context)` | Tracks a matching local unit immediately after `GE_BuildItemComplete`. |
| `AoE4RPG_ENTITY_TRACKER_OnEntityKilled(context)` | Removes a dead tracked ID, updates capacity, and reopens only appropriate searches. |
| `AoE4RPG_ENTITY_TRACKER_GetSpecialRespawnRule(class_name)` | Returns the civilization/class respawn behavior for Jeanne or Khan. |
| `AoE4RPG_ENTITY_TRACKER_CacheSpecialRespawnExecutedAbilityBlueprints()` | Builds the buyback-ability lookup used by the ability event callback. |
| `AoE4RPG_ENTITY_TRACKER_GetSpecialRespawnEntryForExecutedAbility(ability_blueprint)` | Resolves an executed ability to its cached special-respawn entry. |
| `AoE4RPG_ENTITY_TRACKER_GetAbilityExecutingPlayerIdentifier(context)` | Extracts the executing player's ID from supported ability-event context fields. |
| `AoE4RPG_ENTITY_TRACKER_OnAbilityExecuted(context)` | Activates and immediately checks Jeanne's pending buyback respawn search. |
| `AoE4RPG_ENTITY_TRACKER_FindAndTrackSpecialRespawnClass(class_name)` | Narrowly scans the local player's entities for one pending special hero class. |
| `AoE4RPG_ENTITY_TRACKER_StopSpecialRespawnMonitorIfIdle()` | Removes the respawn monitor after all pending special classes are found. |
| `AoE4RPG_ENTITY_TRACKER_CompleteSpecialRespawnForClass(class_name)` | Clears a class's pending respawn state after successful rediscovery. |
| `AoE4RPG_ENTITY_TRACKER_MonitorSpecialRespawns()` | Watches native respawn timing and performs scans only when a pending class becomes eligible. |
| `AoE4RPG_ENTITY_TRACKER_BeginSpecialRespawnForClass(class_name)` | Starts the temporary Jeanne/Khan respawn monitor after death. |
| `AoE4RPG_ENTITY_TRACKER_IsTrackedEntityIdentifier(entity_id)` | Performs constant-time tracked-ID membership testing for UI selection. |
| `AoE4RPG_ENTITY_TRACKER_ForEachTrackedEntity(callback)` | Invokes a caller callback for every valid tracked hero or elite. |
| `AoE4RPG_ENTITY_TRACKER_Initialize()` | Builds lookups and registers production and supported ability events once. |
| `AoE4RPG_ENTITY_TRACKER_Shutdown()` | Removes tracker events and temporary monitoring rules. |

## `AoE4RPG_hero_ui.scar` — 11 functions

| Function | Use |
|---|---|
| `AoE4RPG_UI_NormalizeEntity(value)` | Converts supported entity values into an entity object and entity ID. |
| `AoE4RPG_UI_UpdateHeroAttributes(entity)` | Shows, hides, and fills the selected hero/elite attribute and XP context. |
| `AoE4RPG_UI_CreateHeroAttributesUI()` | Constructs the selected-unit attribute panel and its XAML bindings. |
| `AoE4RPG_UI_BuildXPBar(current_xp, required_xp, width)` | Produces the compact XP progress bar. |
| `AoE4RPG_UI_GetHeroProgressText(entity)` | Formats one tracked entity's class, level, and XP progress line. |
| `AoE4RPG_UI_CreateHeroPanel(name)` | Creates a stored hero-progress panel record. |
| `AoE4RPG_UI_RefreshHeroProgress()` | Rebuilds the progress panel entries from valid tracked IDs. |
| `ForEachTrackedEntity callback(entity, entity_id)` *(anonymous)* | Adds one tracked hero/elite's formatted progress text during refresh. |
| `AoE4RPG_UI_InitializeHeroesDisplay()` | Creates and initially populates the hero progress display. |
| `AoE4RPG_UI_UpdateHeroesDisplay()` | Refreshes the tracked hero display through its public update entry point. |
| `AoE4RPG_UI_InitializeHeroBar()` | Compatibility initializer that starts the hero display/UI setup. |

## `AoE4RPG_ui.scar` — additional functions

| `AoE4RPG_UI_IsHeroUnitType(entity)` | Checks the selected entity against every configured RPG unit type and the bodyguard type for interval-driven hero UI display. |

## `AoE4RPG_random_bonus.scar` — 13 functions

| Function | Use |
|---|---|
| `AoE4RPG_BONUS_GetPlayerIdentifier(player)` | Normalizes player objects/numbers for ownership and command validation. |
| `AoE4RPG_BONUS_IsDefinitionEligible(entity, definition)` | Tests melee, ranged, siege, and other eligibility requirements for one bonus. |
| `AoE4RPG_BONUS_GetEligibleDefinitionKeys(entity)` | Returns every random-bonus key the entity is allowed to receive. |
| `AoE4RPG_BONUS_GenerateChoices(entity, bracket_index)` | Creates the fixed three-choice offer: listed bonus, bracket-scaled primary attribute, and Ability_List skill. |
| `AoE4RPG_BONUS_HasQueuedOffer(unit_data, bracket_index)` | Prevents duplicate queued offers for the same entity and bracket. |
| `AoE4RPG_BONUS_CreateOffer(entity, owner, bracket_index)` | Creates and queues one bracket's three-choice bonus offer. |
| `AoE4RPG_BONUS_EnsureCurrentBracketOffer(entity)` | Ensures a tracked hero/elite has the offer required by its current bracket. |
| `AoE4RPG_BONUS_CreateInitialOffersForRegisteredUnits()` | Creates starting offers for registered units already present when play begins. |
| `AoE4RPG_BONUS_GetActiveOffer(entity_id)` | Returns the first pending offer for an entity. |
| `AoE4RPG_BONUS_ApplyDefinition(entity, unit_data, definition_key)` | Adds the chosen bonus to cumulative derived stats and applies its live modifier. |
| `AoE4RPG_BONUS_ApplyHealthPerAttack(attacker, unit_data)` | Heals an eligible melee attacker after a confirmed positive-damage attack. |
| `AoE4RPG_SelectBracketBonus(sending_player, data)` | Validates a synchronized player choice, applies it, removes the offer, and refreshes UI. |
| `AoE4RPG_BONUS_Initialize()` | Registers the synchronized bonus-selection command and initializes starting offers. |

## `AoE4RPG_random_bonus_ui.scar` — 6 functions

| Function | Use |
|---|---|
| `AoE4RPG_BONUS_UI_Hide()` | Hides and clears the three-choice bonus panel context. |
| `AoE4RPG_BONUS_UI_IsLocallyOwned(entity)` | Ensures bonus choices are shown only for the local player's entity. |
| `AoE4RPG_BONUS_UI_UpdateForEntity(entity)` | Populates or hides the bonus UI for the selected tracked entity's active offer. |
| `AoE4RPG_BONUS_UI_SelectChoice(choice_parameter)` | Sends a selected choice through the synchronized bonus command. |
| `AoE4RPG_BONUS_UI_OnSelectionApplied(entity_id)` | Refreshes the panel after a choice has been accepted. |
| `AoE4RPG_BONUS_UI_Initialize()` | Creates the left-side vertical three-choice UI and binds its actions. |

## `AoE4RPG_ui.scar` — 11 functions

| Function | Use |
|---|---|
| `AoE4RPG_UI_CreatePanel(name, title)` | Creates and stores a basic non-XAML panel record. |
| `AoE4RPG_UI_UpdateSelectedUnitPanel(entity)` | Copies the selected unit's class, level, and XP into the status record. |
| `AoE4RPG_UI_Initialize()` | Creates the base unit-status panel. |
| `AoE4RPG_UI_GetSingleSelectedEntity()` | Returns an entity only when the local player has exactly one squad selected. |
| `SGroup_ForEach callback(group_id, index, squad_id)` *(anonymous)* | Extracts the selected squad's first entity during selection resolution. |
| `AoE4RPG_UI_UpdateSelectionState(force_update)` | Detects selection/data revision changes and updates or hides hero and bonus UI. |
| `AoE4RPG_UI_MonitorSelection()` | Lightweight every-tick entry point for cached selection-state checking. |
| `AoE4RPG_UI_StartSelectionMonitor()` | Starts the selection rule once and performs an immediate refresh. |
| `AoE4RPG_UI_StopSelectionMonitor()` | Removes the selection monitoring rule. |
| `AoE4RPG_UI_RefreshSelection()` | Forces the current selection to be recalculated and redrawn. |
| `AoE4RPG_UI_CheckSelectionChange()` | Compatibility entry point that forwards to the forced selection refresh. |
