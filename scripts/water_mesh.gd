@tool
extends MeshInstance3D

@export var map: Node3D

func update_water_mesh(N):

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half = (N - 1) * Constants.T / 2.0

	# small upward offset to reduce z-fighting with the ground (increase if needed)
	var WATER_EPS := 0.10 * Constants.T
	# define water color once (in scope for material assignment)
	var water_col := Color(0.0, 0.45, 0.8, 0.6)

	# iterate only to N-1 to avoid wrapping/connecting last to first (which can create stretched planes)
	for x in range(N - 1):
		for y in range(N - 1):
			var x2 = x + 1
			var y2 = y + 1

			# world-space bases
			var base_x = half - x * Constants.T
			var base_x2 = half - x2 * Constants.T
			var base_z = half - y * Constants.T
			var base_z2 = half - y2 * Constants.T

			# sample water level and lift slightly to avoid z-fighting
			var p00 = Vector3(base_x,  map.get_water_level(base_x, base_z) + WATER_EPS, base_z)
			var p01 = Vector3(base_x,  map.get_water_level(base_x, base_z2) + WATER_EPS, base_z2)
			var p10 = Vector3(base_x2, map.get_water_level(base_x2, base_z) + WATER_EPS, base_z)
			var p11 = Vector3(base_x2, map.get_water_level(base_x2, base_z2) + WATER_EPS, base_z2)

			var wn1 = (p11 - p00).cross(p10 - p00).normalized()
			if wn1.dot(Vector3.UP) < 0:
				wn1 = -wn1
			st.set_normal(wn1)
			st.set_color(water_col); st.add_vertex(p00)
			st.set_normal(wn1)
			st.set_color(water_col); st.add_vertex(p11)
			st.set_normal(wn1)
			st.set_color(water_col); st.add_vertex(p10)

			var wn2 = (p01 - p00).cross(p11 - p00).normalized()
			if wn2.dot(Vector3.UP) < 0:
				wn2 = -wn2
			st.set_normal(wn2)
			st.set_color(water_col); st.add_vertex(p00)
			st.set_normal(wn2)
			st.set_color(water_col); st.add_vertex(p01)
			st.set_normal(wn2)
			st.set_color(water_col); st.add_vertex(p11)

	mesh = st.commit()
	
