extends Camera3D
## Two camera styles, toggled with the VIEW button (remembered between sessions):
##   ISO:    fixed isometric. Looks down from one corner and never spins, so the world stays put
##           and you watch the car slide across it. Orthographic, like a classic arcade game.
##   FOLLOW: high chase cam (think Over the Hill) that turns toward where the car is going.
## Both zoom: pinch, the -/+ buttons, the mouse wheel or the gamepad's Y/X.

const SAVE_PATH := "user://camera.cfg"
const ISO_YAW := 45.0            ## looking from the south-east corner
const ISO := {"pitch_close": 40.0, "pitch_far": 55.0, "size_close": 13.0, "size_far": 50.0, "distance": 45.0}
const FOLLOW := {"pitch_close": 44.0, "pitch_far": 68.0, "dist_close": 13.0, "dist_far": 42.0}

var car  ## car.gd
var iso := true
var zoom := 0.2                  ## 0 = close, 1 = far
var look_ahead := 0.35
var max_look_ahead := 9.0
var speed_zoom := 0.1
var follow_sharpness := 6.0
var yaw_sharpness := 2.6

var _zoom_smooth := 0.2
var _yaw := 0.0
var _focus := Vector3.ZERO


func _ready() -> void:
	near = 0.3
	far = 400.0
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		zoom = clampf(cfg.get_value("camera", "zoom", zoom), 0.0, 1.0)
		iso = cfg.get_value("camera", "iso", iso)
	_zoom_smooth = zoom
	_apply_projection()
	if car:
		snap()


func view_name() -> String:
	return "ISO" if iso else "FOLLOW"


func toggle_view() -> void:
	iso = not iso
	_apply_projection()
	if car:
		_yaw = deg_to_rad(ISO_YAW) if iso else car.global_rotation.y
	save()


## Positive = zoom out.
func zoom_by(amount: float) -> void:
	zoom = clampf(zoom + amount, 0.0, 1.0)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("camera", "zoom", zoom)
	cfg.set_value("camera", "iso", iso)
	cfg.save(SAVE_PATH)


func snap() -> void:
	_focus = car.global_position
	_yaw = deg_to_rad(ISO_YAW) if iso else car.global_rotation.y
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

	var ahead := (v * look_ahead).limit_length(max_look_ahead)
	_focus = _focus.lerp(car.global_position + ahead, 1.0 - exp(-follow_sharpness * dt))

	if iso:
		_yaw = deg_to_rad(ISO_YAW)
	else:
		var target_yaw: float = car.global_rotation.y
		if v.length() > 3.0 and car.forward_speed > 0.0:
			target_yaw = atan2(-v.x, -v.z)
		_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-yaw_sharpness * dt))
	_place(v.length())


func _place(spd: float) -> void:
	var z := _zoom_smooth
	var pitch: float
	var d: float
	if iso:
		pitch = lerpf(ISO.pitch_close, ISO.pitch_far, z)
		size = lerpf(ISO.size_close, ISO.size_far, z) + spd * speed_zoom * 0.5
		d = ISO.distance
	else:
		pitch = lerpf(FOLLOW.pitch_close, FOLLOW.pitch_far, z)
		d = lerpf(FOLLOW.dist_close, FOLLOW.dist_far, z) + spd * speed_zoom
	var b := Basis.from_euler(Vector3(deg_to_rad(-pitch), _yaw, 0.0))
	global_transform = Transform3D(b, _focus + b.z * d)
