# Accessibility Requirements

> **Status**: Active
> **Tier**: Basic
> **Last Updated**: 2026-04-17
> **Applies To**: All player-facing systems

## Accessibility Tier: Basic

This project commits to the **Basic** accessibility tier. This is the minimum
viable level for a PC indie game — remapping, subtitles, and essential visual
accommodations. Higher tiers can be adopted post-launch based on player feedback.

## Tier Definition

| Tier | Scope | This Project |
|------|-------|-------------|
| **Basic** | Remapping + subtitles + essential visual | ✅ Committed |
| Standard | Basic + colorblind modes + scalable UI | Future consideration |
| Comprehensive | Standard + motor accessibility + full settings | Post-launch |
| Exemplary | Comprehensive + external audit | Not planned |

## Basic Tier Requirements

### Input Accessibility

- [x] **All keyboard bindings are remappable** from the settings menu
- [x] **Gamepad support** for all gameplay and menu navigation
- [ ] **No simultaneous button requirements** — no action requires pressing 2+ buttons at the same time
- [ ] **Pause is always available** — game can be paused at any time during gameplay (never blocked)

### Visual Accessibility

- [ ] **Damage numbers are color-coded** with distinct shapes or size (not color alone) for crit vs normal vs DoT
- [ ] **Enemy telegraphs use animation + color** — never rely on color alone to communicate attack timing
- [ ] **Card archetypes distinguishable by icon shape** in addition to color (Gunslinger/Drifter/Outlaw/Neutral have distinct frame shapes)
- [ ] **UI text minimum 8px at native resolution** (equivalent to ~40px at 1080p with 5× scaling)

### Audio Accessibility

- [ ] **No gameplay information conveyed by audio alone** — all audio cues have a visual equivalent (hit-stop, screen shake, damage numbers)
- [ ] **Volume sliders** for master, SFX, and music (when audio is implemented)

### Motor Accessibility

- [ ] **Input buffering** reduces timing precision requirements (8-frame buffer window per Input System GDD)
- [ ] **No rapid button mashing required** — single-press actions only
- [ ] **Adjustable difficulty** (future: enemy HP/damage scaling options)

## Implementation Checklist

| Requirement | System | Status | Sprint |
|------------|--------|--------|--------|
| Key remapping | Input System | Not Started | Sprint 1 |
| Gamepad navigation for menus | UI Systems | Not Started | When menus built |
| Pause always available | Input System | Not Started | Sprint 1 |
| Non-color-only damage numbers | Combat System | Not Started | When VFX built |
| Non-color-only telegraphs | Enemy AI | Not Started | When enemies built |
| Archetype shape distinction | Card Hand UI | Not Started | When UI built |
| Volume sliders | Audio Manager | Not Started | When audio built |

## Testing

- Test with keyboard only (no mouse)
- Test with gamepad only (no keyboard)
- Test with color filters (grayscale screenshot check for color-only information)
- Verify all text is readable at native resolution
