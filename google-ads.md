Integrating the System

I've moved on to integrating Google Play Services and IAPs, focusing on installing the necessary Godot plugins. I'm setting up the Google Play Console, which involves creating a developer account and configuring the app. Specifically, I'm integrating Google Play Games Services for progress saving and achievements, and setting up Google Play Billing for in-app purchases, including the "Remove Ads" option.

To address your requests regarding "Pacyrinth Game":

1. Steps to Integrate and View Ads
To display ads in your Godot game, you need to use an ad mediation platform like AdMob.
1. AdMob Setup: Create an account on the AdMob website (https://admob.google.com/).
2. Create Ad Units: In AdMob, create an app and set up "Banner" and "Interstitial" ad unit IDs for Android.
3. Godot Plugin: Install a reputable AdMob plugin for Godot (ensure it matches your Godot version, e.g., Godot 4.x).
4. Configure Plugin: In your Godot project export settings, enter your AdMob App ID and the ad unit IDs you created.
5. Implementation: In your game code, use the plugin's API to:
    - Load ads on game startup.
    - Show Interstitial ads at specific milestones (e.g., level transition or Game Over).
    - Handle ad-related signals (e.g., closing an ad, failing to load).

2. Linking Google Play Services (IAP & Save Progress)
This requires Google Play Console configuration and Godot plugins.
1. Google Play Console: Set up a developer account, create the app, and configure both Google Play Billing and Google Play Games Services.
2. Integrate Plugins:
    - Billing: Install the Godot Google Play Billing plugin to handle purchases (including the "Remove Ads" non-consumable item).
    - Services: Install a Google Play Games Services plugin to handle user authentication, cloud saves, and achievements.
3. Implementation:
    - Use the Billing API to query products, process purchases, and acknowledge them.
    - To remove ads, check the purchase status of the pacyrinth_no_ads item on startup. If purchased, set a global variable to hide ad triggers.
    - To save progress, use the Games Services API to map your local save file to Google's cloud storage.
3. In-App Purchase List
I have updated inapp-items.md to include the "Remove Ads" item.



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
