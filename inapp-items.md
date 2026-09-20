# In-App Purchase Items (draft)

One-time consumable purchases. The main game stays fully free; these are optional boosts.

Each item needs a Google Play product ID (format: `pacyrinth_power_001`):
product IDs must be lowercase, start with a letter, and use only A-Z / 0-9 / _ / .

Prices below are placeholder values the user must confirm before they are submitted
to the Google Play Console.

| # | Product ID (planned) | Name            | Type       | Description                                                        | Price (placeholder) |
|---|----------------------|-----------------|------------|--------------------------------------------------------------------|---------------------|
| 1 | pacyrinth_power_001  | INVISIBILITY    | consumable | Become invisible to ghosts for 8 seconds                           | 0.50 USD            |
| 2 | pacyrinth_power_002  | MAGNET          | consumable | Dots fly to you from far away for 10 seconds                       | 0.75 USD            |
| 3 | pacyrinth_power_003  | SHIELD          | consumable | Survive one ghost hit; shield breaks instead                       | 0.80 USD            |
| 4 | pacyrinth_power_004  | SLOW GHOSTS     | consumable | Ghosts move at half speed for 10 seconds                           | 0.90 USD            |
| 5 | pacyrinth_power_005  | ROCKET          | consumable | Board tilts up to 34 degrees for 8 seconds                         | 1.00 USD            |
| 6 | pacyrinth_power_006  | DOT FEVER       | consumable | Dot requirements for the stage are halved for 12 seconds           | 1.10 USD            |
| 7 | pacyrinth_power_007  | GHOST FREEZE    | consumable | Freeze all ghosts in place for 6 seconds                           | 1.20 USD            |
| 8 | pacyrinth_power_008  | GHOST REPEL     | consumable | Push ghosts back when they get close for 8 seconds                 | 1.40 USD            |
| 9 | pacyrinth_power_009  | GIANT           | consumable | Ball doubles in radius for 10 seconds (smashes through more)       | 1.50 USD            |
|10 | pacyrinth_power_010  | EXTRA LIFE      | consumable | Gain one extra life for the current run                            | 2.00 USD            |

Notes
- Purchase flow: buy in STORE, the active boost (one at a time) is applied during play.
- No subscriptions planned. All items are one-time consumables (respawning ability available in STORE).
- IAP requires a Google Play billing license + a Godot Play Billing plugin (roadmap).