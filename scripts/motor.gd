extends RefCounted
## The engine. Throttle is always on, so the only ways to keep it alive are:
## shift up before it sits on the limiter, and don't downshift so hard it over-revs.
## Past the torque cutoff the curve goes negative, which gives you engine braking on downshifts.

## Normalized torque curve: x = rpm, y = fraction of peak torque.
const CURVE := [
	Vector2(0, 0.50),
	Vector2(1000, 0.55),
	Vector2(3000, 0.80),
	Vector2(5200, 1.00),
	Vector2(6600, 0.95),
	Vector2(7600, 0.80),
	Vector2(8000, 0.20),
	Vector2(8400, -0.40),
	Vector2(9400, -1.00),
	Vector2(13000, -1.30),
]

var idle_rpm := 900.0
var redline_rpm := 7600.0        ## tach turns red, SHIFT! warning
var peak_torque := 150.0
var damage_rpm := 7900.0         ## above this the engine slowly wears (sitting on the limiter)
var sustained_damage := 0.6      ## health per second, per 1000 rpm over damage_rpm
var money_shift_rpm := 9400.0    ## above this you've money-shifted
var money_shift_damage := 2.5    ## extra health per second, per 1000 rpm over money_shift_rpm

var rpm := 900.0
var health := 1.0


func is_blown() -> bool:
	return health <= 0.0


func over_redline() -> bool:
	return rpm > redline_rpm


func torque_at(r: float) -> float:
	if r <= CURVE[0].x:
		return CURVE[0].y * peak_torque
	for i in range(1, CURVE.size()):
		if r <= CURVE[i].x:
			var t := inverse_lerp(CURVE[i - 1].x, CURVE[i].x, r)
			return lerpf(CURVE[i - 1].y, CURVE[i].y, t) * peak_torque
	return CURVE[CURVE.size() - 1].y * peak_torque


## target_rpm: what the wheels say the engine should be doing.
## engaged: in gear. It's clutchless, so rpm locks straight to the wheels.
func tick(target_rpm: float, engaged: bool, dt: float) -> void:
	if is_blown():
		rpm = move_toward(rpm, 0.0, 8000.0 * dt)
		return
	if engaged:
		rpm = maxf(idle_rpm, target_rpm)
	else:
		rpm = move_toward(rpm, idle_rpm, 5000.0 * dt)

	var damage := 0.0
	if rpm > damage_rpm:
		damage += sustained_damage * (rpm - damage_rpm) / 1000.0 * dt
	if rpm > money_shift_rpm:
		damage += money_shift_damage * (rpm - money_shift_rpm) / 1000.0 * dt
	health = maxf(0.0, health - damage)


func repair() -> void:
	health = 1.0
	rpm = idle_rpm
