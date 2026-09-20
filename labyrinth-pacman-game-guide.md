# Building a Tilt-Maze Pac-Man Game — Complete Beginner's Guide

## 0. What you're actually building (read this first)

You're combining two genres with different movement logic, and reconciling that is the single most important design decision you'll make:

- **Labyrinth-style movement**: a ball rolls freely and continuously across a board, controlled by tilting the device. This uses real physics (gravity, momentum, collisions with walls).
- **Pac-Man-style movement**: the player and ghosts move along a fixed grid, one corridor at a time, and AI ghosts pathfind toward the player through that grid.

These don't naturally mix, because physics-based rolling gives you smooth, momentum-driven motion (hard to grid-align), while Pac-Man's ghost AI depends on a clean grid to calculate paths.

**The practical solution** (used by most successful hybrids): keep the ball's *movement* physics-based and free-rolling (tilt = force applied to a Rigidbody), but build the *maze and dot layout* on an invisible grid underneath. Ghosts move physics-based too, but their AI reads the same grid to decide which direction to head at each junction. This gives you tilt-based fluid motion for the player while still letting ghosts "solve" the maze intelligently. This guide is built around that approach.

---

## 1. Tools you'll need

- **Unity** (free, Personal license) — download from unity.com. Install the **Android Build Support** and/or **iOS Build Support** modules during setup, since you'll need a real phone to test tilt controls (the editor can't simulate a tilted device properly).
- **C#** — Unity's scripting language. You don't need to be fluent; this guide gives you working starter scripts.
- **A physical Android or iOS phone** for testing (tilt/accelerometer doesn't work in the Unity Editor).
- Optional but useful: **Aseprite** or **Piskel** (free, pixel art) for sprites; **Audacity** for sound editing.

---

## 2. Project setup

1. Open Unity Hub → New Project → **2D (URP)** template. Name it something like `TiltMaze`.
2. Go to **File → Build Settings** → switch platform to **Android** or **iOS** (whichever phone you'll test on). Switching early avoids headaches later.
3. Go to **Edit → Project Settings → Player** and set orientation to whatever you want the board to be viewed in (Portrait is simplest for tilt maze games).

---

## 3. Design the maze layout

Before touching code, sketch your maze on graph paper or in a spreadsheet — a grid of cells where each cell is either **open floor**, **wall**, **dot**, **empty (no dot)**, or **goal hole**. This grid is your single source of truth; both the visual maze and the ghost AI will read from it.

In Unity:

1. Create a **Tilemap** (GameObject → 2D Object → Tilemap → Rectangular). This is how Pac-Man-style games efficiently build grid-based levels.
2. Design or download simple wall/floor tile sprites (16x16 or 32x32 px works well).
3. Paint your maze walls using the Tile Palette window.
4. Keep a **separate data structure** (a 2D array or a simple text/CSV file) marking which cells contain dots, which is the goal hole, and where ghosts start. You'll read this array in code to spawn dots and to run ghost pathfinding — don't hardcode positions by hand for more than a tiny test maze.

---

## 4. The ball (player) — tilt-based movement

1. Create a **Sprite** for your Pac-Man-style ball (a yellow circle with a mouth wedge cut out, or an animated 2–3 frame "chomp" sprite).
2. Add a **Rigidbody2D** (set Gravity Scale to 0, since you're not falling — you're rolling on a flat board) and a **Circle Collider 2D**.
3. Set walls' colliders to **static** with a physics material that has near-zero friction and no bounciness, so the ball glides smoothly instead of sticking.

**Reading the tilt input**: Unity exposes the accelerometer through `Input.acceleration`, a `Vector3` giving the phone's tilt on each axis.

```csharp
using UnityEngine;

public class TiltBallController : MonoBehaviour
{
    public float tiltForce = 8f;
    private Rigidbody2D rb;

    void Start()
    {
        rb = GetComponent<Rigidbody2D>();
    }

    void FixedUpdate()
    {
        Vector3 tilt = Input.acceleration;
        // acceleration.x/y range roughly -1 to 1 depending on phone orientation
        Vector2 force = new Vector2(tilt.x, tilt.y) * tiltForce;
        rb.AddForce(force);
    }
}
```

Test this on your phone early — accelerometer feel (sensitivity, dead zone, axis mapping for your chosen orientation) needs real-device tuning, and it will feel completely different in the editor.

Add a small linear drag (Rigidbody2D → Linear Drag, try 1–3) so the ball doesn't slide forever once you stop tilting.

---

## 5. Dots

1. Create a small yellow dot sprite and a **Prefab** out of it with a small trigger collider.
2. When loading the level, loop through your maze data array and **instantiate a dot prefab** at every cell marked "dot."
3. On the ball, add a trigger collision handler:

```csharp
void OnTriggerEnter2D(Collider2D other)
{
    if (other.CompareTag("Dot"))
    {
        Destroy(other.gameObject);
        ScoreManager.Instance.AddScore(10);
    }
}
```

4. Track remaining dot count; you can optionally require all dots collected before the goal hole "opens" (classic Pac-Man rule), or make dots purely score bonuses that don't block finishing — your call.

---

## 6. The goal hole

1. Place a trigger collider at your goal cell.
2. On overlap with the ball, trigger your win condition (stop input, play a "fall into hole" animation/scale-down effect, show a level-complete screen).

```csharp
void OnTriggerEnter2D(Collider2D other)
{
    if (other.CompareTag("Player"))
    {
        GameManager.Instance.LevelComplete();
    }
}
```

---

## 7. Ghosts — movement and AI

This is the trickiest part. Here's a beginner-friendly approach:

1. Ghosts are also Rigidbody2D-driven sprites, but instead of tilt input, their velocity is set by an AI script every frame.
2. **Pathfinding**: since your maze lives in a grid array, run a **Breadth-First Search (BFS)** from the ghost's current cell to the ball's current cell. BFS is simpler than A* and plenty fast for typical maze sizes — a great starting point before you optimize.
3. Convert the ball's and ghost's world positions to grid coordinates each frame (`Mathf.RoundToInt` on position divided by cell size).
4. BFS gives you the next cell to move toward; set the ghost's velocity toward that cell's world position.

```csharp
public class GhostAI : MonoBehaviour
{
    public Transform player;
    public float speed = 3f;
    private Rigidbody2D rb;
    private MazeGrid maze; // your grid data wrapper

    void Start()
    {
        rb = GetComponent<Rigidbody2D>();
    }

    void FixedUpdate()
    {
        Vector2Int ghostCell = maze.WorldToCell(transform.position);
        Vector2Int playerCell = maze.WorldToCell(player.position);

        Vector2Int nextCell = maze.BFSNextStep(ghostCell, playerCell);
        Vector2 targetWorldPos = maze.CellToWorld(nextCell);

        Vector2 direction = (targetWorldPos - (Vector2)transform.position).normalized;
        rb.velocity = direction * speed;
    }
}
```

5. **Ghost "personality" (optional, adds a lot of fun)**: classic Pac-Man ghosts don't all chase directly — some intercept, some patrol, some scatter to corners periodically. A simple version: alternate every ~7 seconds between "chase" (BFS toward player) and "scatter" (BFS toward a fixed corner). This alone makes ghosts feel much less predictable and more fair.
6. **Catching the player**: add a trigger check on the ghost (or the ball) — on collision, call `GameManager.Instance.PlayerCaught()`, which reduces lives and either respawns the ball at a start point or ends the game.

---

## 8. Game state, lives, and scoring

Create a single persistent `GameManager` (a singleton that survives across scenes) to hold:
- Current score
- Lives remaining
- Reference to whether the level is complete/failed

```csharp
public class GameManager : MonoBehaviour
{
    public static GameManager Instance;
    public int lives = 3;
    public int score = 0;

    void Awake()
    {
        if (Instance == null) { Instance = this; DontDestroyOnLoad(gameObject); }
        else Destroy(gameObject);
    }

    public void PlayerCaught()
    {
        lives--;
        if (lives <= 0) GameOver();
        else RespawnPlayer();
    }

    public void LevelComplete() { /* load next level / show win UI */ }
    public void GameOver() { /* show game over UI */ }
    void RespawnPlayer() { /* move ball back to start cell, reset velocity */ }
}
```

---

## 9. UI

Use Unity's **UI Canvas** for score, lives, and start/win/lose screens. Keep it simple at first: a score text in the corner, a lives counter (small ball icons work well), and a full-screen panel that appears on win/lose with a "Retry" button.

---

## 10. Polish pass (do this after the core loop works)

- **Sprite animation**: give the ball 2–3 frames for a chomping mouth, animated based on movement speed.
- **Sound**: a dot-collect blip, a ghost-catch sound, background music reminiscent of (but not copied from) classic arcade chiptunes.
- **Ghost "eyes"**: classic Pac-Man ghosts have eyes that look in their movement direction — small visual touch, big feel improvement.
- **Camera**: if your maze is larger than one screen, add a camera that follows the ball smoothly (`Vector3.Lerp` toward the ball's position each frame) instead of showing the whole board at once.
- **Haptics**: light phone vibration on dot pickup or ghost catch (Unity's `Handheld.Vibrate()`) adds tactile feedback that tilt-controlled games benefit from a lot.

---

## 11. Testing on a real device

1. Connect your phone via USB, enable Developer Mode / USB debugging (Android) or trust the device (iOS with a paid Apple Developer account for iOS builds).
2. **File → Build and Run**. This installs a real APK/IPA to your phone.
3. Test tilt sensitivity on the actual device and adjust `tiltForce` and drag values until movement feels controllable, not twitchy or sluggish. This will take several iterations — budget real time for it.

---

## 12. Suggested build order (milestones)

Build in this order so you always have something playable:

1. Static maze + tilt-controlled ball reaching a goal hole (no dots, no ghosts).
2. Add dots + score.
3. Add one ghost with simple BFS chase.
4. Add lives/respawn/game over.
5. Add multiple ghosts + scatter/chase behavior switching.
6. Polish: animation, sound, UI screens, haptics.
7. Build additional maze levels by swapping out the grid data.

---

## 13. A note on naming and assets

Since this is directly inspired by Pac-Man, avoid using Namco/Bandai's actual character names, logos, ghost names (Blinky, Pinky, Inky, Clyde), or copied artwork if you intend to publish this — even a strong resemblance in branding or marketing copy can create trademark issues. Design your own distinct visual identity (different ghost colors/names, your own maze art) while keeping the *gameplay mechanics* — which aren't protectable in the same way art and branding are.

---

## 14. Learning resources

- Unity's official **2D Roguelike** and **Pac-Man style** tutorials (search "Unity Learn 2D") for grid-based movement patterns.
- Search "Unity accelerometer tilt movement tutorial" for device-specific tuning tips.
- Search "BFS pathfinding Unity C# tutorial" if you want a deeper walkthrough of the pathfinding script above before you type it in.

---

### Quick recap of the architecture

```
Maze data (grid array) ──┬── generates Tilemap visuals
                          ├── used by dot spawner
                          └── used by ghost BFS pathfinding

Ball: Rigidbody2D + tilt input (Input.acceleration) → free rolling
Ghosts: Rigidbody2D + BFS toward ball's grid cell → grid-aware chasing
GameManager: singleton tracking score/lives/win-lose state
```

Start with milestone 1 above — a rollable ball reaching a hole in a static maze — and get that feeling good on your actual phone before adding anything else. Everything else layers on top of that foundation.
