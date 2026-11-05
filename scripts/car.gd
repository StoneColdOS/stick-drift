extends RigidBody3D
## Arcade drift physics on a flat plane (bicycle model: one front axle, one rear axle).
## Each axle has a grip budget. The rear axle shares its budget between drive force and
## side grip (friction circle), so too much power or the e-brake makes the rear step out.

const Motor := preload("res://scripts/motor.gd")
const Gearbox := preload("res://scripts/gearbox.gd")
const G := 9.81
const RAD_TO_RPM := 60.0 / TAU

signal gear_changed(old_gear: int, new_gear: int)
signal engine_blown

var input  ## car_input.gd
var motor := Motor.new()

# --- Drivetrain
var wheel_radius := 0.3
var final_drive := 4.3
var torque_multiplier := 1.7      ## arcade boost; raise for more power oversteer

# --- Chassis (distances along the car's forward axis)
var front_axle := 1.25
var rear_axle := -1.2
var max_steer_angle := 42.0
var steer_speed := 260.0          ## degrees per second the front wheels can turn
var countersteer_assist := 0.3    ## 0 = off. Helps catch slides by adding some countersteer for you

# --- Tires
var front_grip := 1.2
var rear_grip := 0.9
var min_rear_lateral_share := 0.38## rear keeps this much side grip at full wheelspin, so drifts stay catchable
var handbrake_grip_scale := 0.3
var handbrake_brake := 0.3
var base_angular_damp := 0.7
var spin_guard := 0.8              ## past ~35° of slip the rear grips back up, up to this share. Lower = easier to spin

# --- Resistance
var rolling_resistance := 0.25    ## m/s^2
var aero_drag := 0.42
var coast_brake := 3.2            ## extra m/s^2 in neutral (or dead engine) so stopping isn't floaty

# --- Read-only state
var gear := 0
var steer_angle := 0.0
var speed := 0.0
var forward_speed := 0.0
var slip_angle := 0.0
var rear_slide := 0.0
var front_slide := 0.0
var wheelspin_rpm := 0.0
var drifting := false

var _spawn: Transform3D
var _reset_requested := false
var _was_blown := false


func _ready() -> void:
	mass = 1000.0
	gravity_scale = 0.0
	axis_lock_linear_y = true
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3.ZERO
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = base_angular_damp
	continuous_cd = true
	can_sleep = false
	var pm := PhysicsMaterial.new()
	pm.friction = 0.0  # scrape along walls instead of sticking
	pm.bounce = 0.05
	physics_material_override = pm

	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.66, 0.9, 4.2)
	shape.shape = b
	shape.position = Vector3(0, 0.65, 0)
	add_child(shape)

	_spawn = global_transform
	motor.repair()


func handbrake() -> float:
	return input.handbrake if input else 0.0


func forward() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized()


func _point_velocity(offset: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(offset)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _reset_requested:
		_reset_requested = false
		state.transform = _spawn
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO


func _physics_process(dt: float) -> void:
	# Gear comes straight from the shifter (clutchless).
	var requested: int = input.gear if input else 0
	if requested != gear:
		var old := gear
		gear = requested
		gear_changed.emit(old, gear)

	var steer_in: float = input.steer if input else 0.0
	if absf(slip_angle) > 10.0:
		steer_in = clampf(steer_in - countersteer_assist * clampf(slip_angle / 45.0, -1.0, 1.0), -1.0, 1.0)
	var target_steer: float = steer_in * max_steer_angle
	steer_angle = move_toward(steer_angle, target_steer, steer_speed * dt)

	var fwd := forward()
	var right := fwd.cross(Vector3.UP)
	var v := linear_velocity
	v.y = 0.0
	var vf := v.dot(fwd)
	forward_speed = vf
	speed = v.length()

	# ---- Engine
	var ratio := Gearbox.ratio(gear) * final_drive
	var engaged := gear != Gearbox.NEUTRAL and not motor.is_blown()
	var ground_rpm := absf(vf / wheel_radius * ratio) * RAD_TO_RPM
	motor.tick(ground_rpm + wheelspin_rpm, engaged, dt)
	if motor.is_blown() and not _was_blown:
		_was_blown = true
		engine_blown.emit()

	var axle_mass := mass * 0.5
	var front_max := front_grip * G * axle_mass
	var rear_max := rear_grip * G * axle_mass
	var hb := handbrake()
	rear_max *= lerpf(1.0, handbrake_grip_scale, hb)

	# Throttle is always on. The torque curve goes negative past the cutoff (engine braking).
	var drive := 0.0
	if engaged:
		if vf * signf(ratio) < -0.5:
			drive = -signf(vf) * rear_max * 0.9  # e.g. slammed into R while rolling forward
		else:
			drive = motor.torque_at(motor.rpm) * torque_multiplier * ratio / wheel_radius
		drive *= lerpf(1.0, 0.6, hb)

	# Stiffness that cancels sideways speed in about two physics steps.
	var stiffness := axle_mass / dt * 0.5

	# ---- Front axle
	var f_off := fwd * front_axle
	var f_fwd := fwd.rotated(Vector3.UP, -deg_to_rad(steer_angle))
	var f_right := f_fwd.cross(Vector3.UP)
	var f_lat := _point_velocity(f_off).dot(f_right)
	var f_want := -f_lat * stiffness
	var f_force := clampf(f_want, -front_max, front_max)
	front_slide = clampf(absf(f_lat) / 5.0, 0.0, 1.0) if absf(f_want) > front_max else 0.0
	apply_force(f_right * f_force, f_off)

	# ---- Rear axle: drive + e-brake + friction circle
	var r_off := fwd * rear_axle
	var rv := _point_velocity(r_off)
	var r_lat := rv.dot(right)
	var r_long := rv.dot(fwd)

	var long_f := clampf(drive, -rear_max, rear_max)
	var spin_excess := maxf(0.0, absf(drive) - rear_max) / maxf(rear_max, 1.0)
	if hb > 0.01:
		var brake := minf(absf(r_long) * axle_mass / dt * 0.5, handbrake_brake * rear_max * hb)
		long_f = clampf(long_f - signf(r_long) * brake, -rear_max, rear_max)

	var lat_avail := sqrt(maxf(0.0, rear_max * rear_max - long_f * long_f))
	var guard_t := clampf(inverse_lerp(35.0, 70.0, absf(slip_angle)), 0.0, 1.0)
	var guard := lerpf(min_rear_lateral_share, maxf(spin_guard, min_rear_lateral_share), guard_t)
	# Past ~35° the car also resists rotating further, so a big flick doesn't turn into a spin.
	angular_damp = lerpf(base_angular_damp, base_angular_damp + spin_guard * 5.0, guard_t)
	lat_avail = maxf(lat_avail, rear_max * guard)
	var r_want := -r_lat * stiffness
	var r_force := clampf(r_want, -lat_avail, lat_avail)
	var sliding := absf(r_want) > lat_avail
	rear_slide = maxf(clampf(absf(r_lat) / 5.0, 0.0, 1.0) if sliding else 0.0, clampf(spin_excess, 0.0, 1.0))
	apply_force(fwd * long_f + right * r_force, r_off)

	# Wheelspin pushes the tach up while sliding. That's how a long drift can cook the engine.
	var spin_target := (clampf(spin_excess, 0.0, 1.0) * 2200.0 + rear_slide * 900.0) if engaged else 0.0
	wheelspin_rpm = move_toward(wheelspin_rpm, spin_target, 6000.0 * dt)

	# ---- Rolling resistance, drag, neutral coast brake
	if speed > 0.01:
		var dir := v / speed
		var resist := rolling_resistance * mass + aero_drag * speed * speed
		if not engaged:
			resist += coast_brake * mass
		resist = minf(resist, speed * mass / dt)
		apply_central_force(-dir * resist)

	# ---- Drift state
	if speed > 3.0:
		slip_angle = rad_to_deg(fwd.signed_angle_to(v, Vector3.UP))
		drifting = vf > 0.0 and speed > 5.0 and absf(slip_angle) > 12.0
	else:
		slip_angle = 0.0
		drifting = false


func repair_engine() -> void:
	motor.repair()
	_was_blown = false
	wheelspin_rpm = 0.0


func reset_to_spawn() -> void:
	_reset_requested = true
	steer_angle = 0.0
	repair_engine()
