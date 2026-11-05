extends RefCounted
## Shared helpers: cached materials and low-poly building blocks.

static var _mats := {}
static var _unit_box: BoxMesh
static var _unit_plane: PlaneMesh
static var _prism: ArrayMesh
static var _soft: GradientTexture2D


static func lit(c: Color, roughness := 0.85) -> StandardMaterial3D:
	var key := "L%s%s" % [c, roughness]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = roughness
		_mats[key] = m
	return _mats[key]


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
