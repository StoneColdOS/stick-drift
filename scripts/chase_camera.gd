extends Camera3D
## Two camera styles, toggled with the ISO / 3D button (remembered between sessions):
##   ISO: flat isometric look (orthographic, no perspective), swung around behind the car.
##   3D:  high perspective chase cam (think Over the Hill).
## Both turn toward where the car is *going* (its velocity), so "up" on screen is always forward,
## and in a drift you see the car swing sideways while the road ahead stays in view.
## Zoom is dynamic: close when you're slow, pulling out as you speed up and a bit more while
## drifting, then easing back in. Pinch, the -/+ buttons, the mouse wheel or the gamepad's Y/X
## set how close it sits when you're slow.

const SAVE_PATH := "user://camera.cfg"
const ISO := {"pitch_close": 34.0, "pitch_far": 62.0, "size_close": 9.0, "size_far": 54.0, "distance": 55.0, "speed_pull": 0.85, "drift_pull": 0.25}
const FOLLOW := {"pitch_close": 44.0, "pitch_far": 68.0, "dist_close": 13.0, "dist_far": 42.0}

var car  ## car.gd
var iso := true
var zoom := 0.05                 ## base zoom when slow: 0 = close, 1 = far
var look_ahead := 0.7             ## seconds of travel the camera leads by
var max_lead := 0.32              ## at most this fraction of the visible height ahead of the car
var speed_pull := 0.5             ## 3D view: extra zoom at full speed (0 turns the dynamic zoom off). ISO has its own in ISO
var full_speed := 32.0            ## m/s where the speed pull maxes out (~72 mph)
var drift_pull := 0.15            ## extra zoom while drifting
var follow_sharpness := 6.0
var yaw_sharpness := 2.6

var _zoom_smooth := 0.05
var _dyn := 0.0
var _yaw := 0.0
var _focus := Vector3.ZERO


func _ready() -> void:
	near = 0.3
	far = 400.0
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		zoom = clampf(cfg.get_value("camera", "base_zoom", zoom), 0.0, 1.0)
		iso = cfg.get_value("camera", "iso", iso)
	_zoom_smooth = zoom
	_apply_projection()
	if car:
		snap()


func view_name() -> String:
	return "ISO" if iso else "3D"


func toggle_view() -> void:
	iso = not iso
	_apply_projection()
	save()


## Positive = zoom out.
func zoom_by(amount: float) -> void:
	zoom = clampf(zoom + amount, 0.0, 1.0)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("camera", "base_zoom", zoom)
	cfg.set_value("camera", "iso", iso)
	cfg.save(SAVE_PATH)


func snap() -> void:
	_focus = car.global_position
	_yaw = car.global_rotation.y
	_place(0.0)


func _apply_projection() -> void:
	if iso:
		projection = Camera3D.PROJECTION_ORTHOGONAL
	else:
		projection = Camera3D.PROJECTION_PERSPECTIVE
		fov = 42.0


func _process(dt: float) -> void:
	if car == null:
		return
	_zoom_smooth = lerpf(_zoom_smooth, zoom, 1.0 - exp(-10.0 * dt))
	var v: Vector3 = car.linear_velocity
	v.y = 0.0

	# Dynamic zoom: pull out with speed and drifting. Out a bit quicker than back in, so it
	# doesn't pump in and out between gear changes.
	var pull: float = ISO.speed_pull if iso else speed_pull
	var dpull: float = ISO.drift_pull if iso else drift_pull
	var dyn_target := clampf(v.length() / full_speed, 0.0, 1.0) * pull
	if car.drifting:
		dyn_target += dpull
	var rate := 1.8 if dyn_target > _dyn else 0.7
	_dyn = lerpf(_dyn, dyn_target, 1.0 - exp(-rate * dt))

	# Lead the car so most of the screen is road coming at you (more reaction time).
	# The car sits toward the bottom of the screen, more so the faster you go.
	var view_height: float = size if iso else lerpf(FOLLOW.dist_close, FOLLOW.dist_far, clampf(_zoom_smooth + _dyn, 0.0, 1.0)) * 0.75
	var ahead := (v * look_ahead).limit_length(view_height * max_lead)
	_focus = _focus.lerp(car.global_position + ahead, 1.0 - exp(-follow_sharpness * dt))

	var target_yaw: float = car.global_rotation.y
	if v.length() > 3.0 and car.forward_speed > 0.0:
		target_yaw = atan2(-v.x, -v.z)
	_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-yaw_sharpness * dt))
	_place(v.length())


func _place(_spd: float) -> void:
	var z := clampf(_zoom_smooth + _dyn, 0.0, 1.0)
	var pitch: float
	var d: float
	if iso:
		pitch = lerpf(ISO.pitch_close, ISO.pitch_far, z)
		size = lerpf(ISO.size_close, ISO.size_far, z)
		d = ISO.distance
	else:
		pitch = lerpf(FOLLOW.pitch_close, FOLLOW.pitch_far, z)
		d = lerpf(FOLLOW.dist_close, FOLLOW.dist_far, z)
	var b := Basis.from_euler(Vector3(deg_to_rad(-pitch), _yaw, 0.0))
	global_transform = Transform3D(b, _focus + b.z * d)
