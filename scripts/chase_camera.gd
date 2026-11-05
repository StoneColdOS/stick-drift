extends Camera3D
## Chase cam with a few angles (the CAM button cycles them). It turns toward where the car is
## *going* (its velocity), so in a drift you see the car swing sideways while the road ahead
## stays in view. The car sits low on screen so most of the view is road ahead.

const VIEWS := [
	{"name": "CHASE", "pitch": 36.0, "distance": 16.0, "ahead": 0.3, "max_ahead": 7.0, "lift": 3.0, "rotate": true},
	{"name": "HIGH", "pitch": 55.0, "distance": 22.0, "ahead": 0.5, "max_ahead": 12.0, "lift": 6.0, "rotate": true},
	{"name": "TOP", "pitch": 80.0, "distance": 30.0, "ahead": 0.45, "max_ahead": 12.0, "lift": 0.0, "rotate": false},
]

var car  ## car.gd
var view := 0
var speed_zoom := 0.12
var follow_sharpness := 6.0
var yaw_sharpness := 2.6

var _yaw := 0.0
var _focus := Vector3.ZERO


func _ready() -> void:
	fov = 45.0
	near = 0.3
	far = 300.0
	if car:
		snap()


func view_name() -> String:
	return VIEWS[view].name


func cycle() -> void:
	view = (view + 1) % VIEWS.size()


func snap() -> void:
	_focus = car.global_position
	_yaw = car.global_rotation.y
	_place(0.0)


func _process(dt: float) -> void:
	if car == null:
		return
	var cfg: Dictionary = VIEWS[view]
	var v: Vector3 = car.linear_velocity
	v.y = 0.0

	# Aim ahead of the car: along its velocity, plus a fixed lift in the direction we're facing,
	# so the car sits in the lower part of the screen.
	var heading := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var ahead: Vector3 = (v * float(cfg.ahead)).limit_length(cfg.max_ahead) + heading * float(cfg.lift)
	_focus = _focus.lerp(car.global_position + ahead, 1.0 - exp(-follow_sharpness * dt))

	if cfg.rotate:
		var target_yaw: float = car.global_rotation.y
		if v.length() > 3.0 and car.forward_speed > 0.0:
			target_yaw = atan2(-v.x, -v.z)
		_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-yaw_sharpness * dt))
	else:
		_yaw = lerp_angle(_yaw, 0.0, 1.0 - exp(-yaw_sharpness * dt))
	_place(v.length())


func _place(spd: float) -> void:
	var cfg: Dictionary = VIEWS[view]
	var b := Basis.from_euler(Vector3(deg_to_rad(-float(cfg.pitch)), _yaw, 0.0))
	var d: float = float(cfg.distance) + spd * speed_zoom
	global_transform = Transform3D(b, _focus + b.z * d)
