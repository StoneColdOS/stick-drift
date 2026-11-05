extends RefCounted
## Collects lots of boxes and flat quads and merges them into one mesh per material, so a city
## full of windows and signs is a handful of draw calls instead of thousands (phones care).

var _verts := {}    ## material -> PackedVector3Array
var _normals := {}  ## material -> PackedVector3Array

const _FACES := [
	# normal, then four corners (unit cube, -0.5..0.5), wound so Godot sees them front-facing
	[Vector3(0, 0, 1), [Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]],
	[Vector3(0, 0, -1), [Vector3(1, -1, -1), Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(1, 1, -1)]],
	[Vector3(1, 0, 0), [Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1)]],
	[Vector3(-1, 0, 0), [Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(-1, 1, -1)]],
	[Vector3(0, 1, 0), [Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(-1, 1, -1)]],
	[Vector3(0, -1, 0), [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1)]],
]


func _arrays(mat: Material) -> void:
	if not _verts.has(mat):
		_verts[mat] = PackedVector3Array()
		_normals[mat] = PackedVector3Array()


## A box of `size` centred at `pos`, turned `yaw_deg` around Y.
func box(mat: Material, size: Vector3, pos: Vector3, yaw_deg := 0.0) -> void:
	_arrays(mat)
	var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var half := size * 0.5
	var v: PackedVector3Array = _verts[mat]
	var n: PackedVector3Array = _normals[mat]
	for f in _FACES:
		var normal: Vector3 = basis * f[0]
		var c: Array = f[1]
		var p := []
		for k in 4:
			p.append(pos + basis * (c[k] * half))
		# Two triangles, clockwise when seen from outside.
		for idx in [0, 2, 1, 0, 3, 2]:
			v.append(p[idx])
			n.append(normal)
	_verts[mat] = v
	_normals[mat] = n


## A flat quad lying on the ground (decals: crosswalks, light pools).
func ground_quad(mat: Material, size: Vector2, pos: Vector3, yaw_deg := 0.0) -> void:
	_arrays(mat)
	var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var p := [pos + basis * Vector3(-hx, 0, -hz), pos + basis * Vector3(hx, 0, -hz),
		pos + basis * Vector3(hx, 0, hz), pos + basis * Vector3(-hx, 0, hz)]
	var v: PackedVector3Array = _verts[mat]
	var n: PackedVector3Array = _normals[mat]
	for idx in [0, 1, 2, 0, 2, 3]:
		v.append(p[idx])
		n.append(Vector3.UP)
	_verts[mat] = v
	_normals[mat] = n


## Builds one MeshInstance3D per material under `parent`.
func commit(parent: Node, name := "Batch") -> void:
	for mat in _verts:
		var v: PackedVector3Array = _verts[mat]
		if v.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = _normals[mat]
		# UVs from world position so the (non-triplanar) glow textures still map sensibly.
		var uv := PackedVector2Array()
		uv.resize(v.size())
		for i in v.size():
			uv[i] = Vector2(v[i].x, v[i].z)
		arrays[Mesh.ARRAY_TEX_UV] = uv
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.name = name
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
	_verts.clear()
	_normals.clear()
