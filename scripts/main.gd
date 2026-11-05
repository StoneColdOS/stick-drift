extends Node
## Builds the whole game: night lighting, the neighborhood, the car, the pixelated camera,
## the touch controls and the HUD.
##
## Keyboard (for testing on the Mac): A/D or arrows steer, 1-5 gears, N or 0 neutral, R reverse,
## Space kicks the rear out, Enter reset, V camera view, - and = zoom (or the mouse wheel). You can also drag the on-screen
## controls with the mouse.
## Gamepad (Thor): left stick steers, R1/L1 shift up/down, B kick, Y/X zoom, Select camera view,
## Start resets.

const CarScript := preload("res://scripts/car.gd")
const CarModel := preload("res://scripts/car_model.gd")
const CarInput := preload("res://scripts/car_input.gd")
const Neighborhood := preload("res://scripts/neighborhood.gd")
const Tokyo := preload("res://scripts/tokyo.gd")
const ChaseCamera := preload("res://scripts/chase_camera.gd")
const TouchControls := preload("res://scripts/touch_controls.gd")
const Hud := preload("res://scripts/hud.gd")
const Haptics := preload("res://scripts/haptics.gd")

const NIGHT_SKY := Color(0.1, 0.12, 0.18)  ## also the fog colour, so the distance melts away
const PIXEL_SHRINK := 2  ## 720 / 2 = 360 pixel-tall world. Lower = sharper, higher = chunkier.
const MAX_SHRINK := 3    ## automatic quality can drop to this if the phone is struggling
const SEQUENCE := [-1, 0, 1, 2, 3, 4, 5]  ## for gamepad up/down shifting

var input := CarInput.new()
var world_viewport: SubViewport
var world_container: SubViewportContainer
var _fps_low_time := 0.0
var world: Node3D
var town: Node3D
var car: RigidBody3D
var camera: Camera3D
var touch: Control
var hud: Control
var environment: Environment
var map_name := "tokyo"


func _ready() -> void:
	_setup_actions()

	var container := SubViewportContainer.new()
	container.stretch = true
	container.stretch_shrink = PIXEL_SHRINK
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	var post := ShaderMaterial.new()
	post.shader = load("res://scripts/retro.gdshader")
	container.material = post
	add_child(container)
	world_container = container
	world_viewport = SubViewport.new()
	world_viewport.msaa_3d = Viewport.MSAA_DISABLED
	container.add_child(world_viewport)

	world = Node3D.new()
	world.name = "World"
	world_viewport.add_child(world)
	_build_environment()

	var settings := ConfigFile.new()
	settings.load("user://settings.cfg")
	map_name = settings.get_value("world", "map", "tokyo")
	town = Tokyo.new() if map_name == "tokyo" else Neighborhood.new()
	town.name = map_name.capitalize()
	world.add_child(town)
	town.build()

	car = CarScript.new()
	car.name = "Car"
	car.input = input
	world.add_child(car)
	car.engine_blown.connect(func(): Haptics.buzz(300))
	car.motor.damage_enabled = settings.get_value("engine", "risky", false)
	car.global_transform = town.spawn
	car._spawn = town.spawn
	var model := CarModel.new()
	car.add_child(model)
	model.build(car)
	town.target = car

	camera = ChaseCamera.new()
	camera.car = car
	camera.env = environment
	world.add_child(camera)
	camera.current = true
	camera.snap()
	if "camera" in town:
		town.camera = camera

	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	hud = Hud.new()
	hud.car = car
	ui.add_child(hud)
	touch = TouchControls.new()
	touch.input = input
	touch.car = car
	touch.camera = camera
	touch.map_name = map_name
	ui.add_child(touch)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = NIGHT_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.33, 0.45)
	env.ambient_light_energy = 1.0
	# Depth fog the same colour as the night sky: clear around the car, swallowing the
	# distance. The camera moves the start/end as it zooms.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = NIGHT_SKY
	env.fog_density = 1.0
	env.fog_depth_curve = 1.4
	env.fog_depth_begin = 20.0
	env.fog_depth_end = 70.0
	env.glow_enabled = false  # costs ~20% fps on phones; the additive light halos glow without it
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	environment = env

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.62, 0.85)
	moon.light_energy = 0.3
	moon.shadow_enabled = false
	moon.rotation_degrees = Vector3(-50, -30, 0)
	world.add_child(moon)


func _process(dt: float) -> void:
	_auto_quality(dt)

	var kb_steer := Input.get_axis("steer_left", "steer_right")
	touch.kb_steer = kb_steer
	if Input.is_action_just_pressed("kick"):
		car.kick()

	for g in range(1, 6):
		if Input.is_action_just_pressed("gear_%d" % g):
			touch.snap_to_gear(g)
	if Input.is_action_just_pressed("gear_n"):
		touch.snap_to_gear(0)
	if Input.is_action_just_pressed("gear_r"):
		touch.snap_to_gear(-1)
	if Input.is_action_just_pressed("shift_up") or Input.is_action_just_pressed("shift_down"):
		var i := SEQUENCE.find(input.gear)
		i += 1 if Input.is_action_just_pressed("shift_up") else -1
		touch.snap_to_gear(SEQUENCE[clampi(i, 0, SEQUENCE.size() - 1)])
	if Input.is_action_just_pressed("view"):
		camera.toggle_view()
	if Input.is_action_just_pressed("zoom_out"):
		camera.zoom_by(0.15)
		camera.save()
	if Input.is_action_just_pressed("zoom_in"):
		camera.zoom_by(-0.15)
		camera.save()
	if Input.is_action_just_pressed("reset"):
		if car.motor.is_blown():
			car.repair_engine()
		else:
			car.reset_to_spawn()
			touch.snap_to_gear(0)


func _unhandled_input(event: InputEvent) -> void:
	# Mouse wheel zoom (for testing on the Mac).
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom_by(-0.05)
			camera.save()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom_by(0.05)
			camera.save()


## If the phone can't hold ~50 fps for a couple of seconds, render the world at a lower
## resolution (chunkier pixels). Never goes back up mid-session, so it doesn't flicker.
func _auto_quality(dt: float) -> void:
	if world_container.stretch_shrink >= MAX_SHRINK or Time.get_ticks_msec() < 4000:
		return
	if Engine.get_frames_per_second() < 50:
		_fps_low_time += dt
		if _fps_low_time > 2.5:
			world_container.stretch_shrink += 1
			_fps_low_time = 0.0
	else:
		_fps_low_time = maxf(0.0, _fps_low_time - dt)


func _setup_actions() -> void:
	_key("steer_left", [KEY_A, KEY_LEFT])
	_key("steer_right", [KEY_D, KEY_RIGHT])
	_key("kick", [KEY_SPACE])
	for g in range(1, 6):
		_key("gear_%d" % g, [KEY_0 + g])
	_key("gear_n", [KEY_N, KEY_0])
	_key("gear_r", [KEY_R])
	_key("reset", [KEY_ENTER])
	_key("view", [KEY_V])
	_key("zoom_out", [KEY_MINUS])
	_key("zoom_in", [KEY_EQUAL])
	_key("shift_up", [])
	_key("shift_down", [])

	_axis("steer_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("steer_right", JOY_AXIS_LEFT_X, 1.0)
	_button("kick", JOY_BUTTON_B)
	_button("shift_up", JOY_BUTTON_RIGHT_SHOULDER)
	_button("shift_down", JOY_BUTTON_LEFT_SHOULDER)
	_button("reset", JOY_BUTTON_START)
	_button("view", JOY_BUTTON_BACK)
	_button("zoom_out", JOY_BUTTON_Y)
	_button("zoom_in", JOY_BUTTON_X)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


func _key(action: String, keys: Array) -> void:
	_ensure(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)


func _axis(action: String, axis: JoyAxis, dir: float) -> void:
	_ensure(action)
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = dir
	InputMap.action_add_event(action, e)


func _button(action: String, button: JoyButton) -> void:
	_ensure(action)
	var e := InputEventJoypadButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)
