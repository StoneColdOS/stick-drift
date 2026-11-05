# Stick Drift

*Night drifting with a real stick.*

A semi top-down, pixelated low-poly drift game. Night-time suburb, white LED street lights, an old-school two-tone coupe, an on-screen steering wheel and a real H-pattern stick shift. The gas is always on, so shifting *is* the game: forget to shift and you'll blow the engine, downshift too hard and you'll blow it faster.

Built in Godot 4.7.

![Drifting](docs/screenshots/drift.png)

## Play it

**On your iPhone (or any phone):** open [stonecoldos.github.io/stick-drift](https://stonecoldos.github.io/stick-drift/) in Safari and turn the phone sideways. Every push to `main` rebuilds it (give it a couple of minutes, then refresh).

**Full screen on iPhone:** Safari won't let a web page hide its address bar, so add it to your home screen once: in Safari tap **Share > Add to Home Screen**, then launch it from the icon. It opens full screen with no address bar.

**On the Thor:** every push also builds an APK. Open the [latest build](https://github.com/StoneColdOS/stick-drift/releases/tag/latest-build), download `stick-drift.apk` and install it over the old one.

**On your Mac:** install [Godot 4.7](https://godotengine.org/download), click **Import**, pick `project.godot` in this folder, then press **F5**. You can drag the on-screen controls with the mouse.

## Controls

```
1   3   5
|   |   |
+---N---+
|   |   |
2   4   R
```

| | Touch | Keyboard | Gamepad (Thor) |
|---|---|---|---|
| Steer | Twist the wheel (bottom-left). Let go and it spins back to center | A / D or arrows | Left stick |
| Shift | Drag the knob through the H gate (bottom-right) | 1-5, N or 0, R | R1 up / L1 down |
| E-brake | Pull the lever down (far right) | Space | B or L2 |
| Camera | ISO / 3D button (top-right): flat isometric or perspective, both behind the car | V | Select |
| Zoom | Automatic: close when slow, pulls out with speed and drifting. Pinch or − / + sets how close it sits when slow | - / = or mouse wheel | Y / X |
| Reset | RESET (top-right) | Enter | Start |

- **The gas is always on** whenever you're in gear.
- **Slow down** by downshifting (engine braking) or knocking it into **neutral**.
- **Drift:** get going in 2nd, flick the wheel and tug the e-brake, then countersteer. 2nd is the drift gear; it has just enough power to keep the rear sliding.
- **Forgiving by default:** the auto gas keeps the rear tires hooked up while you're just driving, and steering tightens up with speed, so the car only slides when you start a drift with the e-brake. Once you're sliding you get full power to hold it, a little countersteer assist, and past about 35° the car resists spinning out.
- **Engine damage:** sitting on the limiter (~7900+ rpm) wears it down over about 25 seconds, and a money shift (way past 9800 rpm) kills it fast. Watch for **SHIFT!**
- **Vibration:** gear changes buzz on the Thor and Android. On iPhone (iOS 18+) you get a haptic tick when your thumb lifts off the shifter; Safari doesn't allow anything better.

## How it's built

Everything is built in code from `scripts/main.gd`, no scene editing needed.

| File | What it does |
|---|---|
| `scripts/car.gd` | Arcade drift physics: front and rear axle grip, friction circle, e-brake |
| `scripts/motor.gd` | Torque curve, redline, engine braking, blowing up |
| `scripts/gearbox.gd` | 5-speed ratios |
| `scripts/shifter_gate.gd` | H-pattern gate logic (knob always travels through neutral) |
| `scripts/touch_controls.gd` | Wheel, shifter, e-brake lever, buttons |
| `scripts/hud.gd` | Gear, tach, speed, engine health, drift points |
| `scripts/neighborhood.gd` | The night suburb and street lights |
| `scripts/car_model.gd` | Placeholder car, headlight/tail light glow, exhaust and backfires, skid marks, smoke |
| `scripts/chase_camera.gd` | Isometric or perspective chase camera, with zoom (both remembered) |
| `scripts/haptics.gd` | Vibration on gear changes |
| `tests/test_drive.gd` | Automated test: launches, shifts, drifts, blows the engine |

Run the test: `godot --headless --fixed-fps 120 --path . -s res://tests/test_drive.gd`. The web build only publishes if it passes.

## Tuning cheat sheet

In `scripts/car.gd`:

- More slide: lower `rear_grip`, raise `torque_multiplier`
- Easier to catch a drift: raise `countersteer_assist`, `spin_guard` or `min_rear_lateral_share`
- Harder / more raw: set `traction_control`, `countersteer_assist` and `spin_guard` to 0
- Steering sharpness at speed: `steer_grip_limit` (higher = sharper, easier to overdo)
- E-brake: `handbrake_grip_scale` (lower = looser rear), `handbrake_brake` (higher = scrubs more speed)

In `scripts/motor.gd`: `damage_rpm`, `sustained_damage`, `money_shift_rpm`.
Pixel size: `PIXEL_SHRINK` in `scripts/main.gd` (higher = chunkier).

## Next up

- Engine and tire audio (rpm-pitched loop + screech)
- A proper low-poly coupe to replace the box car
