# In-App Purchase Items (draft)

One-time consumable purchases. The main game stays fully free; these are optional boosts.

| # | Product ID (planned) | Name            | Type       | Description                                                        | Price (placeholder) |
|---|----------------------|-----------------|------------|--------------------------------------------------------------------|---------------------|
| 0 | pacyrinth_no_ads     | REMOVE ADS      | non-consumable | Permanently remove banner and interstitial ads from the game        | 1.99 USD            |
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

# AdMob Configuration

Paste your AdMob unit IDs here once created in the AdMob console.

| Ad Type | AdMob Unit ID (Paste here) |
|---------|----------------------------|
| App ID  |              ca-app-pub-7154983327212352~1298158776              |
| Banner  |              ca-app-pub-7154983327212352/2144336583              |
| Interstitial |         ca-app-pub-7154983327212352/6319296020              |

Notes
- Purchase flow: buy in STORE, the active boost (one at a time) is applied during play.
- No subscriptions planned. All items are one-time consumables (respawning ability available in STORE).
- IAP requires a Google Play billing license + a Godot Play Billing plugin (roadmap).



* Old ID: ca-app-pub-3940256099942544~3347511713