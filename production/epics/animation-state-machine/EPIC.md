# Epic: Animation State Machine

> **Layer**: Core
> **GDD**: design/gdd/animation-state-machine.md
> **Architecture Module**: gameplay/animation_state_machine.gd (on AnimationComponent)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories animation-state-machine`

## Overview

Implement the AnimationComponent's custom state machine that enforces the
3-phase commitment sequence (windup → active → recovery), drives
AnimatedSprite2D playback with 8-directional sprites, manages hit-stop frame
freezes, and emits phase boundary signals that Combat and Collision systems
depend on. This is the enforcement layer for Pillar 1: Every Card Is a Commitment.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0007: Animation Commitment & Hit-Stop | Custom frame-counting state machine, hit-stop freezes all timers | LOW |
| ADR-0001: Entity Composition | AnimationComponent as child node of EntityBase | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-AS-001 | 3-phase action sequence with frame counting | ADR-0007 ✅ |
| TR-AS-002 | Commitment enforcement — no cancel | ADR-0007 ✅ |
| TR-AS-003 | Hit-stop frame freeze on attacker + target | ADR-0007 ✅ |
| TR-AS-004 | 8-dir sprite animation with direction lock | ADR-0007 ✅ |
| TR-AS-005 | AnimatedSprite2D with SpriteFrames at 12 art fps | ADR-0007 ✅ |

## Definition of Done

This epic is complete when:
- AnimationComponent implements 9 animation states with valid transitions
- play_action() locks entity for exact frame counts (windup + active + recovery)
- Phase signals fire at correct frame boundaries
- apply_hitstop() freezes all timers (longer-wins policy)
- Direction locks at WINDUP start, unlocks at action_completed
- Stun during WINDUP cancels action correctly
- Unit tests pass for phase timing, hit-stop, and state transitions

## Next Step

Run `/create-stories animation-state-machine` to break this epic into implementable stories.
