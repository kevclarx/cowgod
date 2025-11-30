@tool
extends MeshInstance3D

@export var map: Node3D

func update_ground_mesh(N, elev):
	# Generate ground mesh with its (0,0) corner at world XZ = (0,0)
	# (previous version centered the mesh around the origin)
	# Build non-indexed arrays so vertices are never shared between triangles (guarantees flat facets)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols  := PackedColorArray()

	for x in range(N - 1):
		for y in range(N - 1):
			var x2 = x + 1
			var y2 = y + 1

			# World-space base positions with origin at (0,0)
			var base_x = x * Constants.T
			var base_x2 = x2 * Constants.T
			var base_z = y * Constants.T
			var base_z2 = y2 * Constants.T

			# Heights (Y) for the four corners
			var h00 = elev[x][y] * Constants.T
			var h01 = elev[x][y2] * Constants.T
			var h10 = elev[x2][y] * Constants.T
			var h11 = elev[x2][y2] * Constants.T

			# Quad corners in Godot: Vector3(x, y, z) with y = elevation
			var p0 = Vector3(base_x,  h00, base_z)   # (x, y)
			var p1 = Vector3(base_x,  h01, base_z2)  # (x, y+1)
			var p2 = Vector3(base_x2, h11, base_z2)  # (x+1, y+1)
			var p3 = Vector3(base_x2, h10, base_z)   # (x+1, y)

			# Use a single uniform color for the entire tile so each triangle renders flat (no color interpolation between tiles)
			var tile_col = map.get_color_at(x, y)

			# Triangle A (p0, p3, p2) - duplicate vertices, compute per-triangle normal
			var a = p0; var b = p3; var c = p2
			var n = (b - a).cross(c - a).normalized()
			if n.y < 0.0:
				n = -n
			verts.append(a); verts.append(b); verts.append(c)
			norms.append(n); norms.append(n); norms.append(n)
			cols.append(tile_col); cols.append(tile_col); cols.append(tile_col)

			# Triangle B (p0, p2, p1)
			a = p0; b = p2; c = p1
			n = (b - a).cross(c - a).normalized()
			if n.y < 0.0:
				n = -n
			verts.append(a); verts.append(b); verts.append(c)
			norms.append(n); norms.append(n); norms.append(n)
			cols.append(tile_col); cols.append(tile_col); cols.append(tile_col)

	# Build ArrayMesh from non-indexed arrays (no shared vertices)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols

	# assign mesh
	mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# remove children and recreate collision if needed
	for n in get_children():
		n.queue_free()
	create_trimesh_collision()
