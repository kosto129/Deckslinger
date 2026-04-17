# Smoke Test: Critical Paths

**Purpose**: Run these 10-15 checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (which reads this file)
**Update**: Add new entries when new core systems are implemented.

## Core Stability (always run)

1. Game launches to main menu without crash
2. New run can be started from the main menu
3. Main menu responds to both KB/M and gamepad input

## Core Mechanic (update per sprint)

4. Player entity spawns in room and can move in 8 directions
5. Card hand displays 4 cards with correct archetype colors
6. Playing a card commits the player (windup → active → recovery)
7. Hitting an enemy deals damage with hit-stop and screen shake
8. Use-to-draw: playing a card draws a replacement from draw pile

## Room Flow

9. Clearing all enemies in a room triggers room clear sequence
10. Room transition (fade out → load → fade in) completes without error
11. Player HP persists between rooms

## Data Integrity

12. CardRegistry loads all .tres files from assets/data/cards/ without error
13. Run seed produces identical floor layouts on repeated runs

## Performance

14. No visible frame drops below 60fps during combat with 4+ enemies
15. No memory growth over 5 minutes of continuous play
