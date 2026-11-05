extends SceneTree
## Drives the car automatically and checks the core loop works.
## Run: godot --headless --fixed-fps 120 --path . -s res://tests/test_drive.gd

const Gate := preload("res://scripts/shifter_gate.gd")

var failures := 0
var main: Node
var car


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# --- Shifter gate logic
	_check(Gate.gear_at(Gate.slot_for(3)) == 3, "Slot 3 reads as 3rd")
	_check(Gate.gear_at(Vector2(0, 0.5)) == 0, "Halfway into a slot is still neutral")
	_check(Gate.gear_at(Vector2(1, -1)) == -1, "Bottom right is reverse")
	var p := Gate.slot_for(2)
	var passed_neutral := false
	for i in 200:
		p = Gate.move_along(p, Gate.slot_for(3), 0.05)
		if Gate.gear_at(p) == 0:
			passed_neutral = true
		_check(absf(p.y) < 1e-3 or absf(p.x - roundf(p.x)) < 1e-3, "Knob never leaves the gate", true)
	_check(passed_neutral and Gate.gear_at(p) == 3, "2nd to 3rd goes through neutral and lands in 3rd")
	_check(Gate.project(Vector2(-0.6, 0.9)) == Vector2(-1, 0.9), "Dragging near the 1st column snaps to it")

	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	car = main.car
	car.collision_mask = 0  # drive through walls for the long straight-line tests

	_check(car.gear == 0 and car.speed < 0.1, "Starts parked in neutral")
	await _secs(1.0)
	_check(car.speed < 0.1, "Neutral doesn't move")

	# --- Launch in 1st
	main.touch.snap_to_gear(1)
	await _secs(2.0)
	_check(car.gear == 1, "In 1st")
	_check(car.speed > 6.0, "Auto throttle pulls in 1st (%.1f m/s)" % car.speed)

	# --- Stay in 1st: should blow up
	var t := 0.0
	while not car.motor.is_blown() and t < 30.0:
		await _secs(0.5)
		t += 0.5
	_check(car.motor.is_blown(), "Sitting on the limiter in 1st blows the engine (%.1fs)" % t)
	await _secs(1.0)
	_check(car.motor.rpm < 2000.0, "Dead engine winds down")

	# --- Fresh start, shift properly through the gears
	main.touch.snap_to_gear(0)
	car.reset_to_spawn()
	await _secs(0.5)
	_check(car.speed < 0.5 and not car.motor.is_blown(), "Reset puts the car back with a fresh engine")
	main.touch.snap_to_gear(1)
	t = 0.0
	while t < 14.0:
		await _secs(0.1)
		t += 0.1
		if car.motor.rpm > 7200.0 and car.gear < 4:
			main.touch.snap_to_gear(car.gear + 1)
	_check(car.gear == 4, "Shifted up to 4th")
	_check(car.motor.health > 0.95, "Good shifting keeps the engine healthy (%.2f)" % car.motor.health)
	_check(car.speed > 35.0, "Gets up to speed (%.0f mph)" % (car.speed * 2.237))

	# --- Normal steering at speed doesn't throw the car sideways
	var planted := 0.0
	main.touch.snap_to_gear(4)
	Input.action_press("steer_right", 0.7)
	for i in 240:
		await physics_frame
		planted = maxf(planted, absf(car.slip_angle))
	Input.action_release("steer_right")
	_check(planted < 10.0, "Hard steering at speed stays planted without the e-brake (max %.0f°)" % planted)
	main.touch.snap_to_gear(4)
	await _secs(1.0)

	# --- Downshift to slow down (one gear) then money shift (way down)
	var before: float = car.speed
	main.touch.snap_to_gear(3)
	await _secs(1.0)
	_check(car.speed < before, "Downshift 4 -> 3 at speed slows the car")
	_check(not car.motor.is_blown(), "One gear down doesn't kill it")
	main.touch.snap_to_gear(1)
	await _secs(0.5)
	_check(car.motor.is_blown(), "Money shift into 1st at speed blows it")

	# --- Drift: 2nd gear, steer + e-brake
	car.repair_engine()
	main.touch.snap_to_gear(0)
	car.reset_to_spawn()
	await _secs(0.5)
	main.touch.snap_to_gear(2)
	await _secs(2.5)
	var max_slip := 0.0
	var drifted := false
	var drift_time := 0.0
	Input.action_press("steer_right")
	Input.action_press("ebrake")
	for i in 80:
		await physics_frame
	Input.action_release("ebrake")
	for i in 360:  # simple countersteer: steer against the slide
		await physics_frame
		var want := clampf(-car.slip_angle / 70.0, -1.0, 1.0) if i > 15 else 1.0
		Input.action_release("steer_left")
		Input.action_release("steer_right")
		if want > 0.0:
			Input.action_press("steer_right", want)
		else:
			Input.action_press("steer_left", -want)
		max_slip = maxf(max_slip, absf(car.slip_angle))
		if car.drifting:
			drift_time += 1.0 / 120.0
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	drifted = drift_time > 1.5
	# Let go of the wheel mid-slide: the assist and spin guard should save it.
	main.touch.snap_to_gear(0)
	car.reset_to_spawn()
	await _secs(0.5)
	main.touch.snap_to_gear(2)
	await _secs(2.5)
	Input.action_press("steer_right")
	Input.action_press("ebrake")
	await _secs(0.6)
	Input.action_release("ebrake")
	Input.action_release("steer_right")
	var worst := 0.0
	for i in 360:
		await physics_frame
		worst = maxf(worst, absf(car.slip_angle))
	_check(worst < 80.0, "Letting go of the wheel mid-drift doesn't spin you out (max %.0f°)" % worst)
	_check(drifted, "E-brake + countersteer holds a drift (%.1fs, max %.0f°)" % [drift_time, max_slip])
	await _secs(0.5)
	_check(main.hud.drift_points > 0.0 or main.hud.best > 0.0, "Drifting scores points")

	# --- Neutral stops the car
	main.touch.snap_to_gear(0)
	await _secs(6.0)
	_check(car.speed < 1.0, "Neutral coasts to a stop (%.1f m/s)" % car.speed)

	# --- Walls work
	car.collision_mask = 1
	car.reset_to_spawn()
	await _secs(0.3)
	main.touch.snap_to_gear(2)
	await _secs(8.0)
	var town = main.town
	_check(absf(car.global_position.x) < town.half and absf(car.global_position.z) < town.half, "Can't drive off the map")

	print("\n%s: %d failure(s)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String, quiet := false) -> void:
	if not ok:
		failures += 1
		print("  FAIL  ", what)
	elif not quiet:
		print("  ok    ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _secs(s: float) -> void:
	for i in int(s * 120):
		await physics_frame
