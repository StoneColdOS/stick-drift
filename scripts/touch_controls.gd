extends Control
## On-screen controls, landscape:
##   Bottom-left:  steering wheel. Put a thumb on it and twist; let go and it spins back to center.
##   Bottom-right: H-pattern shifter. Drag the knob through the gate.
##   No e-brake: flick the wheel or downshift while turning to kick the rear out.
##   Top-right:    ISO/3D camera toggle, RESET, then zoom out (-) and in (+).
##                 Pinch anywhere empty to zoom too.
##   Center (when the engine's blown): NEW ENGINE.
## Everything is semi-transparent white so the night scene shows through.

const Gate := preload("res://scripts/shifter_gate.gd")
const Gearbox := preload("res://scripts/gearbox.gd")
const Haptics := preload("res://scripts/haptics.gd")
const SETTINGS := "user://settings.cfg"

const GHOST := Color(1, 1, 1, 0.38)
const GHOST_STRONG := Color(1, 1, 1, 0.55)
const FAINT := Color(1, 1, 1, 0.16)
const ACCENT := Color(1.0, 0.55, 0.15, 0.85)

const WHEEL_R := 175.0
const WHEEL_MAX := 720.0        ## degrees each way for full lock: two full turns, like a real car
const WHEEL_RETURN := 1100.0    ## self-centering when you let go, degrees per second
const UNIT := 92.0              ## shifter gate unit in pixels
const KNOB_FOLLOW := 30.0       ## gate units per second while dragging
const KNOB_SETTLE := 9.0

var input   ## car_input.gd
var car     ## car.gd
var camera  ## chase_camera.gd
var kb_steer := 0.0      ## keyboard / gamepad, set by main.gd each frame
var kb_handbrake := 0.0

# Layout (recomputed on resize)
var wheel_center := Vector2.ZERO
var shifter_center := Vector2.ZERO
var reset_pos := Vector2.ZERO
var mode_btn := Rect2(30, 24, 170, 46)  ## CHILL / RISKY engine toggle
var view_pos := Vector2.ZERO
var zoom_out_pos := Vector2.ZERO
var zoom_in_pos := Vector2.ZERO
var free_fingers := {}  ## fingers not on a control, for pinch zoom
var engine_btn := Rect2()

# Wheel
var wheel_angle := 0.0
var wheel_finger := -1
var wheel_last := 0.0

# Shifter
var knob := Vector2.ZERO
var knob_target := Vector2.ZERO
var knob_finger := -1
var knob_grab := Vector2.ZERO



func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var s := get_viewport_rect().size
	wheel_center = Vector2(60 + WHEEL_R, s.y - 50 - WHEEL_R)
	shifter_center = Vector2(s.x - 60 - UNIT * 1.9, s.y - 60 - UNIT * 1.6)
	reset_pos = Vector2(s.x - 70, 60)
	view_pos = Vector2(s.x - 165, 60)
	zoom_out_pos = Vector2(s.x - 70, 145)
	zoom_in_pos = Vector2(s.x - 70, 220)
	engine_btn = Rect2(s.x / 2 - 170, s.y / 2 + 40, 340, 80)
	queue_redraw()


## Keyboard and gamepad shifting go through here so the knob moves too.
func snap_to_gear(gear: int) -> void:
	knob_finger = -1
	knob = Gate.slot_for(gear)
	knob_target = knob
	_apply_gear()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_down(event.index, event.position)
		else:
			_up(event.index)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position)


func _down(finger: int, pos: Vector2) -> void:
	if car and car.motor.is_blown() and engine_btn.has_point(pos):
		car.repair_engine()
		return
	if mode_btn.grow(10).has_point(pos):
		if car:
			car.motor.damage_enabled = not car.motor.damage_enabled
			car.repair_engine()
			var cfg := ConfigFile.new()
			cfg.load(SETTINGS)
			cfg.set_value("engine", "risky", car.motor.damage_enabled)
			cfg.save(SETTINGS)
		return
	if pos.distance_to(view_pos) < 40:
		if camera:
			camera.toggle_view()
		return
	if pos.distance_to(zoom_out_pos) < 38 or pos.distance_to(zoom_in_pos) < 38:
		if camera:
			camera.zoom_by(0.15 if pos.distance_to(zoom_out_pos) < 38 else -0.15)
			camera.save()
		return
	if pos.distance_to(reset_pos) < 45:
		if car:
			car.reset_to_spawn()
		snap_to_gear(0)
		return
	if wheel_finger == -1 and pos.distance_to(wheel_center) < WHEEL_R * 1.25:
		wheel_finger = finger
		wheel_last = _angle_to(wheel_center, pos)
		return
	var local := _to_gate(pos)
	if knob_finger == -1 and absf(local.x) < 1.9 and absf(local.y) < 1.9:
		knob_finger = finger
		knob_grab = knob - local
		knob_target = knob
		return
	free_fingers[finger] = pos


func _drag(finger: int, pos: Vector2) -> void:
	if finger == wheel_finger:
		if pos.distance_to(wheel_center) > WHEEL_R * 0.2:  # angles get jumpy near the center
			var a := _angle_to(wheel_center, pos)
			wheel_angle = clampf(wheel_angle + rad_to_deg(angle_difference(wheel_last, a)), -WHEEL_MAX, WHEEL_MAX)
			wheel_last = a
	elif finger == knob_finger:
		knob_target = Gate.project(_to_gate(pos) + knob_grab)
	elif free_fingers.has(finger):
		if free_fingers.size() == 2 and camera:
			var other: Vector2
			for f in free_fingers:
				if f != finger:
					other = free_fingers[f]
			var before := other.distance_to(free_fingers[finger])
			var after := other.distance_to(pos)
			camera.zoom_by((before - after) / 350.0)  # pinch in = zoom out, spread = zoom in
		free_fingers[finger] = pos


func _up(finger: int) -> void:
	if free_fingers.has(finger):
		free_fingers.erase(finger)
		if camera:
			camera.save()
	if finger == wheel_finger:
		wheel_finger = -1
	elif finger == knob_finger:
		knob_finger = -1
		# Released deep enough into a slot: seat it. Otherwise spring back to neutral.
		if absf(knob.y) >= Gate.ENGAGE:
			knob_target = Vector2(roundf(knob.x), signf(knob.y))
		else:
			knob_target = Vector2.ZERO


func _process(dt: float) -> void:
	if wheel_finger == -1:
		wheel_angle = move_toward(wheel_angle, 0.0, WHEEL_RETURN * dt)
	knob = Gate.move_along(knob, knob_target, (KNOB_FOLLOW if knob_finger != -1 else KNOB_SETTLE) * dt)
	_apply_gear()

	if input:
		var touch_steer := wheel_angle / WHEEL_MAX  # clockwise on screen = right
		input.steer = kb_steer if absf(kb_steer) > 0.05 else touch_steer
		input.handbrake = kb_handbrake
	queue_redraw()


func _apply_gear() -> void:
	if input == null:
		return
	var g := Gate.gear_at(knob)
	if g != input.gear and g != 0:
		Haptics.buzz()
	input.gear = g


func _to_gate(pos: Vector2) -> Vector2:
	var d := (pos - shifter_center) / UNIT
	return Vector2(d.x, -d.y)


func _gate_to_screen(g: Vector2) -> Vector2:
	return shifter_center + Vector2(g.x, -g.y) * UNIT


static func _angle_to(c: Vector2, p: Vector2) -> float:
	return atan2(p.y - c.y, p.x - c.x)


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	var font := ThemeDB.fallback_font

	# Steering wheel
	draw_set_transform(wheel_center, deg_to_rad(wheel_angle), Vector2.ONE)
	for a in [0.0, PI, PI / 2]:
		draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * (WHEEL_R - 25), FAINT, 26.0)
	draw_circle(Vector2.ZERO, 48, FAINT)
	draw_arc(Vector2.ZERO, WHEEL_R - 16, 0, TAU, 72, GHOST, 32.0, true)
	draw_rect(Rect2(-10, -WHEEL_R - 2, 20, 36), ACCENT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Lock gauge: the wheel looks the same after a full spin, so an arc around the rim shows
	# how far you're turned. Half the rim = full lock.
	var frac := wheel_angle / WHEEL_MAX
	if absf(frac) > 0.01:
		var start := -PI / 2
		draw_arc(wheel_center, WHEEL_R + 14, start, start + frac * PI, 48, ACCENT, 8.0, true)

	# Shifter gate
	draw_rect(Rect2(shifter_center - Vector2(UNIT * 1.9, UNIT * 1.9), Vector2(UNIT * 3.8, UNIT * 3.8)), Color(1, 1, 1, 0.05))
	draw_line(_gate_to_screen(Vector2(-1, 0)), _gate_to_screen(Vector2(1, 0)), FAINT, 14.0)
	for c in [-1, 0, 1]:
		draw_line(_gate_to_screen(Vector2(c, -1)), _gate_to_screen(Vector2(c, 1)), FAINT, 14.0)
	for g in [1, 2, 3, 4, 5, Gate.REVERSE]:
		var slot := Gate.slot_for(g)
		var p := _gate_to_screen(slot) + Vector2(-15, -40 if slot.y > 0 else 60)
		draw_string(font, p, Gearbox.label(g), HORIZONTAL_ALIGNMENT_CENTER, 30, 30, GHOST)
	var kp := _gate_to_screen(knob)
	draw_circle(kp, 50, GHOST_STRONG)
	draw_arc(kp, 34, 0, TAU, 40, ACCENT, 4.0, true)

	# Reset
	draw_circle(reset_pos, 36, Color(1, 1, 1, 0.18))
	draw_string(font, reset_pos + Vector2(-36, 7), "RESET", HORIZONTAL_ALIGNMENT_CENTER, 72, 18, Color.WHITE)

	# Engine mode toggle (top-left)
	if car:
		var risky: bool = car.motor.damage_enabled
		draw_rect(mode_btn, Color(1, 0.3, 0.2, 0.3) if risky else Color(0.5, 0.9, 1.0, 0.18))
		draw_string(font, mode_btn.position + Vector2(0, 31), "ENGINE: RISKY" if risky else "ENGINE: CHILL", HORIZONTAL_ALIGNMENT_CENTER, mode_btn.size.x, 18, Color.WHITE)

	# View toggle + zoom
	draw_circle(view_pos, 36, Color(1, 1, 1, 0.18))
	var vname: String = camera.view_name() if camera else "VIEW"
	draw_string(font, view_pos + Vector2(-36, 7), vname, HORIZONTAL_ALIGNMENT_CENTER, 72, 15, Color.WHITE)
	for b in [[zoom_out_pos, "−"], [zoom_in_pos, "+"]]:
		draw_circle(b[0], 30, Color(1, 1, 1, 0.18))
		draw_string(font, b[0] + Vector2(-30, 12), b[1], HORIZONTAL_ALIGNMENT_CENTER, 60, 34, Color.WHITE)

	# New engine button (only when blown; the HUD draws the panel behind it)
	if car and car.motor.is_blown():
		draw_rect(engine_btn, Color(1, 1, 1, 0.25))
		draw_string(font, engine_btn.position + Vector2(0, 52), "NEW ENGINE", HORIZONTAL_ALIGNMENT_CENTER, engine_btn.size.x, 34, Color.WHITE)
