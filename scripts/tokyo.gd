extends Node3D
## A Tokyo-style night district: tight streets between mid- and high-rise blocks, rows of lit
## windows, glowing neon signs, vending machines, utility poles with sagging-straight wires,
## white crosswalks and an open parking lot in the middle to drift in.
##
## Buildings between the camera and the car get an x-ray hole cut around the car
## (scripts/building.gdshader), so tall buildings never hide it. Everything static is merged into a few meshes per block.

const Util := preload("res://scripts/util.gd")
const Batch := preload("res://scripts/mesh_batch.gd")

const BLOCKS := 5
const BLOCK := 36.0
const ROAD := 12.0
const LIGHT_RADIUS := 34.0
const FLOOR_H := 3.2

const LED_WHITE := Color(0.88, 0.93, 1.0)
const ASPHALT := Color(0.13, 0.135, 0.155)
const LOT_ASPHALT := Color(0.16, 0.165, 0.185)
const SIDEWALK := Color(0.34, 0.34, 0.36)
const CONCRETE := [
	Color(0.42, 0.42, 0.44), Color(0.36, 0.35, 0.34), Color(0.5, 0.47, 0.43),
	Color(0.3, 0.31, 0.34), Color(0.46, 0.44, 0.46), Color(0.27, 0.26, 0.27),
]
const WINDOW_COLORS := [Color(1.0, 0.95, 0.85), Color(0.85, 0.92, 1.0), Color(1.0, 0.82, 0.55)]
const NEON := [
	Color(1.0, 0.2, 0.55), Color(0.2, 0.9, 1.0), Color(1.0, 0.85, 0.2),
	Color(0.55, 0.3, 1.0), Color(1.0, 0.35, 0.15), Color(0.3, 1.0, 0.5),
]
const SIGN_DARK := Color(0.05, 0.05, 0.07)
const CUT_RADIUS := 0.2  ## x-ray circle around the car, fraction of screen height
const BUILDING_SHADER := preload("res://scripts/building.gdshader")

var rng := RandomNumberGenerator.new()
var lights: Array[OmniLight3D] = []
var spawn := Transform3D.IDENTITY
var target: Node3D  ## the car
var camera: Camera3D
var half := 0.0
var _cull_timer := 0.0
var _mats := {}
var _city := Batch.new()       ## emissive/unlit bits, merged across the whole map


func build(seed_value := 13) -> void:
	rng.seed = seed_value
	var cell := BLOCK + ROAD
	var total := BLOCKS * cell + ROAD
	half = total / 2.0

	var tiles := 8
	var tile := total / tiles
	for i in tiles:
		for j in tiles:
			var c := Vector3(-half + tile * (i + 0.5), -0.05, -half + tile * (j + 0.5))
			Util.box(self, Vector3(tile, 0.1, tile), c, Util.lit(ASPHALT, 0.5))

	for i in BLOCKS:
		for j in BLOCKS:
			var c := Vector3(-half + ROAD + BLOCK / 2 + i * cell, 0, -half + ROAD + BLOCK / 2 + j * cell)
			if i == 2 and j == 2:
				_lot(c)
				spawn = Transform3D(Basis.IDENTITY, c)
			else:
				_block(c)

	_streets(cell)
	_intersection_lights(cell)
	_skyline()
	_boundary()
	_city.commit(self, "City Lights")


func _process(dt: float) -> void:
	update_fade()
	_cull_timer -= dt
	if _cull_timer > 0.0 or target == null:
		return
	_cull_timer = 0.2
	var p := target.global_position
	for l in lights:
		var d := l.global_position - p
		d.y = 0.0
		l.visible = d.length_squared() < LIGHT_RADIUS * LIGHT_RADIUS


## Tell the building shader where the car is on screen, so it can cut an x-ray circle
## through anything between the camera and the car.
func update_fade() -> void:
	if camera == null or target == null:
		return
	var p := target.global_position + Vector3(0, 0.8, 0)
	var vp_size := camera.get_viewport().get_visible_rect().size
	var screen := camera.unproject_position(p) / vp_size
	var depth := -(camera.global_transform.affine_inverse() * p).z
	RenderingServer.global_shader_parameter_set("car_screen", screen)
	RenderingServer.global_shader_parameter_set("car_depth", depth)
	RenderingServer.global_shader_parameter_set("cut_radius", CUT_RADIUS)


func _shader_mat(key: String, albedo: Color, emission := Color.BLACK, energy := 0.0) -> ShaderMaterial:
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = BUILDING_SHADER
		m.set_shader_parameter("albedo", albedo)
		m.set_shader_parameter("grit", Util.grain())
		m.set_shader_parameter("emission_color", emission)
		m.set_shader_parameter("emission_energy", energy)
		_mats[key] = m
	return _mats[key]


func _wall_mat(c: Color) -> ShaderMaterial:
	return _shader_mat("wall%s" % c, c)


func _glow_mat(c: Color, energy: float) -> ShaderMaterial:
	return _shader_mat("glow%s%s" % [c, energy], c * 0.35, c, energy)


func _dark_mat() -> ShaderMaterial:
	return _shader_mat("dark", SIGN_DARK)


# ------------------------------------------------------------------ blocks

func _block(center: Vector3) -> void:
	var b := Node3D.new()
	add_child(b)
	b.position = center
	Util.static_box(b, Vector3(BLOCK, 3, BLOCK), Vector3(0, 1.5, 0))
	var batch := Batch.new()
	batch.box(Util.lit(SIDEWALK, 0.9), Vector3(BLOCK, 0.18, BLOCK), Vector3(0, 0.09, 0))

	# Split the block into lots: 2x2, 3x2 or 2x3, each a building.
	var inner := BLOCK - 3.0
	var nx := 2 + rng.randi() % 2
	var nz := 2 + (rng.randi() % 2 if nx == 2 else 0)
	var lw := inner / nx
	var ld := inner / nz
	for ix in nx:
		for iz in nz:
			var lot_c := Vector3(-inner / 2 + lw * (ix + 0.5), 0.18, -inner / 2 + ld * (iz + 0.5))
			var edge_x := ix == 0 or ix == nx - 1
			var edge_z := iz == 0 or iz == nz - 1
			_building(batch, center, lot_c, Vector2(lw - 0.6, ld - 0.6), Vector2i(
				(-1 if ix == 0 else (1 if ix == nx - 1 else 0)),
				(-1 if iz == 0 else (1 if iz == nz - 1 else 0))), edge_x or edge_z)

	# Vending machines and utility poles on the sidewalk.
	var e := BLOCK / 2 - 0.9
	for side in 4:
		var along := -BLOCK / 2 + 3.0
		while along < BLOCK / 2 - 3.0:
			var p := _side_point(side, e, along)
			if rng.randf() < 0.12:
				_vending(batch, center, p, side)
			along += rng.randf_range(4.0, 7.0)
	for side in 4:
		for k in [-1, 1]:
			_pole(batch, center, _side_point(side, BLOCK / 2 - 0.45, k * BLOCK * 0.28), side)

	batch.commit(b, "Block")


func _side_point(side: int, e: float, along: float) -> Vector3:
	match side:
		0: return Vector3(along, 0.18, e)
		1: return Vector3(along, 0.18, -e)
		2: return Vector3(e, 0.18, along)
		_: return Vector3(-e, 0.18, along)


func _side_yaw(side: int) -> float:
	match side:
		0: return 0.0
		1: return 180.0
		2: return 90.0
		_: return -90.0


## One building on a lot. `out` says which sides face a street (-1/1 per axis, 0 = interior).
func _building(batch, block_c: Vector3, c: Vector3, size: Vector2, out: Vector2i, street: bool) -> void:
	var heights := [6.4, 9.6, 9.6, 12.8, 16.0, 19.2, 25.6, 32.0]
	var h: float = heights[rng.randi() % heights.size()]
	var wall := _wall_mat(CONCRETE[rng.randi() % CONCRETE.size()])
	batch.box(wall, Vector3(size.x, h, size.y), c + Vector3(0, h / 2, 0))
	var rim := _wall_mat(Color(0.55, 0.55, 0.58))
	batch.box(rim, Vector3(size.x, 0.6, 0.3), c + Vector3(0, h + 0.3, size.y / 2 - 0.15))
	batch.box(rim, Vector3(size.x, 0.6, 0.3), c + Vector3(0, h + 0.3, -size.y / 2 + 0.15))
	batch.box(rim, Vector3(0.3, 0.6, size.y), c + Vector3(size.x / 2 - 0.15, h + 0.3, 0))
	batch.box(rim, Vector3(0.3, 0.6, size.y), c + Vector3(-size.x / 2 + 0.15, h + 0.3, 0))
	# Rooftop clutter: water tank / AC box.
	if rng.randf() < 0.6:
		batch.box(_wall_mat(Color(0.25, 0.25, 0.27)), Vector3(2.2, 1.4, 2.2), c + Vector3(rng.randf_range(-2, 2), h + 0.7, rng.randf_range(-2, 2)))

	var world_c := block_c + c
	var faces := []
	if out.x != 0:
		faces.append([Vector3(out.x, 0, 0), size.y])
	if out.y != 0:
		faces.append([Vector3(0, 0, out.y), size.x])
	for f in faces:
		var n: Vector3 = f[0]
		var width: float = f[1]
		var yaw := rad_to_deg(atan2(n.x, n.z))
		var face_off: float = (size.x if n.x != 0 else size.y) / 2 + 0.03
		var face_c := world_c + n * face_off
		# Shopfront: a bright band at street level.
		if rng.randf() < 0.75:
			var shop: Color = WINDOW_COLORS[rng.randi() % WINDOW_COLORS.size()]
			_city.box(_glow_mat(shop, 1.0), Vector3(width * 0.8, 2.2, 0.06), face_c + Vector3(0, 1.4, 0), yaw)
			_city.ground_quad(Util.glow(Color(shop.r, shop.g, shop.b, 0.12), true), Vector2(width * 0.9, 5.0),
				Vector3(face_c.x, 0.04, face_c.z) + n * 2.0, yaw)
		# Window rows on the floors above.
		var floors := int(h / FLOOR_H)
		for fl in range(1, floors):
			if rng.randf() < 0.55:
				var wc: Color = WINDOW_COLORS[rng.randi() % WINDOW_COLORS.size()]
				_city.box(_glow_mat(wc, 0.75), Vector3(width * rng.randf_range(0.5, 0.85), 1.1, 0.06),
					face_c + Vector3(0, fl * FLOOR_H + 1.5, 0), yaw)
		# Neon sign: a vertical panel sticking out from the corner, with dark "characters".
		if street and rng.randf() < 0.55 and h > 8.0:
			var col: Color = NEON[rng.randi() % NEON.size()]
			var side_dir := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(1, 0, 0)
			var sh := minf(rng.randf_range(4.0, 9.0), h - 3.0)
			var sp := face_c + side_dir * (width / 2 - 0.8) + n * 0.7 + Vector3(0, 3.0 + sh / 2, 0)
			_city.box(_glow_mat(col, 1.25), Vector3(0.25, sh, 1.2), sp, yaw)
			var glyphs := int(sh / 1.1)
			for g in glyphs:
				var gy := sp.y - sh / 2 + 0.6 + g * 1.1
				_city.box(_dark_mat(), Vector3(0.3, 0.55, 0.6), Vector3(sp.x, gy, sp.z), yaw)
			# Coloured light pool on the pavement below.
			_city.ground_quad(Util.glow(Color(col.r, col.g, col.b, 0.24), true), Vector2(10, 10),
				Vector3(sp.x, 0.04, sp.z) + n * 3.0)
		# Rooftop billboard along the street edge: reads great from above.
		if rng.randf() < 0.4 and h >= 9.6:
			var colr: Color = NEON[rng.randi() % NEON.size()]
			var bb := face_c - n * 0.6 + Vector3(0, h + 1.4, 0)
			_city.box(_glow_mat(colr, 1.25), Vector3(width * 0.7, 2.6, 0.25), bb, yaw)
			_city.box(_dark_mat(), Vector3(0.15, 2.8, 0.15), bb - n * 0.3 + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(width * 0.3, 0, 0), yaw)
			_city.box(_dark_mat(), Vector3(0.15, 2.8, 0.15), bb - n * 0.3 - Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(width * 0.3, 0, 0), yaw)
		# Horizontal sign above the shopfront.
		elif rng.randf() < 0.35:
			var col2: Color = NEON[rng.randi() % NEON.size()]
			_city.box(_glow_mat(col2, 1.2), Vector3(width * 0.6, 0.9, 0.12), face_c + Vector3(0, 3.0, 0) + n * 0.05, yaw)


func _vending(batch, block_c: Vector3, p: Vector3, side: int) -> void:
	var yaw := _side_yaw(side)
	var body: Color = [Color(0.75, 0.1, 0.1), Color(0.1, 0.3, 0.8), Color(0.9, 0.9, 0.92)][rng.randi() % 3]
	batch.box(_wall_mat(body), Vector3(1.0, 1.85, 0.75), p + Vector3(0, 0.92, 0), yaw)
	var n := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, 1)
	_city.box(_glow_mat(Color(0.9, 0.97, 1.0), 1.1), Vector3(0.8, 1.1, 0.05), block_c + p + Vector3(0, 1.15, 0) + n * 0.39, yaw)
	_city.ground_quad(Util.glow(Color(0.85, 0.95, 1.0, 0.18), true), Vector2(3.5, 3.5), block_c + Vector3(p.x, 0.04, p.z) + n * 1.6)


var _last_pole := {}  ## block side -> previous pole top, for wires


func _pole(batch, block_c: Vector3, p: Vector3, side: int) -> void:
	var concrete := _wall_mat(Color(0.5, 0.5, 0.5))
	batch.box(concrete, Vector3(0.28, 9.0, 0.28), p + Vector3(0, 4.5, 0))
	var yaw := _side_yaw(side) + 90.0
	batch.box(concrete, Vector3(1.6, 0.12, 0.12), p + Vector3(0, 8.4, 0), yaw)
	batch.box(_wall_mat(Color(0.35, 0.35, 0.37)), Vector3(0.5, 0.7, 0.5), p + Vector3(0, 7.6, 0))  # transformer
	# Wires to the previous pole on this side.
	var top := block_c + p + Vector3(0, 8.4, 0)
	var key := "%s%d" % [block_c, side]
	if _last_pole.has(key):
		var prev: Vector3 = _last_pole[key]
		var mid := (prev + top) / 2
		var length := prev.distance_to(top)
		var wyaw := rad_to_deg(atan2((top - prev).x, (top - prev).z))
		var wire := _dark_mat()
		for off in [-0.6, 0.0, 0.6]:
			var o := Basis(Vector3.UP, deg_to_rad(wyaw)) * Vector3(off, 0, 0)
			_city.box(wire, Vector3(0.04, 0.04, length), mid + o, wyaw)
			_city.box(wire, Vector3(0.04, 0.04, length), mid + o + Vector3(0, -0.5, 0), wyaw)
	_last_pole[key] = top


func _lot(center: Vector3) -> void:
	var lot := Node3D.new()
	add_child(lot)
	lot.position = center
	Util.box(lot, Vector3(BLOCK, 0.02, BLOCK), Vector3(0, 0.005, 0), Util.lit(LOT_ASPHALT, 0.5))
	var paint := Util.glow(Color(1, 1, 1, 0.5))
	var x := -BLOCK / 2 + 3
	while x <= BLOCK / 2 - 3:
		_city.ground_quad(paint, Vector2(0.15, 4.5), center + Vector3(x, 0.03, -BLOCK / 2 + 3.5))
		_city.ground_quad(paint, Vector2(0.15, 4.5), center + Vector3(x, 0.03, BLOCK / 2 - 3.5))
		x += 2.6
	var c := BLOCK / 2 - 1.5
	for corner in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		_lamp(center + Vector3(corner.x * c, 0, corner.y * c), Vector3(-corner.x, 0, -corner.y).normalized())


# ------------------------------------------------------------------ streets

func _streets(cell: float) -> void:
	var lane := Util.glow(Color(0.95, 0.95, 0.95, 0.5))
	var zebra := Util.glow(Color(1, 1, 1, 0.55))
	for k in BLOCKS + 1:
		var road := -half + ROAD / 2 + k * cell
		for i in BLOCKS:
			var start := -half + ROAD + i * cell
			var p := start + 5.5
			while p < start + BLOCK - 5.5:
				_city.ground_quad(lane, Vector2(2.5, 0.18), Vector3(p + 1.25, 0.02, road))
				_city.ground_quad(lane, Vector2(0.18, 2.5), Vector3(road, 0.02, p + 1.25))
				p += 5.0
		# Crosswalks on every side of every intersection.
		for m in BLOCKS + 1:
			var cross := -half + ROAD / 2 + m * cell
			for s in [-1.0, 1.0]:
				for t in range(-5, 6):
					var o := t * 1.0
					_city.ground_quad(zebra, Vector2(0.55, 2.6), Vector3(road + o, 0.025, cross + s * (ROAD / 2 + 1.6)))
					_city.ground_quad(zebra, Vector2(2.6, 0.55), Vector3(road + s * (ROAD / 2 + 1.6), 0.025, cross + o))


func _intersection_lights(cell: float) -> void:
	for i in BLOCKS + 1:
		for j in BLOCKS + 1:
			if (i + j) % 2 == 1:
				continue
			var c := Vector3(-half + ROAD / 2 + i * cell, 0, -half + ROAD / 2 + j * cell)
			_lamp(c + Vector3(ROAD / 2 + 0.6, 0.18, ROAD / 2 + 0.6), Vector3(-1, 0, -1).normalized())


func _lamp(base: Vector3, out: Vector3) -> void:
	var l := Node3D.new()
	add_child(l)
	l.position = base
	l.basis = Basis.looking_at(out, Vector3.UP)
	var pole := _wall_mat(Color(0.3, 0.31, 0.33))
	Util.box(l, Vector3(0.18, 6.5, 0.18), Vector3(0, 3.25, 0), pole)
	Util.box(l, Vector3(0.12, 0.12, 2.6), Vector3(0, 6.5, -1.3), pole)
	Util.box(l, Vector3(0.4, 0.14, 0.9), Vector3(0, 6.4, -2.6), Util.emissive(LED_WHITE, 4.0))
	var light := OmniLight3D.new()
	l.add_child(light)
	light.position = Vector3(0, 6.0, -2.6)
	light.omni_range = 20.0
	light.light_energy = 3.5
	light.light_color = LED_WHITE
	light.shadow_enabled = false
	lights.append(light)
	_city.ground_quad(Util.glow(Color(LED_WHITE.r, LED_WHITE.g, LED_WHITE.b, 0.2), true), Vector2(13, 13),
		base + l.basis * Vector3(0, 0, -2.6) + Vector3(0, 0.035 - base.y, 0))


# ------------------------------------------------------------------ edges

func _skyline() -> void:
	# Tall towers outside the playable area, mostly lost in the fog, for that city-at-night feel.
	var ring := half + 18.0
	var p := -ring
	while p <= ring:
		for side in 4:
			var h := rng.randf_range(25, 80)
			var w := rng.randf_range(10, 18)
			var pos: Vector3
			match side:
				0: pos = Vector3(p, h / 2, ring + rng.randf_range(0, 15))
				1: pos = Vector3(p, h / 2, -ring - rng.randf_range(0, 15))
				2: pos = Vector3(ring + rng.randf_range(0, 15), h / 2, p)
				_: pos = Vector3(-ring - rng.randf_range(0, 15), h / 2, p)
			_city.box(_wall_mat(Color(0.18, 0.19, 0.22)), Vector3(w, h, w), pos)
			var floors := int(h / FLOOR_H)
			var toward := -Vector3(signf(pos.x) if side >= 2 else 0.0, 0, signf(pos.z) if side < 2 else 0.0)
			var yaw := rad_to_deg(atan2(toward.x, toward.z))
			for fl in range(1, floors, 2):
				if rng.randf() < 0.4:
					_city.box(_glow_mat(WINDOW_COLORS[rng.randi() % 3], 0.8), Vector3(w * 0.8, 1.0, 0.06),
						pos + Vector3(0, -h / 2 + fl * FLOOR_H, 0) + toward * (w / 2 + 0.03), yaw)
		p += 16.0
	var outer := Util.lit(Color(0.1, 0.1, 0.12), 1.0)
	Util.box(self, Vector3(half * 2 + 160, 0.1, half * 2 + 160), Vector3(0, -0.2, 0), outer)


func _boundary() -> void:
	var len := half * 2 + 4
	Util.static_box(self, Vector3(len, 4, 2), Vector3(0, 2, half + 1))
	Util.static_box(self, Vector3(len, 4, 2), Vector3(0, 2, -half - 1))
	Util.static_box(self, Vector3(2, 4, len), Vector3(half + 1, 2, 0))
	Util.static_box(self, Vector3(2, 4, len), Vector3(-half - 1, 2, 0))
