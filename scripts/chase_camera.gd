extends Camera3D
## Semi top-down chase cam. It turns toward where the car is *going* (its velocity), not where it's
## pointing, so in a drift you see the car swing sideways in front of you.

var car  ## car.gd
var pitch := 58.0
var distance := 22.0
var speed_zoom := 0.18
var look_ahead := 0.35
var max_look_ahead := 8.0
var follow_sharpness := 6.0
var yaw_sharpness := 2.2
var rotate_with_car := true  ## off = fixed north-up view like classic top-down drift games

var _yaw := 0.0
var _focus := Vector3.ZERO


func _ready() -> void:
	fov = 38.0
	near = 0.3
	far = 300.0
	if car:
		snap()


func snap() -> void:
	_focus = car.global_position
	_yaw = car.global_rotation.y
	_place(0.0)


func _process(dt: float) -> void:
	if car == null:
		return
	var v: Vector3 = car.linear_velocity
	v.y = 0.0
	var ahead := (v * look_ahead).limit_length(max_look_ahead)
	_focus = _focus.lerp(car.global_position + ahead, 1.0 - exp(-follow_sharpness * dt))

	if rotate_with_car:
		var target_yaw: float = car.global_rotation.y
		if v.length() > 3.0 and car.forward_speed > 0.0:
			target_yaw = atan2(-v.x, -v.z)
		_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-yaw_sharpness * dt))
	else:
		_yaw = 0.0
	_place(v.length())


func _place(spd: float) -> void:
	var b := Basis.from_euler(Vector3(deg_to_rad(-pitch), _yaw, 0.0))
	var d := distance + spd * speed_zoom
	global_transform = Transform3D(b, _focus + b.z * d)
