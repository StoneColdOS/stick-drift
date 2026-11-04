# Stick Drift

A semi top-down, pixelated low-poly drift game for iPhone. Night-time suburb, white LED street lights, an old-school two-tone coupe, an on-screen steering wheel and a real H-pattern stick shift. The throttle is always on, so shifting *is* the gameplay: forget to shift and you'll blow the engine, downshift too hard and you'll blow it faster.

## Getting it running (Unity 6)

1. Install **Unity Hub** and a **Unity 6** editor (6000.x) with **iOS Build Support**.
2. In Unity Hub: **Add > Add project from disk** and pick this repo folder. Unity generates the rest of the project the first time it opens (takes a few minutes).
3. In the menu bar: **Stick Drift > Build Neighborhood Scene**.
4. Press **Play**. In the Game view, pick a landscape iPhone resolution (e.g. 2556x1179) so the layout looks right.
5. Commit the `.meta` files and `ProjectSettings/` folder Unity created, so the repo stays in sync.

> Uses the **Built-in Render Pipeline** and the **old Input Manager**. If you created the project from a URP template or switched to the new Input System only, set *Project Settings > Player > Active Input Handling* to "Input Manager (Old)" or "Both".

### Testing on your iPhone
**File > Build Profiles > iOS > Switch Platform**, then **Build**. Open the generated Xcode project, set your signing team, plug in the phone, and run.

## Controls

| Touch | Keyboard (for testing on the Mac) |
|---|---|
| Steering wheel (bottom-left): twist it with your thumb, let go and it self-centers | A / D or arrow keys |
| Shifter (bottom-right): drag the knob through the H-pattern gate | 1-5, N or 0 for neutral, R for reverse |
| E-brake lever (far right): pull down | Space |

```
1   3   5
|   |   |
+---N---+
|   |   |
2   4   R
```

- **Gas is automatic** whenever you're in gear.
- **Slow down** by downshifting (engine braking) or knocking it into **neutral**.
- **Start a drift** with the e-brake, or just power-oversteer in 1st/2nd.
- **Engine damage:** sitting above ~7900 rpm slowly wears the engine; a money shift (way over 9400 rpm) kills it almost instantly. Watch for **SHIFT!** on the HUD.

## Project layout

```
Assets/
  Editor/StickDriftSetup.cs        one-click scene + iPhone player settings
  Scripts/
    Core/StickDriftBootstrap.cs    builds everything at startup
    Core/MatLib.cs                 runtime materials
    Car/DriftCar.cs                arcade drift physics (the fun part to tune)
    Car/Engine.cs                  torque curve, redline, blowing up
    Car/Gearbox.cs                 5-speed ratios
    Car/CarControls.cs             input hub + keyboard fallback
    Car/CarBuilder.cs, CarEffects.cs   placeholder car model, skids, smoke, lights
    World/NeighborhoodBuilder.cs   procedural night suburb
    World/LampCuller.cs            only nearby street lights are switched on
    UI/                            wheel, shifter, e-brake, HUD
    Rendering/PixelCamera.cs       low-res render for the pixel look
    Rendering/FollowCamera.cs      semi top-down chase cam
```

## Tuning cheat sheet

Select **Car** in the Hierarchy while playing and tweak `DriftCar`:

- More slide: lower `rearGrip`, raise `torqueMultiplier`.
- Easier to catch a drift: raise `minRearLateralShare`, raise `maxSteerAngle`.
- E-brake too strong/weak: `handbrakeGripScale`, `handbrakeBrake`.
- Engine too fragile: raise `damageRpm` or lower `sustainedDamage` under **Engine**.

Pixel size lives on the **Stick Drift** object (`pixelHeight`, lower = chunkier). Camera angle and zoom are on **Main Camera > FollowCamera** (`rotateWithCar` off gives a fixed north-up view).

## Next up

- Engine and tire audio (rpm-pitched loop + screech)
- A proper low-poly coupe model to replace the box car
- Drift scoring zones and a combo multiplier
- Haptics on gear changes and when the engine blows
