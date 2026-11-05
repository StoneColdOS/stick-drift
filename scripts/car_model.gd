extends Node3D
## The car's looks: a blocky two-tone ("panda") old-school coupe, plus skid marks, tire smoke,
## engine smoke and brake lights. Swap this for a real low-poly model later; the physics won't care.
## Car faces -Z.

const Util := preload("res://scripts/util.gd")

const WHITE := Color(0.92, 0.92, 0.90)
const BLACK := Color(0.05, 0.05, 0.06)
const GLASS := Color(0.05, 0.07, 0.10)
const TIRE := Color(0.04, 0.04, 0.04)
const HEADLIGHT := Color(1.0, 0.93, 0.8)
const TAIL := Color(1.0, 0.08, 0.05)
const MAX_SKIDS := 1200

var car  ## car.gd
var front_left: Node3D
var front_right: Node3D
var tail_mat: StandardMaterial3D
var tire_smoke: Array[CPUParticles3D] = []
var engine_smoke: CPUParticles3D
var skids: MultiMesh
var skid_next := 0

# Lights & exhaust
var tail_halos: Array[MeshInstance3D] = []
var tail_pool: MeshInstance3D
var tail_halo_mat: StandardMaterial3D
var tail_pool_mat: StandardMaterial3D
var exhaust: CPUParticles3D
var exhaust_burst: CPUParticles3D
var backfire: MeshInstance3D
var backfire_mat: StandardMaterial3D
var _backfire_t := 0.0
var _rng := RandomNumberGenerator.new()
var last_mark := [Vector3.INF, Vector3.INF]


func build(the_car) -> void:
	car = the_car
	var white := Util.lit(WHITE, 0.35)
	var black := Util.lit(BLACK, 0.6)
	var glass := Util.lit(GLASS, 0.1)

	Util.box(self, Vector3(1.66, 0.30, 4.22), Vector3(0, 0.45, 0), black)
	Util.box(self, Vector3(1.64, 0.30, 4.16), Vector3(0, 0.74, 0), white)
	Util.box(self, Vector3(1.56, 0.08, 1.20), Vector3(0, 0.86, -1.45), white, Vector3(-4, 0, 0))
	Util.box(self, Vector3(1.42, 0.48, 1.90), Vector3(0, 1.12, 0.35), glass)
	Util.box(self, Vector3(1.38, 0.06, 1.55), Vector3(0, 1.38, 0.45), white)
	Util.box(self, Vector3(1.60, 0.20, 0.12), Vector3(0, 0.42, -2.12), black)
	Util.box(self, Vector3(1.60, 0.20, 0.12), Vector3(0, 0.42, 2.12), black)
	Util.box(self, Vector3(1.50, 0.05, 0.25), Vector3(0, 0.92, 1.95), black)

	var hl := Util.emissive(HEADLIGHT, 2.5)
	Util.box(self, Vector3(0.38, 0.12, 0.06), Vector3(-0.55, 0.72, -2.09), hl)
	Util.box(self, Vector3(0.38, 0.12, 0.06), Vector3(0.55, 0.72, -2.09), hl)

	tail_mat = Util.emissive_instance(TAIL, 1.3)
	Util.box(self, Vector3(0.5, 0.14, 0.06), Vector3(-0.52, 0.74, 2.1), tail_mat)
	Util.box(self, Vector3(0.5, 0.14, 0.06), Vector3(0.52, 0.74, 2.1), tail_mat)

	var tire := Util.lit(TIRE, 0.9)
	front_left = _wheel(Vector3(-0.74, 0.31, -car.front_axle), tire)
	front_right = _wheel(Vector3(0.74, 0.31, -car.front_axle), tire)
	_wheel(Vector3(-0.74, 0.31, -car.rear_axle), tire)
	_wheel(Vector3(0.74, 0.31, -car.rear_axle), tire)

	# Warm halogen beam, to contrast with the cold LED street lights.
	var beam := SpotLight3D.new()
	beam.position = Vector3(0, 0.8, -2.2)
	beam.rotation_degrees = Vector3(-10, 0, 0)
	beam.spot_range = 30.0
	beam.spot_angle = 35.0
	beam.light_energy = 3.0
	beam.light_color = Color(1.0, 0.92, 0.78)
	beam.shadow_enabled = false
	add_child(beam)

	var smoke := Color(0.8, 0.8, 0.84, 0.35)
	tire_smoke.append(_smoke(Vector3(-0.8, 0.3, -car.rear_axle), smoke, 2.2))
	tire_smoke.append(_smoke(Vector3(0.8, 0.3, -car.rear_axle), smoke, 2.2))
	engine_smoke = _smoke(Vector3(0, 1.0, -1.6), Color(0.22, 0.22, 0.24, 0.55), 1.6)

	_build_lights()
	_build_exhaust()
	car.gear_changed.connect(_on_gear_changed)
	_build_skids()


func _wheel(pos: Vector3, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.position = pos
	var w := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.31
	cyl.bottom_radius = 0.31
	cyl.height = 0.22
	cyl.radial_segments = 10
	w.mesh = cyl
	w.material_override = mat
	w.rotation_degrees = Vector3(0, 0, 90)
	pivot.add_child(w)
	return pivot


func _smoke(pos: Vector3, color: Color, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	add_child(p)
	p.position = pos
	p.local_coords = false
	p.emitting = false
	p.amount = 40
	p.lifetime = 1.8
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true  # without this, idle particles render as full-size black quads
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Util.soft_circle()
	quad.material = m
	p.mesh = quad
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(0, 0.3, 0)
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(1, 1))
	p.scale_amount_curve = grow
	p.color = color
	var fade := Gradient.new()
	fade.set_offset(0, 0.0)
	fade.set_offset(1, 1.0)
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	return p


# ------------------------------------------------------------------ glow

## Additive, unshaded, soft-edged. Colors above 1.0 trip the bloom.
static func _additive(c: Color, billboard: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = c
	m.albedo_texture = Util.soft_circle()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return m


func _halo(pos: Vector3, size: float, mat: Material) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = pos
	return mi


func _ground_glow(pos: Vector3, size: Vector2, mat: Material) -> MeshInstance3D:
	var p := PlaneMesh.new()
	p.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = p
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = pos
	return mi


func _build_lights() -> void:
	# Headlights: bright halos on the lamps, plus a warm beam pool stretched out on the road.
	var head_halo := _additive(Color(1.6, 1.45, 1.15, 0.9), true)
	_halo(Vector3(-0.55, 0.75, -2.2), 1.3, head_halo)
	_halo(Vector3(0.55, 0.75, -2.2), 1.3, head_halo)
	_ground_glow(Vector3(0, 0.05, -7.5), Vector2(5.5, 11.0), _additive(Color(1.0, 0.85, 0.6, 0.32), false))
	_ground_glow(Vector3(0, 0.06, -4.2), Vector2(3.2, 4.0), _additive(Color(1.0, 0.9, 0.7, 0.3), false))

	# Tail lights: red halos and a red wash on the road behind, both flare up when braking.
	tail_halo_mat = _additive(Color(1.8, 0.12, 0.08, 0.7), true)
	tail_halos.append(_halo(Vector3(-0.52, 0.75, 2.2), 0.9, tail_halo_mat))
	tail_halos.append(_halo(Vector3(0.52, 0.75, 2.2), 0.9, tail_halo_mat))
	tail_pool_mat = _additive(Color(1.0, 0.05, 0.03, 0.22), false)
	tail_pool = _ground_glow(Vector3(0, 0.05, 3.3), Vector2(3.6, 3.0), tail_pool_mat)


# ------------------------------------------------------------------ exhaust

func _build_exhaust() -> void:
	# The pipe itself, poking out under the rear bumper on the left.
	var pipe := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.06
	cyl.height = 0.25
	cyl.radial_segments = 8
	pipe.mesh = cyl
	pipe.material_override = Util.lit(Color(0.35, 0.35, 0.37), 0.3)
	add_child(pipe)
	pipe.position = Vector3(-0.55, 0.28, 2.15)
	pipe.rotation_degrees = Vector3(90, 0, 0)

	var tip := Vector3(-0.55, 0.28, 2.3)
	exhaust = _puffs(tip, 36, 1.3, 0.0, Color(0.8, 0.8, 0.85, 0.32))
	exhaust.emitting = true
	exhaust_burst = _puffs(tip, 16, 0.9, 1.0, Color(0.85, 0.85, 0.9, 0.5))
	exhaust_burst.one_shot = true

	# Backfire: a quick orange flash at the tip.
	backfire_mat = _additive(Color(2.5, 1.1, 0.3, 0.0), true)
	backfire = _halo(tip + Vector3(0, 0, 0.25), 0.9, backfire_mat)


func _puffs(pos: Vector3, amount: int, lifetime: float, explosive: float, color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	add_child(p)
	p.position = pos
	p.local_coords = false
	p.emitting = false
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = explosive
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.95
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Util.soft_circle()
	quad.material = m
	p.mesh = quad
	p.direction = Vector3(0, 0.3, 1)  # out the back
	p.spread = 18.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.5
	p.gravity = Vector3(0, 0.4, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.0))
	p.scale_amount_curve = grow
	p.color = color
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	return p


func _on_gear_changed(old_gear: int, new_gear: int) -> void:
	if car.motor.is_blown() or new_gear == 0:
		return
	exhaust_burst.restart()
	exhaust_burst.emitting = true
	# Backfire on downshifts and on quick high-rpm upshifts.
	if (old_gear > new_gear and new_gear > 0) or car.motor.rpm > 6000.0:
		_backfire_t = 0.12


func _build_skids() -> void:
	skids = MultiMesh.new()
	skids.transform_format = MultiMesh.TRANSFORM_3D
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.26, 0.42)
	skids.mesh = plane
	skids.instance_count = MAX_SKIDS
	skids.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = skids
	mmi.material_override = Util.glow(Color(0.0, 0.0, 0.0, 0.7))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.top_level = true  # lives in world space, not attached to the car
	add_child(mmi)
	mmi.global_transform = Transform3D.IDENTITY


func _process(dt: float) -> void:
	if car == null:
		return
	var steer := -deg_to_rad(car.steer_angle)
	front_left.rotation.y = steer
	front_right.rotation.y = steer

	var sliding: bool = car.speed > 2.0 and (car.rear_slide > 0.15 or car.drifting or car.handbrake() > 0.5)
	for p in tire_smoke:
		p.emitting = sliding

	var health: float = car.motor.health
	engine_smoke.emitting = health < 0.35

	var braking: bool = car.handbrake() > 0.1 or car.gear == 0
	tail_mat.emission_energy_multiplier = 4.5 if braking else 1.3
	var flare := 1.0 if braking else 0.0
	tail_halo_mat.albedo_color.a = lerpf(0.55, 1.0, flare)
	for h in tail_halos:
		h.scale = Vector3.ONE * lerpf(1.0, 1.7, flare)
	tail_pool_mat.albedo_color.a = lerpf(0.16, 0.38, flare)
	tail_pool.scale = Vector3.ONE * lerpf(1.0, 1.35, flare)

	# Exhaust: lazy puffs at idle, more and faster with revs. Dead engine = no exhaust.
	var running: bool = not car.motor.is_blown()
	exhaust.emitting = running
	var rev := clampf((car.motor.rpm - 900.0) / 7000.0, 0.0, 1.0)
	exhaust.initial_velocity_min = lerpf(0.6, 3.0, rev)
	exhaust.initial_velocity_max = lerpf(1.2, 5.0, rev)
	exhaust.speed_scale = lerpf(0.8, 1.6, rev)

	# Backfire flash, plus the odd pop while sitting on the limiter.
	if running and car.motor.over_redline() and _rng.randf() < 0.04:
		_backfire_t = 0.08
	_backfire_t = maxf(0.0, _backfire_t - dt)
	backfire_mat.albedo_color.a = 1.0 if _backfire_t > 0.0 else 0.0
	backfire.scale = Vector3.ONE * _rng.randf_range(0.8, 1.4)

	if sliding:
		_mark(0, Vector3(-0.74, 0, -car.rear_axle))
		_mark(1, Vector3(0.74, 0, -car.rear_axle))
	else:
		last_mark = [Vector3.INF, Vector3.INF]


func _mark(i: int, local: Vector3) -> void:
	var p := to_global(local)
	p.y = 0.03
	var last: Vector3 = last_mark[i]
	if last != Vector3.INF and p.distance_to(last) < 0.3:
		return
	var dir: Vector3 = (p - last) if last != Vector3.INF else car.forward()
	dir.y = 0.0
	if dir.length() < 0.001:
		dir = Vector3.FORWARD
	last_mark[i] = p
	var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
	skids.set_instance_transform(skid_next, Transform3D(basis, p))
	skid_next = (skid_next + 1) % MAX_SKIDS
	skids.visible_instance_count = mini(skids.visible_instance_count + 1, MAX_SKIDS)
