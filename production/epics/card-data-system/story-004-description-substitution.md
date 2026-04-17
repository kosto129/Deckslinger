# Story 004: Card Description Variable Substitution

> **Epic**: Card Data System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/card-data-system.md`
**Requirements**: `TR-CD-005` (variable substitution in card description strings), GDD AC #13

**ADR Governing Implementation**: ADR-0004: Data Resource Architecture
**ADR Decision Summary**: CardData.description is a String field with `{token}` placeholders. Substitution resolves tokens against the card's effects array at display time. CardData is read-only — substitution produces a new String, never mutates the resource.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: GDScript `String.format()` accepts a Dictionary and replaces `{key}` tokens — this is the idiomatic approach. Verify behavior when a key exists in the format dictionary but maps to a float (verify rounding behavior; use `int(value)` before inserting to avoid "15.0" instead of "15"). If a token is present in the description but absent from the dictionary, Godot 4.6's `String.format()` leaves the token unreplaced (no crash) — this is the correct fallback per GDD Edge Cases.

**Control Manifest Rules (Foundation)**:
- Required: CardData is read-only at runtime. Substitution returns a new String — never write to `CardData.description`.
- Required: All cross-system enums live in Enums autoload. Substitution logic reads `Enums.EffectType` to map tokens to effect fields.
- Forbidden: Never hardcode gameplay values in GDScript. The values substituted come from CardEffect fields, not from inline constants.

---

## Acceptance Criteria

- [ ] A static method (or utility function) `resolve_description(card: CardData) -> String` exists, accessible from Card Hand UI and tooltips
- [ ] `"Deal {damage} damage"` resolves to `"Deal 15 damage"` for a card with a DAMAGE effect where `value == 15.0`
- [ ] `"Dash {distance} pixels"` resolves to `"Dash 80 pixels"` for a card with a MOVE_SELF effect where `value == 80.0`
- [ ] `"Gain {shield} shield"` resolves to `"Gain 20 shield"` for a card with a SHIELD effect where `value == 20.0`
- [ ] `"Draw {draw} card"` resolves to `"Draw 1 card"` for a card with a DRAW_CARDS effect where `value == 1.0`
- [ ] Float values are rendered as integers in substitution output (15.0 → "15", not "15.0")
- [ ] An unknown token (no matching effect) is left unreplaced in the output — no crash
- [ ] A card with zero effects and a description containing no tokens resolves correctly (returns the description unchanged)
- [ ] A card with multiple effects resolves tokens from the first matching effect for each token type

---

## Token-to-Effect Mapping

The substitution system maps description tokens to CardEffect fields by scanning `CardData.effects` in array order and extracting values based on `effect_type`.

| Token | Source Effect Type | Source Field | Notes |
|-------|--------------------|--------------|-------|
| `{damage}` | DAMAGE or AOE_DAMAGE | `effect.value` | First DAMAGE or AOE_DAMAGE effect in the array |
| `{heal}` | HEAL | `effect.value` | First HEAL effect |
| `{shield}` | SHIELD | `effect.value` | First SHIELD effect |
| `{distance}` | MOVE_SELF | `effect.value` | First MOVE_SELF effect |
| `{speed}` | MOVE_SELF | `effect.secondary_value` | First MOVE_SELF effect |
| `{draw}` | DRAW_CARDS | `effect.value` | First DRAW_CARDS effect |
| `{discard}` | DISCARD | `effect.value` | First DISCARD effect |
| `{radius}` | AOE_DAMAGE | `effect.secondary_value` | First AOE_DAMAGE effect |
| `{knockback}` | DAMAGE | `effect.secondary_value` | First DAMAGE effect with secondary_value > 0 |
| `{status}` | APPLY_STATUS | `effect.status_effect_id` | StringName rendered as String |
| `{duration}` | APPLY_STATUS | `effect.status_duration_frames` | Rendered as integer frames |
| `{projectile_damage}` | SPAWN_PROJECTILE | `effect.value` | First SPAWN_PROJECTILE effect |

---

## API Specification

```gdscript
# Location: src/foundation/data/card_description_resolver.gd
class_name CardDescriptionResolver

## Resolves {token} placeholders in a CardData description string.
## Returns a new String — never mutates the CardData resource.
## All float values are cast to int before substitution.
## Unknown tokens are left unreplaced (no crash).
##
## Parameters:
##   card — the CardData whose description and effects are used
##
## Returns:
##   Resolved description String ready for display in Card Hand UI or tooltip.
static func resolve(card: CardData) -> String
```

### Internal Flow

```
resolve(card):
  1. Build a Dictionary of token_name -> String value
     by iterating card.effects in order:
       For each CardEffect, check effect.effect_type:
         If DAMAGE or AOE_DAMAGE and "damage" not yet in dict:
           dict["damage"] = str(int(effect.value))
         If HEAL and "heal" not yet in dict:
           dict["heal"] = str(int(effect.value))
         ... (repeat for each token per mapping table above)
  2. Return card.description.format(dict)
     - format() leaves unreplaced any token whose key is absent from dict
     - No error on missing tokens
```

---

## Worked Example (GDD AC #13)

**Input card**:
- `description = "Deal {damage} damage"`
- `effects[0] = CardEffect(effect_type=DAMAGE, value=15.0)`

**Substitution dictionary built**:
```
{ "damage": "15" }
```

**`String.format()` call**:
```gdscript
"Deal {damage} damage".format({"damage": "15"})
# Result: "Deal 15 damage"
```

**Verification**: GDD AC #13 states `{damage}` resolves to `"Deal 15 damage"` for a card with DAMAGE effect `base_value=15`. GDD uses the term `base_value` — the corresponding field on CardEffect is `value`. Confirmed: `effect.value == 15.0` → `str(int(15.0)) == "15"`.

---

## Edge Cases

**Token with no matching effect**:
- Description: `"Deal {damage} damage and apply {status}"`, effects contains only a DAMAGE effect
- `{status}` has no matching APPLY_STATUS effect
- Substitution dict: `{"damage": "15"}`
- `String.format()` output: `"Deal 15 damage and apply {status}"`
- The unresolved token is visible to the player — this is a content authoring bug, not a runtime error. Design validation should flag descriptions with tokens that have no corresponding effect.

**Effect value is 0.0**:
- `effect.value == 0.0` → token substitutes as `"0"` — this is correct and intentional. A shield with 0 HP is a design bug, not a resolver bug.

**Multiple effects of the same type**:
- Only the first matching effect per token is used. A card with two DAMAGE effects uses `effects[0].value` for `{damage}`.

**APPLY_STATUS `{status}` token**:
- `effect.status_effect_id` is a `StringName` — render as `str(effect.status_effect_id)`. The raw id (e.g., `"blinded"`) appears in the description. For MVP this is acceptable. Post-MVP, a status display name lookup can be added.

**Card with no effects, no tokens**:
- Empty dict, `description.format({})` returns the description unchanged. No crash.

**`{duration}` in frames**:
- `status_duration_frames = 120` → `"120"`. Frame count is the raw value. Post-MVP, the UI layer may convert to seconds (`120 / 60 = 2s`) — that conversion belongs in the UI layer, not the resolver.

---

## Implementation Notes

**File location**: `src/foundation/data/card_description_resolver.gd`

**Static method**: `resolve()` is a static method — no instantiation required. Card Hand UI calls `CardDescriptionResolver.resolve(card)` directly.

**No caching for MVP**: Descriptions are resolved on every display call. With 4–6 cards in hand, this is ~6 `String.format()` calls per frame at most (only on UI update, not every frame). No performance concern at this scale.

**`str(int(value))`**: Use `str(int(effect.value))` not `str(effect.value)` to ensure floats render as integers. `str(15.0)` produces `"15.0"` in GDScript; `str(int(15.0))` produces `"15"`.

**Localization note**: `CardDescriptionResolver.resolve()` returns a substituted String. If the project later adds localization via `tr()`, the description string should be translated before substitution: `tr(card.description).format(dict)`. The resolver should be designed so this change is a one-line addition.

**First-match semantics**: Only the first effect of each matching type contributes a token. This is intentional for MVP — multi-hit cards like `fan_the_hammer` show one damage value in the description even though two effects exist. The description string should say "Deal {damage} damage twice" — the word "twice" is authored in the description, not derived from effect count.

---

## Out of Scope

- Story 001: CardData resource class with `description` field (prerequisite)
- Story 003: Starter card .tres files with description strings authored using tokens (prerequisite)
- Display name lookup for `status_effect_id` tokens (post-MVP)
- Frame-to-seconds conversion for `{duration}` (post-MVP, UI layer concern)
- Runtime description changes based on player state (e.g., "Deal {damage} damage (×2 on BURNING enemies)") — this is a Card Hand UI concern, not the resolver

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: Automated unit test — must pass (`tests/unit/card_description_resolver/`)
**Gate level**: BLOCKING
**Status**: [ ] Not yet created

### QA Test Cases

| ID | Scenario | Input | Expected Result | Pass/Fail |
|----|----------|-------|-----------------|-----------|
| T-004-01 | DAMAGE token resolves to integer | `description="Deal {damage} damage"`, DAMAGE effect `value=15.0` | `"Deal 15 damage"` | [ ] |
| T-004-02 | AOE_DAMAGE token resolves correctly | `description="Deal {damage} in area"`, AOE_DAMAGE effect `value=14.0` | `"Deal 14 in area"` | [ ] |
| T-004-03 | MOVE_SELF distance token resolves | `description="Dash {distance} pixels"`, MOVE_SELF effect `value=80.0` | `"Dash 80 pixels"` | [ ] |
| T-004-04 | SHIELD token resolves | `description="Gain {shield} shield"`, SHIELD effect `value=20.0` | `"Gain 20 shield"` | [ ] |
| T-004-05 | DRAW_CARDS token resolves | `description="Draw {draw} card"`, DRAW_CARDS effect `value=1.0` | `"Draw 1 card"` | [ ] |
| T-004-06 | Unknown token left unreplaced | `description="Deal {damage} and {unknown}"`, DAMAGE effect `value=10.0` | `"Deal 10 and {unknown}"` (no crash) | [ ] |
| T-004-07 | Float value rendered as integer | `description="{damage}"`, DAMAGE effect `value=15.0` | `"15"` not `"15.0"` | [ ] |
| T-004-08 | Zero effects, no tokens | `description="Vanish from sight"`, `effects=[]` | `"Vanish from sight"` (unchanged) | [ ] |
| T-004-09 | Zero effects, token present | `description="Deal {damage} damage"`, `effects=[]` | `"Deal {damage} damage"` (unreplaced, no crash) | [ ] |
| T-004-10 | Multiple effects — first DAMAGE wins | `description="{damage}"`, effects=[DAMAGE value=9.0, DAMAGE value=9.0] | `"9"` (first effect, not summed) | [ ] |
| T-004-11 | APPLY_STATUS tokens resolve | `description="Apply {status} for {duration} frames"`, APPLY_STATUS `status_effect_id=&"blinded"`, `status_duration_frames=120` | `"Apply blinded for 120 frames"` | [ ] |
| T-004-12 | Multi-token description resolves all | `description="Deal {damage} damage, dash {distance} pixels"`, effects=[DAMAGE val=12.0, MOVE_SELF val=64.0] | `"Deal 12 damage, dash 64 pixels"` | [ ] |
| T-004-13 | GDD AC #13 canonical case | `description="Deal {damage} damage"`, DAMAGE `value=15.0` | `"Deal 15 damage"` | [ ] |

---

## Dependencies

- **Depends on**: Story 001 (CardData with `description: String` and CardEffect with `effect_type`, `value`, `status_effect_id`, `status_duration_frames` fields)
- **Depends on**: Story 003 (starter cards provide real .tres files for integration smoke check — not required for unit tests, which use fixture data)
- **Unlocks**: Card Hand UI (displays resolved descriptions in hand and tooltip), Deck Building UI (card preview descriptions in draft screen)
