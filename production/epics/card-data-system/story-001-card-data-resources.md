# Story 001: CardData and CardEffect Resource Classes

> **Epic**: Card Data System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/card-data-system.md`
**Requirements**: `TR-CD-001` (CardData as Godot Resource), `TR-CD-002` (CardEffect as nested Resource)

**ADR Governing Implementation**: ADR-0004: Data Resource Architecture
**ADR Decision Summary**: Static game data uses Godot Resources (.tres). Nested sub-resources (CardData → Array[CardEffect]) require `duplicate_deep()` (4.5+) when per-instance copies are needed at runtime.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `duplicate_deep()` was added in Godot 4.5 and is required for deep-copying CardData with its nested `Array[CardEffect]`. Shallow `duplicate()` will leave nested CardEffects as shared references. Verify `duplicate_deep()` correctly deep-copies `Array[Resource]` fields in 4.6 before any runtime mutation is attempted. For MVP, CardData resources are read-only at runtime — no duplication needed yet.

**Control Manifest Rules (Foundation)**:
- Required: Static game data uses Godot Resources (.tres). CardData and CardEffect are `extends Resource`.
- Required: Use `duplicate_deep()` (4.5+) when copying Resources with nested sub-resources. Never use `duplicate()` for CardData.
- Required: All cross-system enums live in the Enums autoload (`src/core/enums.gd`). CardData fields must reference `Enums.CardType`, `Enums.CardArchetype`, `Enums.CardRarity`, `Enums.TargetingMode`, `Enums.EffectType`, `Enums.TargetingMode`.
- Forbidden: Never store game data in JSON/YAML.
- Forbidden: Never hardcode gameplay values in GDScript. All tuning values on exported Resource fields.

---

## Acceptance Criteria

- [ ] `src/foundation/data/card_data.gd` exists with `class_name CardData extends Resource`
- [ ] `src/foundation/data/card_effect.gd` exists with `class_name CardEffect extends Resource`
- [ ] All 22 exported fields from GDD S.1 are present on CardData with correct GDScript types (see field table below)
- [ ] All 8 exported fields from GDD E.1 are present on CardEffect with correct GDScript types
- [ ] CardData.effects is typed as `Array[CardEffect]`
- [ ] An `EffectCondition` Resource class exists (referenced by CardEffect.conditions) OR conditions are represented as a typed structure — decision documented
- [ ] Both resources can be created in the Godot editor inspector (no script errors on instantiation)
- [ ] A new CardData .tres file authored in the editor with all required fields set loads without error via `load()`
- [ ] A CardData with 3 nested CardEffects loads and `card_data.effects[2]` returns the third effect correctly typed

---

## Field Reference

### CardData Fields (GDD S.1)

| Field | GDScript Type | Export Hint | Default | Notes |
|-------|---------------|-------------|---------|-------|
| `card_id` | `StringName` | `@export` | `&""` | Required — registry rejects if empty |
| `display_name` | `String` | `@export` | `""` | Required |
| `description` | `String` | `@export_multiline` | `""` | Supports `{variable}` substitution tokens |
| `card_type` | `Enums.CardType` | `@export` | `Enums.CardType.ATTACK` | Required |
| `archetype` | `Enums.CardArchetype` | `@export` | `Enums.CardArchetype.NEUTRAL` | Required |
| `rarity` | `Enums.CardRarity` | `@export` | `Enums.CardRarity.COMMON` | |
| `effects` | `Array[CardEffect]` | `@export` | `[]` | Required — may be empty (legal, see Edge Cases) |
| `targeting` | `Enums.TargetingMode` | `@export` | `Enums.TargetingMode.DIRECTIONAL` | |
| `cooldown_frames` | `int` | `@export_range(0, 300)` | `0` | Frames, not seconds |
| `animation_key` | `StringName` | `@export` | `&""` | Required — key into Animation State Machine |
| `windup_frames` | `int` | `@export_range(0, 60)` | `12` | |
| `active_frames` | `int` | `@export_range(1, 30)` | `4` | |
| `recovery_frames` | `int` | `@export_range(0, 60)` | `8` | |
| `card_art` | `Texture2D` | `@export` | `null` | Placeholder acceptable for MVP |
| `card_color` | `Color` | `@export` | `Color.WHITE` | Derived from archetype at authoring time |
| `sfx_play` | `AudioStream` | `@export` | `null` | |
| `sfx_impact` | `AudioStream` | `@export` | `null` | |
| `shake_intensity` | `float` | `@export_range(0.0, 10.0)` | `0.0` | |
| `upgraded` | `bool` | `@export` | `false` | |
| `upgrade_card_id` | `StringName` | `@export` | `&""` | Empty = no upgrade path |
| `tags` | `Array[StringName]` | `@export` | `[]` | Freeform, no validation |
| `tooltip_extra` | `String` | `@export_multiline` | `""` | |

### CardEffect Fields (GDD E.1)

| Field | GDScript Type | Export Hint | Default | Notes |
|-------|---------------|-------------|---------|-------|
| `effect_type` | `Enums.EffectType` | `@export` | `Enums.EffectType.DAMAGE` | |
| `value` | `float` | `@export` | `0.0` | Primary numeric: damage, heal, distance, etc. |
| `secondary_value` | `float` | `@export` | `0.0` | Radius, knockback, speed — effect-type-dependent |
| `target_override` | `Enums.TargetingMode` | `@export` | `Enums.TargetingMode.DIRECTIONAL` | Use a sentinel value or INHERIT pattern — see Implementation Notes |
| `status_effect_id` | `StringName` | `@export` | `&""` | Used when effect_type == APPLY_STATUS |
| `status_duration_frames` | `int` | `@export_range(0, 600)` | `0` | |
| `vfx_key` | `StringName` | `@export` | `&""` | Spawned on resolution |
| `conditions` | `Array[EffectCondition]` | `@export` | `[]` | AND-evaluated — all must be true to fire |

---

## Implementation Notes

**EffectCondition representation**: GDD E.3 defines 6 named condition types (`HP_BELOW_PERCENT`, `HAS_STATUS`, etc.) with threshold parameters. For MVP, implement `EffectCondition` as a Resource (`src/foundation/data/effect_condition.gd`) with an exported `condition_type` enum field and a `threshold` float/int field. This is editor-authorable and extensible. A Dictionary-based approach is explicitly rejected (not type-safe, not editor-inspectable).

**`target_override` sentinel**: CardEffect needs to express "inherit targeting from parent CardData" vs. an explicit override. Add a `INHERIT = -1` or `NONE = 0` sentinel value to the `TargetingMode` enum in `src/core/enums.gd` (Story 001 entity-framework ensures this autoload exists). Alternatively, add a separate `bool` field `override_targeting` — consult with game-designer on preference before implementing. Default behavior: if `target_override` equals the sentinel, the card-level targeting is used.

**File locations**:
- `src/foundation/data/card_data.gd`
- `src/foundation/data/card_effect.gd`
- `src/foundation/data/effect_condition.gd`

**No autoload required**: These are pure Resource class definitions. CardRegistry (Story 002) is the autoload that loads instances.

**Frames vs seconds**: All timing fields (`windup_frames`, `active_frames`, `recovery_frames`, `cooldown_frames`, `status_duration_frames`) are integer frame counts at 60 fps per Control Manifest rules.

---

## Out of Scope

- Story 002: CardRegistry autoload (loads and indexes .tres instances of these classes)
- Story 003: Authoring the 10 starter card .tres files
- Story 004: Description variable substitution logic
- CardData runtime mutation (requires `duplicate_deep()` — post-MVP)
- EffectCondition runtime evaluation (belongs to Combat System / Card Hand System)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: Automated unit test — must pass (`tests/unit/card_data/`)
**Gate level**: BLOCKING
**Status**: [x] `tests/unit/card_data/card_data_resource_test.gd` — 9 test cases

### QA Test Cases

| ID | Scenario | Input | Expected Result | Pass/Fail |
|----|----------|-------|-----------------|-----------|
| T-001-01 | CardData instantiates with all default values | `CardData.new()` | No error; `card_id == &""`, `rarity == COMMON`, `effects == []`, `cooldown_frames == 0`, `upgraded == false` | [ ] |
| T-001-02 | CardEffect instantiates with all default values | `CardEffect.new()` | No error; `value == 0.0`, `secondary_value == 0.0`, `conditions == []` | [ ] |
| T-001-03 | CardData accepts Array[CardEffect] | Assign array of 3 `CardEffect` instances to `effects` | `card_data.effects.size() == 3`; each element is typed `CardEffect` | [ ] |
| T-001-04 | Nested CardEffect is accessible by index | CardData with effects[0], effects[1], effects[2] | `card_data.effects[2].effect_type` returns correct `EffectType` enum value | [ ] |
| T-001-05 | CardData.tags stores StringName array | Assign `[&"fire", &"movement"]` to `tags` | `card_data.tags[0] == &"fire"` | [ ] |
| T-001-06 | All exported fields survive .tres round-trip | Author CardData in editor with all fields set; save; reload | All fields read back with identical values and types | [ ] |
| T-001-07 | EffectCondition instantiates without error | `EffectCondition.new()` | No error; default fields accessible | [ ] |
| T-001-08 | CardData with zero effects is legal | CardData where `effects == []` | No crash; `effects.is_empty() == true` | [ ] |

---

## Dependencies

- **Depends on**: Entity Framework Story 001 (Shared Enums autoload — `src/core/enums.gd` must exist with CardArchetype, CardRarity, CardType, EffectType, TargetingMode enums)
- **Unlocks**: Story 002 (CardRegistry — needs CardData class to exist), Story 003 (starter .tres files — needs the class definition), Story 004 (description substitution — operates on CardData.description)
