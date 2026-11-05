extends Node3D
## A low-poly nighttime suburb: a grid of blocks with houses and trees, streets between them,
## white LED street lights, and an open practice lot. Blocks are solid (curb walls), so the
## streets are your track. Only street lights near the car are switched on, since phones can
## only handle a few real lights at once; the glowing pools on the road stay on everywhere.

const Util := preload("res://scripts/util.gd")

const BLOCKS := 4
const BLOCK := 46.0
const ROAD := 16.0
const LIGHT_RADIUS := 48.0

const LED_WHITE := Color(0.86, 0.92, 1.0)
const ASPHALT := Color(0.16, 0.165, 0.19)
const LOT_ASPHALT := Color(0.19, 0.195, 0.22)
const SIDEWALK := Color(0.4, 0.4, 0.43)
const LAWN := Color(0.12, 0.22, 0.13)
const OUTER_GRASS := Color(0.08, 0.14, 0.09)
const ROOF := Color(0.2, 0.18, 0.2)
const TRUNK := Color(0.22, 0.15, 0.10)
const POLE := Color(0.25, 0.26, 0.28)
const WINDOW_WARM := Color(1.0, 0.76, 0.42)
const GLASS := Color(0.05, 0.07, 0.11)
const DOOR := Color(0.20, 0.12, 0.08)
const LANE := Color(0.9, 0.75, 0.3, 0.55)
const LINE := Color(1, 1, 1, 0.5)
const HOUSE_COLORS := [
	Color(0.62, 0.68, 0.74), Color(0.74, 0.68, 0.56), Color(0.56, 0.64, 0.54),
	Color(0.58, 0.58, 0.60), Color(0.80, 0.77, 0.68), Color(0.62, 0.48, 0.44),
]
const LEAF_COLORS := [Color(0.08, 0.16, 0.13), Color(0.1, 0.19, 0.14), Color(0.07, 0.13, 0.12)]

var rng := RandomNumberGenerator.new()
var lights: Array[OmniLight3D] = []
var spawn := Transform3D.IDENTITY
var target: Node3D  ## the car, for light culling
var half := 0.0
var _cull_timer := 0.0


func build(seed_value := 86) -> void:
	rng.seed = seed_value
	var cell := BLOCK + ROAD
	var total := BLOCKS * cell + ROAD
	half = total / 2.0

	# Ground in tiles, so each piece only picks up the street lights near it.
	var tiles := 8
	var tile := total / tiles
	for i in tiles:
		for j in tiles:
			var c := Vector3(-half + tile * (i + 0.5), -0.05, -half + tile * (j + 0.5))
			Util.box(self, Vector3(tile, 0.1, tile), c, Util.lit(ASPHALT, 0.6))
	var outer := Util.lit(OUTER_GRASS, 1.0)
	var w := 200.0
	Util.box(self, Vector3(total + 2 * w, 0.1, w), Vector3(0, -0.15, -half - w / 2), outer)
	Util.box(self, Vector3(total + 2 * w, 0.1, w), Vector3(0, -0.15, half + w / 2), outer)
	Util.box(self, Vector3(w, 0.1, total), Vector3(-half - w / 2, -0.15, 0), outer)
	Util.box(self, Vector3(w, 0.1, total), Vector3(half + w / 2, -0.15, 0), outer)

	for i in BLOCKS:
		for j in BLOCKS:
			var c := Vector3(-half + ROAD + BLOCK / 2 + i * cell, 0, -half + ROAD + BLOCK / 2 + j * cell)
			if i == 1 and j == 2:
				_lot(c)
				spawn = Transform3D(Basis.IDENTITY, c)
			else:
				_block(c)

	_lane_dashes(cell)
	_boundary()


func _process(dt: float) -> void:
	_cull_timer -= dt
	if _cull_timer > 0.0 or target == null:
		return
	_cull_timer = 0.2
	var p := target.global_position
	for l in lights:
		var d := l.global_position - p
		d.y = 0.0
		l.visible = d.length_squared() < LIGHT_RADIUS * LIGHT_RADIUS


# ------------------------------------------------------------------ blocks

func _block(center: Vector3) -> void:
	var b := Node3D.new()
	add_child(b)
	b.position = center
	Util.static_box(b, Vector3(BLOCK, 3, BLOCK), Vector3(0, 1.5, 0))  # the curb you bounce off

	Util.box(b, Vector3(BLOCK, 0.2, BLOCK), Vector3(0, 0.1, 0), Util.lit(SIDEWALK, 0.9))
	Util.box(b, Vector3(BLOCK - 5, 0.22, BLOCK - 5), Vector3(0, 0.11, 0), Util.lit(LAWN, 1.0))

	var top := 0.22
	var hx := BLOCK / 4
	var hz := BLOCK / 2 - 12
	_house(b, Vector3(-hx, top, -hz), 180)
	_house(b, Vector3(hx, top, -hz), 180)
	_house(b, Vector3(-hx, top, hz), 0)
	_house(b, Vector3(hx, top, hz), 0)

	var sx := BLOCK / 2 - 5
	for side in [-1.0, 1.0]:
		for k in [-1, 0, 1]:
			if rng.randf() < 0.7:
				_tree(b, Vector3(side * sx + rng.randf_range(-1, 1), top, k * 7 + rng.randf_range(-1.5, 1.5)))
	for k in 2:
		if rng.randf() < 0.6:
			_tree(b, Vector3(rng.randf_range(-12, 12), top, rng.randf_range(-2, 2)))

	var e := BLOCK / 2 - 1.2
	_lamp(b, Vector3(0, 0.2, -e), Vector3.FORWARD)
	_lamp(b, Vector3(0, 0.2, e), Vector3.BACK)
	if rng.randf() < 0.35:
		_lamp(b, Vector3(e, 0.2, 0), Vector3.RIGHT)
	if rng.randf() < 0.35:
		_lamp(b, Vector3(-e, 0.2, 0), Vector3.LEFT)


func _lot(center: Vector3) -> void:
	var lot := Node3D.new()
	add_child(lot)
	lot.position = center
	Util.box(lot, Vector3(BLOCK, 0.02, BLOCK), Vector3(0, 0.005, 0), Util.lit(LOT_ASPHALT, 0.5))

	var paint := Util.glow(LINE)
	var x := -BLOCK / 2 + 4
	while x <= BLOCK / 2 - 4:
		Util.decal(lot, Vector2(0.15, 5), Vector3(x, 0.03, -BLOCK / 2 + 4), paint)
		x += 3.0

	var c := BLOCK / 2 - 2
	for corner in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(1, 0), Vector2(-1, 0)]:
		var out := Vector3(-corner.x, 0, -corner.y).normalized()
		_lamp(lot, Vector3(corner.x * c, 0, corner.y * c), out)


# ------------------------------------------------------------------ props

func _house(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var h := Node3D.new()
	parent.add_child(h)
	h.position = pos
	h.rotation_degrees.y = yaw

	var w := rng.randf_range(9.5, 12.0)
	var d := rng.randf_range(8.0, 9.5)
	var ht := rng.randf_range(3.0, 3.8)
	var body: Color = HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()]
	Util.box(h, Vector3(w, ht, d), Vector3(0, ht / 2, 0), Util.lit(body, 0.95))
	Util.roof(h, Vector3(0, ht, 0), Vector3(d + 1, rng.randf_range(2.0, 2.6), w + 1), Util.lit(ROOF, 0.9), 90)

	# Front of the house faces local +Z (toward the street).
	var fz := d / 2 + 0.02
	Util.panel(h, Vector2(1.6, 1.2), Vector3(-w * 0.3, ht * 0.55, fz), _window())
	Util.panel(h, Vector2(1.6, 1.2), Vector3(w * 0.3, ht * 0.55, fz), _window())
	Util.panel(h, Vector2(1.0, 2.1), Vector3(w * 0.05, 1.05, fz), Util.lit(DOOR, 0.7))
	Util.box(h, Vector3(0.18, 0.25, 0.12), Vector3(w * 0.05 + 0.85, 2.2, fz + 0.05), Util.emissive(WINDOW_WARM, 2.5))
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	Util.panel(h, Vector2(1.4, 1.1), Vector3(side * (w / 2 + 0.02), ht * 0.55, 0), _window(), 90)


func _window() -> Material:
	return Util.emissive(WINDOW_WARM, 1.6) if rng.randf() < 0.6 else Util.lit(GLASS, 0.1)


func _tree(parent: Node3D, pos: Vector3) -> void:
	var t := Node3D.new()
	parent.add_child(t)
	t.position = pos
	t.scale = Vector3.ONE * rng.randf_range(0.8, 1.25)
	# Low-poly pine: stacked six-sided cones.
	Util.box(t, Vector3(0.35, 1.2, 0.35), Vector3(0, 0.6, 0), Util.lit(TRUNK, 1.0))
	var leaf := Util.lit(LEAF_COLORS[rng.randi() % LEAF_COLORS.size()], 1.0)
	var yaw := rng.randf_range(0, 60)
	Util.cone(t, 1.9, 2.6, Vector3(0, 0.8, 0), leaf, yaw)
	Util.cone(t, 1.45, 2.3, Vector3(0, 2.2, 0), leaf, yaw + 20)
	Util.cone(t, 1.0, 2.3, Vector3(0, 3.5, 0), leaf, yaw + 40)


## A street light whose arm reaches out over the road in direction `out`.
func _lamp(parent: Node3D, base: Vector3, out: Vector3, arm := 2.4) -> void:
	var l := Node3D.new()
	parent.add_child(l)
	l.position = base
	l.basis = Basis.looking_at(out, Vector3.UP)  # local -Z now points out over the road

	var pole := Util.lit(POLE, 0.4)
	Util.box(l, Vector3(0.2, 6, 0.2), Vector3(0, 3, 0), pole)
	Util.box(l, Vector3(0.14, 0.14, arm), Vector3(0, 6, -arm / 2), pole)
	Util.box(l, Vector3(0.45, 0.16, 0.95), Vector3(0, 5.9, -arm), Util.emissive(LED_WHITE, 4.0))

	var light := OmniLight3D.new()
	l.add_child(light)
	light.position = Vector3(0, 5.6, -arm)
	light.omni_range = 22.0
	light.light_energy = 4.0
	light.light_color = LED_WHITE
	light.shadow_enabled = false
	lights.append(light)

	# Fake light pool on the road: cheap, always visible, looks great pixelated.
	var pool := Color(LED_WHITE.r, LED_WHITE.g, LED_WHITE.b, 0.22)
	Util.decal(l, Vector2(14, 14), Vector3(0, 0.03 - base.y, -arm), Util.glow(pool, true))


# ------------------------------------------------------------------ roads & edges

func _lane_dashes(cell: float) -> void:
	var paint := Util.glow(LANE)
	for k in BLOCKS + 1:
		var road := -half + ROAD / 2 + k * cell
		for i in BLOCKS:
			var start := -half + ROAD + i * cell
			var p := start + 3.0
			while p < start + BLOCK - 3.0:
				Util.decal(self, Vector2(3, 0.25), Vector3(p + 1.5, 0.02, road), paint)
				Util.decal(self, Vector2(0.25, 3), Vector3(road, 0.02, p + 1.5), paint)
				p += 7.0


func _boundary() -> void:
	var len := half * 2 + 4
	Util.static_box(self, Vector3(len, 4, 2), Vector3(0, 2, half + 1))
	Util.static_box(self, Vector3(len, 4, 2), Vector3(0, 2, -half - 1))
	Util.static_box(self, Vector3(2, 4, len), Vector3(half + 1, 2, 0))
	Util.static_box(self, Vector3(2, 4, len), Vector3(-half - 1, 2, 0))

	var p := -half - 10.0
	while p <= half + 10.0:
		_tree(self, Vector3(p + rng.randf_range(-2, 2), 0, half + rng.randf_range(4, 14)))
		_tree(self, Vector3(p + rng.randf_range(-2, 2), 0, -half - rng.randf_range(4, 14)))
		_tree(self, Vector3(half + rng.randf_range(4, 14), 0, p + rng.randf_range(-2, 2)))
		_tree(self, Vector3(-half - rng.randf_range(4, 14), 0, p + rng.randf_range(-2, 2)))
		p += 6.0
