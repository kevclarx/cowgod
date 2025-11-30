@tool
extends MeshInstance3D

@export var map: Node3D

func update_water_mesh(N):
	# Build water grid with (0,0) corner at world XZ = (0,0)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# small upward offset to reduce z-fighting with the ground
	var WATER_EPS := 0.10 * Constants.T
	var water_col := Color(0.0, 0.45, 0.8, 0.6)

	# iterate only to N-1
	for x in range(N - 1):
		for y in range(N - 1):
			var x2 = x + 1
			var y2 = y + 1

			# world-space bases with origin at (0,0)
			var base_x = x * Constants.T
			var base_x2 = x2 * Constants.T
			var base_z = y * Constants.T
			var base_z2 = y2 * Constants.T

			# sample water level and lift slightly to avoid z-fighting
			var p00 = Vector3(base_x,  map.get_water_level(base_x, base_z) + WATER_EPS, base_z)
			var p01 = Vector3(base_x,  map.get_water_level(base_x, base_z2) + WATER_EPS, base_z2)
			var p10 = Vector3(base_x2, map.get_water_level(base_x2, base_z) + WATER_EPS, base_z)
			var p11 = Vector3(base_x2, map.get_water_level(base_x2, base_z2) + WATER_EPS, base_z2)

			# Triangle A -> ensure normal points up
			var a = p00; var b = p10; var c = p11
			var n = (b - a).cross(c - a)
			if n.y < 0.0:
				var tmp = b; b = c; c = tmp
				n = (b - a).cross(c - a)
			n = n.normalized()
			st.set_normal(n); st.set_color(water_col); st.add_vertex(a)
			st.set_normal(n); st.set_color(water_col); st.add_vertex(b)
			st.set_normal(n); st.set_color(water_col); st.add_vertex(c)

			# Triangle B -> ensure normal points up
			a = p00; b = p11; c = p01
			n = (b - a).cross(c - a)
			if n.y < 0.0:
				var tmp2 = b; b = c; c = tmp2
				n = (b - a).cross(c - a)
			n = n.normalized()
			st.set_normal(n); st.set_color(water_col); st.add_vertex(a)
			st.set_normal(n); st.set_color(water_col); st.add_vertex(b)
			st.set_normal(n); st.set_color(water_col); st.add_vertex(c)

	mesh = st.commit()
