extends Camera3D
## High third-person chase cam (think Over the Hill) with smooth zoom.
## zoom 0 = close and a little lower, zoom 1 = far and nearly top-down. Pinch, the +/- buttons,
## the mouse wheel or the gamepad's Y/X change it, and it's remembered between sessions.
## It turns toward where the car is *going* (its velocity), so in a drift you see the car swing
## sideways while the road ahead stays in view.

const SAVE_PATH := "user://camera.cfg"
const CLOSE := {"pitch": 44.0, "distance": 13.0}
const FAR := {"pitch": 68.0, "distance": 42.0}

var car  ## car.gd
var zoom := 0.45                 ## 0..1
var look_ahead := 0.35
var max_look_ahead := 9.0
var speed_zoom := 0.1
var follow_sharpness := 6.0
var yaw_sharpness := 2.6

var _zoom_smooth := 0.45
var _yaw := 0.0
var _focus := Vector3.ZERO


func _ready() -> void:
	fov = 42.0
	near = 0.3
	far = 400.0
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		zoom = clampf(cfg.get_value("camera", "zoom", zoom), 0.0, 1.0)
	_zoom_smooth = zoom
	if car:
		snap()


## Positive = zoom out (farther, higher).
func zoom_by(amount: float) -> void:
	zoom = clampf(zoom + amount, 0.0, 1.0)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("camera", "zoom", zoom)
	cfg.save(SAVE_PATH)


func snap() -> void:
	_focus = car.global_position
	_yaw = car.global_rotation.y
	_place(0.0)


func _process(dt: float) -> void:
	if car == null:
		return
	_zoom_smooth = lerpf(_zoom_smooth, zoom, 1.0 - exp(-10.0 * dt))
	var v: Vector3 = car.linear_velocity
	v.y = 0.0

	var ahead := (v * look_ahead).limit_length(max_look_ahead)
	_focus = _focus.lerp(car.global_position + ahead, 1.0 - exp(-follow_sharpness * dt))

	var target_yaw: float = car.global_rotation.y
	if v.length() > 3.0 and car.forward_speed > 0.0:
		target_yaw = atan2(-v.x, -v.z)
	_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-yaw_sharpness * dt))
	_place(v.length())


func _place(spd: float) -> void:
	var z := _zoom_smooth
	var pitch := lerpf(CLOSE.pitch, FAR.pitch, z)
	var d := lerpf(CLOSE.distance, FAR.distance, z) + spd * speed_zoom
	var b := Basis.from_euler(Vector3(deg_to_rad(-pitch), _yaw, 0.0))
	global_transform = Transform3D(b, _focus + b.z * d)
