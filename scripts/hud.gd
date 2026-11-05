extends Control
## Gear, speed, tach with redline, engine health, drift points, and the blown-engine screen.

const Gearbox := preload("res://scripts/gearbox.gd")

const TACH_MAX := 10000.0
const TACH_W := 520.0
const WHITE := Color(1, 1, 1, 0.9)
const DIM := Color(1, 1, 1, 0.7)
const HOT := Color(1.0, 0.28, 0.22, 0.95)

var car  ## car.gd
var drift_points := 0.0
var best := 0.0
var _hold := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(dt: float) -> void:
	if car == null:
		return
	# Drift points: angle x speed while sliding, banked after a short pause.
	if car.drifting and not car.motor.is_blown():
		drift_points += absf(car.slip_angle) * car.speed * dt * 0.6
		_hold = 1.5
	elif _hold > 0.0:
		_hold -= dt
		if _hold <= 0.0:
			best = maxf(best, drift_points)
			drift_points = 0.0
	queue_redraw()


func _draw() -> void:
	if car == null:
		return
	var font := ThemeDB.fallback_font
	var s := get_viewport_rect().size
	var cx := s.x / 2
	var m = car.motor
	var flash := fmod(Time.get_ticks_msec() / 1000.0 * 8.0, 1.0) > 0.5

	# Gear + speed
	draw_string(font, Vector2(cx - 60, 105), Gearbox.label(car.gear), HORIZONTAL_ALIGNMENT_CENTER, 120, 96, WHITE)
	draw_string(font, Vector2(cx - 330, 80), "%d MPH" % roundi(car.speed * 2.237), HORIZONTAL_ALIGNMENT_RIGHT, 240, 32, DIM)
	if best > 0.0:
		draw_string(font, Vector2(cx + 90, 80), "BEST %d" % roundi(best), HORIZONTAL_ALIGNMENT_LEFT, 260, 28, DIM)

	# Tach
	var tach := Rect2(cx - TACH_W / 2, 130, TACH_W, 18)
	draw_rect(tach, Color(0, 0, 0, 0.4))
	var red_x: float = TACH_W * m.redline_rpm / TACH_MAX
	draw_rect(Rect2(tach.position + Vector2(red_x, 0), Vector2(TACH_W - red_x, 18)), Color(1, 0.15, 0.1, 0.35))
	var fill := clampf(m.rpm / TACH_MAX, 0.0, 1.0)
	var hot: bool = m.over_redline()
	draw_rect(Rect2(tach.position, Vector2(TACH_W * fill, 18)), HOT if hot and flash else Color(1, 1, 1, 0.75))
	draw_string(font, tach.position + Vector2(0, 44), "%d RPM" % roundi(m.rpm), HORIZONTAL_ALIGNMENT_CENTER, TACH_W, 20, DIM)

	# Engine health (top left)
	draw_string(font, Vector2(40, 42), "ENGINE", HORIZONTAL_ALIGNMENT_LEFT, 200, 20, DIM)
	draw_rect(Rect2(40, 52, 200, 10), Color(0, 0, 0, 0.4))
	var hc := Color(0.55, 1.0, 0.6, 0.85).lerp(HOT, 1.0 - m.health)
	draw_rect(Rect2(40, 52, 200 * m.health, 10), hc)

	# Warnings
	if not m.is_blown():
		var warn := ""
		if m.rpm > m.money_shift_rpm:
			warn = "MONEY SHIFT!"
		elif hot and flash:
			warn = "SHIFT!"
		if warn != "":
			draw_string(font, Vector2(0, s.y / 2 - 90), warn, HORIZONTAL_ALIGNMENT_CENTER, s.x, 64, HOT)

	# Drift points
	if drift_points > 1.0:
		draw_string(font, Vector2(0, 220), "DRIFT  %d" % roundi(drift_points), HORIZONTAL_ALIGNMENT_CENTER, s.x, 44, WHITE)
		if car.drifting:
			draw_string(font, Vector2(0, 252), "%d°" % roundi(absf(car.slip_angle)), HORIZONTAL_ALIGNMENT_CENTER, s.x, 24, DIM)

	# Blown engine panel (the NEW ENGINE button is drawn by the touch controls on top)
	if m.is_blown():
		var panel := Rect2(cx - 340, s.y / 2 - 150, 680, 290)
		draw_rect(panel, Color(0, 0, 0, 0.72))
		draw_string(font, Vector2(panel.position.x, panel.position.y + 95), "ENGINE BLOWN", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 72, HOT)
		draw_string(font, Vector2(panel.position.x, panel.position.y + 145), "should've shifted", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 28, DIM)
