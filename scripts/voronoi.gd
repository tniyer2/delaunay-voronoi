class_name Voronoi extends Object

const FLOAT_EPSILON = 0.00001


"""
Generates a Voronoi Diagram of a set of points by
taking the Dual Graph of its Delaunay Triangulation.
points: A set of points.
"""
static func generate_voronoi_diagram(points):
	return generate_delaunay_triangulation(points)


"""
Generates a Delanauy Triangulation of a set of points
using the Sweep Hull algorithm.
points: The points to find the delanauy triangulation of.
"""
static func generate_delaunay_triangulation(points):
	var original_points_length = len(points)
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
	
	print('non-overlapping triangles:\n'\
		+ get_indexed_geometry_json(triangles))
	
	var edges = get_edges(triangles)
	print('edges: ' + str(edges) + '\n')
	
	flip_edges(triangles, edges)
	print('flipped triangles:\n'\
		+ get_indexed_geometry_json(triangles))
	
	return triangles


"""
Returns a 3-length array of Vector2 positions in CCW order.
Returns null if degenerate case and no order can be determined.
a, b, and c: Vector2 positions to order.
"""
static func get_counter_clockwise_triangle(a: Vector2, b: Vector2, c: Vector2):
	var angle = (b - a).angle_to(c - a)
	
	# ac and ab point in opposite directions
	if abs(angle) >= PI - FLOAT_EPSILON:
		return null
	elif angle > FLOAT_EPSILON: # ac CCW to ab
		return [a, b, c]
	elif angle < FLOAT_EPSILON: # ac CW to ab
		return [a, c, b]
	else: # angle is 0, ac and ab point in same direction
		return null


"""
Returns the radius of the circumcircle that any 3 2D points lie on.
Returns null if degenerate case.
a, b, and c: The points that lie on the circumcircle.
"""
static func calc_circumcircle_radius(a: Vector2, b: Vector2, c: Vector2):
	var angle = abs((b - a).angle_to(c - a))
	
	var numerator = (b - c).length()
	var denominator = 2 * sin(angle)
	if abs(numerator) <= FLOAT_EPSILON or abs(denominator) <= FLOAT_EPSILON:
		return null
		
	var r = numerator / denominator
	if abs(r) <= FLOAT_EPSILON:
		return null
	
	return r


"""
Returns the center of the circumcircle that any 3 2D points lie on.
Returns null if degenerate case.
a, b, and c: The points that lie on the circumcircle.
"""
static func calc_circumcenter(a: Vector2, b: Vector2, c: Vector2):
	var d = 2 * ((a.x * (b.y-c.y)) + (b.x * (c.y-a.y)) + (c.x * (a.y-b.y)))
	
	# degenerate case, points line up or 2 or all are the same.
	if abs(d) <= FLOAT_EPSILON:
		return null
	
	var al = a.length_squared()
	var bl = b.length_squared()
	var cl = c.length_squared()
	
	var ccx = ((al * (b.y-c.y)) + (bl * (c.y-a.y)) + (cl * (a.y-b.y))) / d
	var ccy = ((al * (c.x-b.x)) + (bl * (a.x-c.x)) + (cl * (b.x-a.x))) / d
	
	return Vector2(ccx, ccy)


"""
Adds a 2D point to a 2D convex hull.
This function assumes that the new point is outside of the hull and
the hull already has at least 3 points.
Returns a list of points on the hull that are visible to the new point.
A point is visible if there is a straight path to it
that doesn't intersect with the hull.
hull: A Vector2 Array that lists the points on the hull in CCW order.
new_point: The point to add to the hull.
"""
static func grow_convex_hull(hull: Array, new_point:Vector2):
	assert(len(hull) >= 3, 'hull must have at least 3 points.')
	
	var closest_index
	var min_distance_squared
	
	# Find Point on Hull Closest to New Point
	for i in len(hull):
		var distance_squared = (hull[i] - new_point).length_squared()
		
		if i == 0 || distance_squared < min_distance_squared:
			closest_index = i
			min_distance_squared = distance_squared
	
	assert(closest_index != null, 'closest_index uninitialized.')
	
	"""
	Iterates CCW if finding upper and CW if finding lower.
	Tangent is found when drawing a line with the next point
	intersects with the hull.
	"""
	var find_tangent_point_index = func(find_upper: bool):
		var closest_point = hull[closest_index]
		var prev_direction = closest_point - new_point # initial value
		
		var hull_length = len(hull)
		var i_count = 0 # to prevent infinite loop
		var prev_i = closest_index # initial value
		# increment goes in natural order (will probably be CCW)
		var delta = 1 if find_upper else -1
		# posmod works nicely both forwards and backwards
		var i = posmod(closest_index + delta, hull_length)
		
		# Iterates CCW/CW through hull until tangent is found
		# tangent is found when cur_point is the last visible point
		while i_count < hull_length:
			var cur_point = hull[i]
			var cur_direction = cur_point - new_point
			var angle = prev_direction.angle_to(cur_direction)
			
			# if cur_point not visible, previous point was tangent
			if (find_upper && angle >= -FLOAT_EPSILON) \
				|| (not find_upper && angle <= FLOAT_EPSILON):
				return prev_i
			
			# tangent not found, increment to next point
			prev_direction = cur_direction
			i_count += 1
			prev_i = i
			i = posmod(i + delta, hull_length)
		
		assert(false, 'Tangent point could not be found.')
		return -1
	
	# Find Both Tangents
	var L = find_tangent_point_index.call(false)
	var U = find_tangent_point_index.call(true)
	
	var visible_points = [hull[L]]
	var upper_tangent = hull[U] # don't move this line, U changes after loop
	
	# Remove All Points between the Tangents,
	# Adding them to Visible Points,
	# and Insert a New Point in between.
	if L <= U:
		# Result: . . . L x x x U . . .
		for _i in range((U-L) - 1):
			visible_points.append(
				hull.pop_at(L+1))
		
		# Result: . . . L New_Point U . . .
		hull.insert(L+1, new_point)
	else:
		# Result: . . . U . . . L x x x
		for _i in range((len(hull)-L) - 1):
			# don't change to pop_back(), otherwise order will get messed up
			visible_points.append(
				hull.pop_at(L+1))
		
		# Result: . . . U . . . L New_Point
		hull.insert(L+1, new_point)
		
		# Result: x x x U . . . L New_Point
		for _i in range(U):
			visible_points.append(
				hull.pop_at(0))
	
	visible_points.append(upper_tangent)
	
	return visible_points


"""
Returns the indexed format of a 2D or 3D Geometry.
The indexed format consists of a vector array of vertex positions
with an array defining triangles by referencing vertices by index.
old_vertices: The vector array of positions to be converted.
"""
static func convert_to_indexed_triangles(old_vertices: Array):
	var vertices = []
	var indices = []
	
	# stores an added vertex with its index in vertices
	var added_locs = {}
	
	# Iteratively Process Each Vertex to Convert
	for vertex in old_vertices:
		if vertex in added_locs:
			var loc = added_locs[vertex]
			indices.append(loc)
		else:
			vertices.append(vertex)
			
			var loc = len(vertices) - 1 # last index
			added_locs[vertex] = loc
			indices.append(loc)
	
	return {'vertices': vertices, 'indices': indices}


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
	
	func _to_string():
		var s = 'side ' + str(side_1) + ' of triangle ' + str(triangle_1_index)
		if triangle_2_index != -1:
			s += ', side ' + str(side_2) + ' of triangle ' + str(triangle_2_index)
		return s


"""
Returns a dictionary of the edges in a 2D geometry.
The key is an array containing the indices of the 2 vertices of the edge.
The order of the indices in the key is arbitrary.
triangles: a 2D geometry (in indexed format) to get the edges of.
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
Flips all of the edges in a 2D geometry
so that it is a valid delanauy triangulation.
triangles: 2D geometry (in indexed format) to flip.
edges: dictionary of edges for the 2D geometry.
"""
static func flip_edges(triangles, edges):
	"""
	Uses the 2 adjacent triangles of a shared edge in order to
	return the combined 4-sided shape.
	edge: An edge shared by 2 adjacent triangles.
	"""
	var get_quad = func(edge):
		assert(edge.is_shared(), 'Invalid argument. edge must be shared.')
		
		# Get the 2 Adjacent Triangles
		var t1 = edge.get_triangle_1(triangles.indices)
		var t2 = edge.get_triangle_2(triangles.indices)
		
		# If edge is (A,B), then quad is (B,C,A,D),
		var indices = [
			# In Triangle 1
			t1[(edge.side_1 + 1) % 3], # B (shared with Triangle 2)
			t1[(edge.side_1 + 2) % 3], # C
			t1[edge.side_1],           # A (shared with Triangle 2)
			
			# In Triangle 2
			t2[(edge.side_2 + 2) % 3]  # D
		]
		
		# get respective vertices for convenience
		var vertices = []
		for i in indices:
			vertices.append(triangles.vertices[i])
		
		return {'vertices': vertices, 'indices': indices}
	
	"""
	Returns the distance of d from the circumcircle of a, b, and c.
	A positive value means d is inside the circle,
	a value of 0 means d is on the edge,
	and a negative value means d is outside the circle.
	"""
	var get_distance_from_circumcircle = func(
		a: Vector2, b: Vector2, c: Vector2, d: Vector2):
		var circumcenter = calc_circumcenter(a, b, c)
		var distance_from_center = (circumcenter - d).length()
		
		var radius = calc_circumcircle_radius(a, b, c)
		
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
			return false
		
		var cur_distance = get_distance_from_circumcircle.call(a, b, c, d)
		var distance_if_flipped = get_distance_from_circumcircle.call(b, d, a, c)
		
		# should flip only if it moves point from inside circle to outside
		return cur_distance > 0 && distance_if_flipped <= 0
	
	"""
	Updates an edge's triangle info for 1 of its triangles.
	a and b: Indices of the 2 vertices of an edge.
	triangle_index: Index of the first vertex divided by 3
	of the triangle to replace.
	new_triangle_index: Index of the first vertex divided by 3
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
	Flips an edge by replacing its 2 adjacent triangles
	with the 2 alternate triangles.
	Then updates edges to match the changed geometry.
	quad: The quad of the edge's adjacent triangles.
	edge: The edge to flip.
	"""
	var flip_edge = func(quad, edge):
		var qA = quad.indices[0] # was B
		var qB = quad.indices[1] # was D
		var qC = quad.indices[2] # was A
		var qD = quad.indices[3] # was C
		
		var t1 = edge.triangle_1_index
		var t2 = edge.triangle_2_index
		
		# Replace First Triangle
		triangles.indices[t1 * 3] = qA
		triangles.indices[(t1 * 3) + 1] = qB
		triangles.indices[(t1 * 3) + 2] = qD
		
		# Replace Second Triangle
		triangles.indices[t2 * 3] = qD
		triangles.indices[(t2 * 3) + 1] = qB
		triangles.indices[(t2 * 3) + 2] = qC
		
		# Remove Old Edge, previously (A,B)
		edges[[qC, qA]] = null
		# Add the New Flipped Edge, previously (D,C)
		edges[[qB, qD]] = Edge.new(t1, 1, t2, 0)
		
		# Update Each of the 4 Sides (edges) of the Quad
		# The triangles they are adjacent to
		# and their side on that triangle has changed
		update_triangle_info_in_edge.call(
			qA, qB, t1, t1, 0) # previously (B, D)
		update_triangle_info_in_edge.call(
			qB, qC, t1, t2, 1) # previously (D, A)
		update_triangle_info_in_edge.call(
			qC, qD, t2, t2, 2) # previously (A, C)
		update_triangle_info_in_edge.call(
			qD, qA, t2, t1, 2) # previously (C, B)
	
	# for every edge, flip it if it improves delaunay conditions
	for key in edges:
		var edge = edges[key]
#		print('edge: ' + str(key) + ' - ' + str(edge))
		
		# edge can't be flipped
		if not edge.is_shared():
			continue
		
		# the combined shape of the edge's 2 adjacent triangles
		var quad = get_quad.call(edge)
		
		if should_flip.call(quad):
			flip_edge.call(quad, edge)


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

		# angle should be less than 180 degrees, but more than 0.
		# 	it must be positive and not close to 0, PI, or -PI.
		var angle = (c - b).angle_to(a - b)
		if angle <= FLOAT_EPSILON or angle >= PI - FLOAT_EPSILON:
			return false
	
	return true


"""
Returns a JSON string of an indexed 2D geometry.
geometry: A 2D geometry in indexed format.
"""
static func get_indexed_geometry_json(geometry):
	var flattened_vertices = []
	for v in geometry.vertices:
		flattened_vertices.append(v.x)
		flattened_vertices.append(v.y)
	
	return JSON.stringify({
		'vertices': flattened_vertices,
		'indices': geometry.indices
	})
