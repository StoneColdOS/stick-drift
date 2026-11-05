extends RefCounted
## Shared helpers: cached materials and low-poly building blocks.

static var _mats := {}
static var _unit_box: BoxMesh
static var _unit_plane: PlaneMesh
static var _prism: ArrayMesh
static var _soft: GradientTexture2D
static var _grain: ImageTexture


## Everything gets a gritty, blotchy texture projected in world space (no UVs needed), drawn
## with nearest-neighbour filtering so it reads as chunky pixels. That's most of the
## "photo texture on low-poly" retro look.
static func lit(c: Color, roughness := 0.85, grain_scale := 0.3) -> StandardMaterial3D:
	var key := "L%s%s%s" % [c, roughness, grain_scale]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = roughness
		if grain_scale > 0.0:
			m.albedo_texture = grain()
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3.ONE * grain_scale
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # nearest shimmered in motion
		_mats[key] = m
	return _mats[key]


## 64x64 tileable grit: two octaves of value noise plus speckle, 0.72..1.0 brightness.
static func grain() -> ImageTexture:
	if _grain:
		return _grain
	const N := 64
	var rng := RandomNumberGenerator.new()
	rng.seed = 1986
	var coarse: Array[float] = []
	var fine: Array[float] = []
	for i in 8 * 8:
		coarse.append(rng.randf())
	for i in 16 * 16:
		fine.append(rng.randf())
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			var v := 0.55 * _vnoise(coarse, 8, x / float(N) * 8.0, y / float(N) * 8.0)
			v += 0.30 * _vnoise(fine, 16, x / float(N) * 16.0, y / float(N) * 16.0)
			v += 0.15 * rng.randf()
			var b := lerpf(0.72, 1.0, v)
			img.set_pixel(x, y, Color(b, b, b))
	img.generate_mipmaps()
	_grain = ImageTexture.create_from_image(img)
	return _grain


static func _vnoise(cells: Array[float], n: int, fx: float, fy: float) -> float:
	var x0 := int(floor(fx)) % n
	var y0 := int(floor(fy)) % n
	var x1 := (x0 + 1) % n
	var y1 := (y0 + 1) % n
	var tx := smoothstep(0.0, 1.0, fx - floor(fx))
	var ty := smoothstep(0.0, 1.0, fy - floor(fy))
	var a := lerpf(cells[y0 * n + x0], cells[y0 * n + x1], tx)
	var b := lerpf(cells[y1 * n + x0], cells[y1 * n + x1], tx)
	return lerpf(a, b, ty)


static func emissive(c: Color, energy: float) -> StandardMaterial3D:
	var key := "E%s%s" % [c, energy]
	if not _mats.has(key):
		_mats[key] = emissive_instance(c, energy)
	return _mats[key]


## Uncached, for things that change brightness at runtime (brake lights).
static func emissive_instance(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c * 0.5
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


## Unlit and see-through: light pools, road paint, skid marks.
static func glow(c: Color, soft := false) -> StandardMaterial3D:
	var key := "G%s%s" % [c, soft]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = c
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if soft:
			m.albedo_texture = soft_circle()
		_mats[key] = m
	return _mats[key]


## Radial white-to-clear gradient.
static func soft_circle() -> GradientTexture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.5, Color(1, 1, 1, 0.3))
		_soft = GradientTexture2D.new()
		_soft.gradient = g
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		_soft.width = 64
		_soft.height = 64
	return _soft


static func box(parent: Node, size: Vector3, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	if _unit_box == null:
		_unit_box = BoxMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _unit_box
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = size
	return mi


## Flat rectangle lying on the ground. size.x along X, size.y along Z (before yaw).
static func decal(parent: Node, size: Vector2, pos: Vector3, mat: Material, yaw_deg := 0.0) -> MeshInstance3D:
	if _unit_plane == null:
		_unit_plane = PlaneMesh.new()
		_unit_plane.size = Vector2.ONE
	var mi := MeshInstance3D.new()
	mi.mesh = _unit_plane
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = pos
	mi.rotation_degrees = Vector3(0, yaw_deg, 0)
	mi.scale = Vector3(size.x, 1, size.y)
	return mi


## A vertical rectangle facing +Z (windows, doors).
static func panel(parent: Node, size: Vector2, pos: Vector3, mat: Material, yaw_deg := 0.0) -> MeshInstance3D:
	var mi := box(parent, Vector3(size.x, size.y, 0.04), pos, mat, Vector3(0, yaw_deg, 0))
	return mi


## Flat-shaded triangular prism (a roof). Cross-section in XY, base width 1, height 1,
## base on y = 0, extruded 1 unit along Z, centered on X and Z.
static func prism() -> ArrayMesh:
	if _prism:
		return _prism
	var a0 := Vector3(-0.5, 0, -0.5)
	var b0 := Vector3(0.5, 0, -0.5)
	var c0 := Vector3(0, 1, -0.5)
	var a1 := Vector3(-0.5, 0, 0.5)
	var b1 := Vector3(0.5, 0, 0.5)
	var c1 := Vector3(0, 1, 0.5)
	var center := Vector3(0, 0.33, 0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in [[a0, b0, c0], [a1, c1, b1], [a0, c1, a1], [a0, c0, c1], [b0, b1, c1], [b0, c1, c0]]:
		var p: Vector3 = tri[0]
		var q: Vector3 = tri[1]
		var r: Vector3 = tri[2]
		var n := (q - p).cross(r - p).normalized()
		if n.dot((p + q + r) / 3.0 - center) < 0:
			var tmp := q
			q = r
			r = tmp
			n = -n
		# Godot treats clockwise (seen from the front) as front-facing.
		st.set_normal(n)
		st.add_vertex(p)
		st.add_vertex(r)
		st.add_vertex(q)
	_prism = st.commit()
	return _prism


static func roof(parent: Node, pos: Vector3, size: Vector3, mat: Material, yaw_deg := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = prism()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = pos
	mi.rotation_degrees = Vector3(0, yaw_deg, 0)
	mi.scale = size
	return mi


## Low-poly cone (pine tree tiers, snow caps). Pointy end up, base on y = 0.
static func cone(parent: Node, radius: float, height: float, pos: Vector3, mat: Material, yaw_deg := 0.0) -> MeshInstance3D:
	var key := "cone"
	if not _mats.has(key):
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 1.0
		c.height = 1.0
		c.radial_segments = 6
		c.rings = 1
		_mats[key] = c
	var mi := MeshInstance3D.new()
	mi.mesh = _mats[key]
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = pos + Vector3(0, height / 2, 0)
	mi.rotation_degrees = Vector3(0, yaw_deg, 0)
	mi.scale = Vector3(radius, height, radius)
	return mi


static func static_box(parent: Node, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	body.add_child(shape)
	parent.add_child(body)
	body.position = pos
	return body
