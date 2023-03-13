class_name Voronoi extends Object

const FLOAT_EPSILON = 0.00001


static func generate_voronoi_diagram(points):
	return generate_delaunay_triangulation(points)


# Uses Sweep Hull
static func generate_delaunay_triangulation(points):
	var original_points_length = len(points)
#	print('original points: ' + str(points))
	
	points = points.duplicate(true)
	
	# Get Seed Point
	var seed_point = points.pop_at(0)
	
	# Get Point Closest to Seed
	var distance_to_seed = func(point):
		return (point - seed_point).length_squared()
	points.sort_custom(func(a, b):
		return distance_to_seed.call(a) < distance_to_seed.call(b))
	var closest_point = points.pop_at(0)
	
	# Get Point that Makes the Smallest Circumcircle
	points.sort_custom(func(a, b):
		return calc_circumcircle_radius(a, closest_point, seed_point) \
			< calc_circumcircle_radius(b, closest_point, seed_point))
	var min_cc_point = points.pop_at(0)
	
	# Get the Circumcenter of the Smallest Circumcircle
	var circumcenter = calc_circumcenter(
		min_cc_point, closest_point, seed_point)
	
	# Initial Convex Hull
	var hull = get_counter_clockwise_triangle(
		min_cc_point, closest_point, seed_point)
	
	# Sort Points by Distance from the Smallest Circumcircle's Circumcenter
	var distance_to_circumcenter = func(point):
		return (point - circumcenter).length_squared()
	points.sort_custom(func(a, b):
		return distance_to_circumcenter.call(a) \
			< distance_to_circumcenter.call(b))
	
	# first triangle is initial hull (contains 3 points)
	var triangles = hull.duplicate(true)
	
	# Use Sorted Points to Grow Hull and Add Triangles
	for point_to_add in points:
		# points on the hull visible to the point to add
		var visible_points = grow_convex_hull(hull, point_to_add)
		
		# use visible points to add a triangle fan
		for i in range(len(visible_points) - 1):
			var cur = visible_points[i]
			var next = visible_points[i+1]
			
			# works for both CW and CCW order
			triangles.append(point_to_add)
			triangles.append(next)
			triangles.append(cur)
	
	triangles = convert_to_indexed_triangles(triangles)
	assert(len(triangles.vertices) == original_points_length,
		'Conversion to Indexed Format Failed.')
	print('vertices: ' + str(triangles.vertices))
	print('triangles: ' + str(triangles.indices))
	
	var edges = get_edges(triangles)
	print('edges: ' + str(edges) + '\n')
	flip_edges(triangles, edges)
	print('flipped triangles: ' + str(triangles.indices))
	
	return triangles

"""
Represents an edge between two points.
An edge can be a part of a single triangle or
can be shared between two triangles.
Stores the index of each triangle.
Stores which side (0, 1, or 2) the edge is on for each triangle.
"""
class Edge:
	var triangle_1_index: int
	var triangle_2_index: int
	var side_1: int
	var side_2: int
	
	func _init(triangle_1_index_: int, side_1_: int, triangle_2_index_: int, side_2_: int):
		triangle_1_index = triangle_1_index_
		side_1 = side_1_
		triangle_2_index = triangle_2_index_
		side_2 = side_2_
	
	"""
	Returns true if the edge is shared between adjacent triangles.
	"""
	func is_shared():
		return triangle_2_index != -1
	
	func get_triangle_1(arr: Array):
		return _get_triangle(arr, triangle_1_index)
	
	func get_triangle_2(arr: Array):
		return _get_triangle(arr, triangle_2_index)
	
	"""
	Returns a 3-length array of elements belonging to each vertex of a triangle.
	arr: An array of elements. Each 3-length block belongs to a triangle.
		For example, could be an array of indices or Vector2 positions.
	triangle_index: The index of the triangle's first vertex divided by 3.
	"""
	func _get_triangle(arr: Array, triangle_index: int):
		assert(len(arr) % 3 == 0, 'length of arr is not a multiple of 3.')
		assert(triangle_index < len(arr) / 3 and triangle_index >= 0,
			'triangle_index is out of bounds.')

		var s = triangle_index * 3
		return arr.slice(s, s+3)


"""
Returns a dictionary containing the edges of all of the triangles.
Each edge is stored as an Edge object that is
shared between adjacent triangles.
The key is an array containing the indexes of the two vertices of the edge.
The order of the indexes in the key is arbitrary.
triangles: the triangles (in indexed format) to retrieve edges from.
"""
static func get_edges(triangles):
	var edges = {}
	
	"""
	Adds an edge if it's not in edges,
	otherwise updates it with info on the second triangle.
	a and b: indexes of the vertices in the edge.
	side: side of the triangle the edge is on. (0, 1, or 2)
	triangle_index: index of the triangle's first vertex divided by 3.
	"""
	var add_or_update_edge = func(a, b, side, triangle_index):
		assert(not edges.has([a, b]),
			'Adjacent edge is entered with a reversed key.')
		
		# adjacent triangles are always in reverse order
		var adjacent_triangle_exists = edges.has([b, a])
		
		if not adjacent_triangle_exists:
			# create edge with info on first triangle
			edges[[a, b]] = Edge.new(triangle_index, side, -1, -1)
		else:
			# update edge with info on second triangle
			var edge = edges[[b, a]]
			edge.triangle_2_index = triangle_index
			edge.side_2 = side
	
	# process every edge once for every triangle
	for i in range(0, len(triangles.indices), 3):
		var a = triangles.indices[i]
		var b = triangles.indices[i+1]
		var c = triangles.indices[i+2]
		
		var triangle_index = i / 3
		add_or_update_edge.call(a, b, 0, triangle_index)
		add_or_update_edge.call(b, c, 1, triangle_index)
		add_or_update_edge.call(c, a, 2, triangle_index)
	
	return edges


"""
This function flips all of the edges in a 2D geometry
so that it is a valid delanauy triangulation.
triangles: 2D geometry (in indexed format) to flip.
edges: dictionary of edges for the 2D geometry.
"""
static func flip_edges(triangles, edges):
	"""
	Returns a geometry with 4 points (in indexed format)
	made from the 2 adjacent triangles of an edge.
	edge: An edge shared by 2 adjacent triangles.
	"""
	var get_quad = func(edge):
		# Get the Adjacent Triangles
		var t1 = edge.get_triangle_1(triangles.indices)
		print('first triangle: ' + str(t1))
		var t2 = edge.get_triangle_2(triangles.indices)
		print('second triangle: ' + str(t2))
		
		# Make The Indices for the Vertices of the Quad
		# If edge is (A,B), then quad is (B,C,A,D),
		# where C is in t1 and D in t2
		var indices = [
			t1[(edge.side_1+1) % 3],
			t1[(edge.side_1+2) % 3],
			t1[edge.side_1],
			t2[(edge.side_2+2) % 3]
		]
		print('quad: ' + str(indices))
		
		# Get the Quad's Vertices from the Indices
		var vertices = []
		for i in indices:
			vertices.append(triangles.vertices[i])
		
		return {'vertices': vertices, 'indices': indices}

	"""
	Returns the distance of point d from the circumcircle of a, b, and c.
	A positive value is inside the circle, a zero value is on the edge,
	and a negative value is outside the circle.
	"""
	var get_distance_from_circumcircle = func(
		a: Vector2, b: Vector2, c: Vector2, d: Vector2):
		var circumcenter = calc_circumcenter(a, b, c)
		var radius = calc_circumcircle_radius(a, b, c)
		var distance_from_center = (circumcenter - d).length()
		return radius - distance_from_center

	"""
	Returns true if flipping an edge improves delanauy conditions.
	quad: The quad of the edge's adjacent triangles.
	"""
	var should_flip = func(quad):
		# Get the Four Vertices
		var a = quad.vertices[0]
		var b = quad.vertices[1]
		var c = quad.vertices[2]
		var d = quad.vertices[3]

		# Edge Cannot be Flipped if Quad is Concave
		if not is_quadrilateral_convex(quad.vertices):
			print('Quadrilateral is not convex.')
			return false

		var cur_distance = get_distance_from_circumcircle.call(a, b, c, d)
		print('cur_distance: ' + str(cur_distance))
		var distance_if_flipped = get_distance_from_circumcircle.call(b, d, a, c)
		print('distance_if_flipped: ' + str(distance_if_flipped))

		# should flip only if it moves point from inside circle to outside
		return cur_distance > 0 && distance_if_flipped <= 0

	"""
	Updates the triangle info for 1 of the triangles of an edge.
	a and b: Indexes of the 2 vertices in the edge.
	triangle_index: Index of the first vertex divided by 3 of
		the triangle to replace.
	new_triangle_index: Index of the first vertex divided by 3 of
		the triangle to replace with.
	
	"
	Updates the info for one of the triangles of an edge.
	a and b: The indices of the 2 vertices of an edge.
	triangle_index: The index of the triangle's first vertex divided by 3
		of the triangle to replace.
	new_triangle_index: The index of the triangle's first vertex divided by 3
		of the triangle to replace with.
	new_side: The side (0, 1, or 2) of the new triangle that the edge is on.
	"""
	var update_triangle_info_in_edge = func(
		a: int, b: int,
		triangle_index: int, new_triangle_index: int,
		new_side: int):
		# Find the Edge for a and b
		var key = [a, b] if [a, b] in edges else [b, a]
		var edge = edges[key]
		
		# Update the Triangle Info
		if edge.triangle_1_index == triangle_index:
			edge.triangle_1_index = new_triangle_index
			edge.side_1 = new_side
		else:
			assert(edge.triangle_2_index == triangle_index,
				'triangle_index does not match index of either triangle.')
			
			edge.triangle_2_index = new_triangle_index
			edge.side_2 = new_side
	
	"""
	Flips an edge by replacing it's adjacent triangles
	with different triangles.
	Then updates edges to match the new geometry.
	quad: The quad of the edge's adjacent triangles.
	edge: The edge to flip.
	"""
	var flip_edge = func(quad, edge):
		var qA = quad.indices[0]
		var qB = quad.indices[1]
		var qC = quad.indices[2]
		var qD = quad.indices[3]
		
		var t1 = edge.triangle_1_index
		var t2 = edge.triangle_2_index
		
		# Replace First Triangle
		triangles.indices[t1*3] = qA
		triangles.indices[(t1*3) + 1] = qB
		triangles.indices[(t1*3) + 2] = qD
		
		# Replace Second Triangle
		triangles.indices[t2*3] = qD
		triangles.indices[(t2*3) + 1] = qB
		triangles.indices[(t2*3) + 2] = qC
		
		# Remove Old Edge
		edges[[qC, qA]] = null
		# Add the New Flipped Edge
		edges[[qB, qD]] = Edge.new(t1, 1, t2, 0)
		
		# Update Each of the 4 Edges of the Quad
		update_triangle_info_in_edge.call(qA, qB, t1, t1, 0)
		update_triangle_info_in_edge.call(qB, qC, t1, t2, 1)
		update_triangle_info_in_edge.call(qC, qD, t2, t2, 2)
		update_triangle_info_in_edge.call(qD, qA, t2, t1, 2)

	# for every edge, flip it if it improves delaunay conditions
	for key in edges:
		var edge = edges[key]
		print('edge: ' + str(edge))
		
		# edge can't be flipped
		if not edge.is_shared():
			print('skipping edge, not shared')
			continue
		
		# the combined shape of the edge's 2 adjacent triangles
		var quad = get_quad.call(edge)
		
		if should_flip.call(quad):
			flip_edge.call(quad, edge)
			print('flipped edge')
		print()


"""
Returns true if the quadrilateral is convex.
This is true if all 4 angles are
greater than 0 and less than 180 degrees.
quad: a 4-length Vector2 array, 1 for each point
"""
static func is_quadrilateral_convex(quad: Array):	
	assert(len(quad) == 4, 'Invalid length of parameter quad.')
	
	# return false if any angle doesn't match the conditions
	for i in 4:
		var a = quad[i]
		var b = quad[(i+1) % 4]
		var c = quad[(i+2) % 4]

		# angle should be less than 180 degrees,
		#	but more than 0,
		# 	in the range of [0, PI) and not in [-PI, 0]
		var angle = (c - b).angle_to(a - b)
		if angle <= FLOAT_EPSILON or angle >= PI - FLOAT_EPSILON:
			return false
	
	return true


static func convert_to_indexed_triangles(old_vertices: Array):
	var vertices = []
	var indices = []
	
	# Iteratively add each old vertex.
	for i in range(len(old_vertices)):
		var vertex = old_vertices[i]
		
		# Use previous index if vertex already added.
		var found_index = vertices.find(vertex)
		if found_index == -1:
			vertices.append(vertex)
			indices.append(len(vertices)-1)
		else:
			indices.append(found_index)
	
	return {'vertices': vertices, 'indices': indices}


static func grow_convex_hull(hull: Array, new_point:Vector2):
	var closest_hull_point_index = null
	var min_distance_squared = null
	
	# Get Point on Hull Closest to New Point
	for i in len(hull):
		var cur_point = hull[i]
		var distance_squared = (cur_point - new_point).length_squared()
		
		if i == 0 || distance_squared < min_distance_squared:
			min_distance_squared = distance_squared
			closest_hull_point_index = i

	"""
	Iterates CCW or CW depending on finding upper or lower tangent.
	Tangent is found when the angle of its direction
	vector to the direction vector of the next point
	flips signs.
	This means that drawing a line between the New Point
	and the Next Point would cross the Hull.
	"""
	var find_tangent_point = func(find_upper: bool):
		var closest_hull_point = hull[closest_hull_point_index]
		var prev_direction = (closest_hull_point - new_point)
		
		var hull_length = len(hull)
		var i_count = 0 # for preventing accidental infinite loop
		var prev_i = closest_hull_point_index
		var i = posmod((closest_hull_point_index + (1 if find_upper else -1)),
			hull_length) # incrementing positive is natural order (CCW)

		# Iterate Until Tangent Found
		while i_count < hull_length:
			var cur_point = hull[i]
			var cur_direction = (cur_point - new_point)
			var angle = prev_direction.angle_to(cur_direction)
			
			if (find_upper && angle >= 0) \
				|| (not find_upper && angle <= 0):
				return prev_i
			
			prev_direction = cur_direction
			
			i_count += 1
			prev_i = i
			i = posmod((i + (1 if find_upper else -1)), hull_length)
		assert(false, 'Tangent point could not be found.')
		
	var upper_tangent_index = find_tangent_point.call(true)
	var lower_tangent_index = find_tangent_point.call(false)
	
#	print('closest_hull_point_index: ' + str(closest_hull_point_index))
#	print('upper_tangent_index: ' + str(upper_tangent_index))
#	print('lower_tangent_index: ' + str(lower_tangent_index))
	
	# Remove Points between the Tangents from Hull
	var hull_length = len(hull)
	var i = posmod((lower_tangent_index + 1), hull_length)
	var num_times_front_popped = 0
	var lower_tangent = hull[lower_tangent_index]
	var upper_tangent = hull[upper_tangent_index]
	var visible_points = [lower_tangent] # ... [L --- H] ...  OR ---] U ... L [---
	while i != upper_tangent_index:
		if i > lower_tangent_index:
			if i < upper_tangent_index: # ... L [---] U ...
				var p = hull.pop_at(lower_tangent_index + 1) # safe
				visible_points.append(p)
			elif i > upper_tangent_index: # ... U ... L [---]
				var p = hull.pop_back()
				visible_points.append(p)
			else: # i == U
				assert(false, 'Iterated to upper tangent somehow.')
		elif i < lower_tangent_index: # [---] U ... L ...
			var p = hull.pop_front()
			visible_points.append(p)
			
			num_times_front_popped += 1
		else: # i == L
			assert(false, 'Iterated to lower tangent somehow.')
		
		i = posmod((i+1), hull_length) # increment
	visible_points.append(upper_tangent)
	
	# Insert New Point into Hull between the Tangents
	var updated_lower_tangent_index = \
		lower_tangent_index - num_times_front_popped
	var insert_index = updated_lower_tangent_index + 1
	hull.insert(insert_index, new_point)
	
#	print('new point inserted at: ', str(insert_index))
#	print('hull: ' + str(hull))
#	print('visible_points: ' + str(visible_points))

	return visible_points


static func get_counter_clockwise_triangle(a: Vector2, b: Vector2, c: Vector2):
	if (b - a).angle_to(c - a) >= 0:
		return [a, b, c]
	else:
		return [a, c, b]


static func calc_circumcircle_radius(a: Vector2, b: Vector2, c: Vector2):
	var angle = abs((b - a).angle_to(c - a))
	return (b - c).length() / (2 * sin(angle))


static func calc_circumcenter(a: Vector2, b: Vector2, c: Vector2):
	var d = 2 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	
	var al = a.length_squared()
	var bl = b.length_squared()
	var cl = c.length_squared()
	
	var cx = (al * (b.y - c.y) + bl * (c.y - a.y) + cl * (a.y - b.y)) / d
	var cy = (al * (c.x - b.x) + bl * (a.x - c.x) + cl * (b.x - a.x)) / d
	
	return Vector2(cx, cy)
