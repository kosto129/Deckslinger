# Epic: Combat System

> **Layer**: Core
> **GDD**: design/gdd/combat-system.md
> **Architecture Module**: gameplay/combat_system.gd
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories combat-system`

## Overview

Implement the CombatSystem that processes all damage through a multiplicative
pipeline, manages HealthComponent interactions, orchestrates hit-stop across
Animation + Camera + Input, spawns damage number VFX, handles death processing
with kill credit, and provides the execute_card() entry point that Card Hand
System calls to resolve card effects. This is the central damage authority.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0009: Damage Pipeline & Health Authority | Multiplicative modifiers, HealthComponent sole HP authority, death hit-stop bonus | LOW |
| ADR-0007: Animation Commitment | active_started triggers damage, hit-stop coordination | LOW |
| ADR-0008: Collision Layers | HitData delivery from collision detection | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-CO-001 | Multiplicative damage pipeline | ADR-0009 ✅ |
| TR-CO-002 | HealthComponent as sole HP authority | ADR-0009 ✅ |
| TR-CO-003 | Death sequence + Entity lifecycle | ADR-0009 ✅ |
| TR-CO-004 | Hit-stop orchestration across systems | ADR-0007, ADR-0009 ✅ |
| TR-CO-005 | Floating damage number VFX | ADR-0009 ✅ |
| TR-CO-006 | DoT through same pipeline (no hit-stop) | ADR-0009 ✅ |

## Definition of Done

This epic is complete when:
- CombatSystem processes HitData through full modifier pipeline
- HealthComponent take_damage/heal/died interface works correctly
- execute_card() resolves CardData effects (DAMAGE, HEAL, APPLY_STATUS, etc.)
- Hit-stop freezes attacker + target + camera + input simultaneously
- Killing blow triggers extended hit-stop + entity.die()
- Damage numbers spawn at hit position with color coding
- DoT ticks process through pipeline without hit-stop/shake
- Unit tests pass for damage formula, modifier stacking, death processing

## Next Step

Run `/create-stories combat-system` to break this epic into implementable stories.
