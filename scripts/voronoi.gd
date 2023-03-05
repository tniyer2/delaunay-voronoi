class_name Voronoi extends Object


static func generate_voronoi_diagram(points):
	return generate_delaunay_triangulation(points)


# Uses Sweep Hull
static func generate_delaunay_triangulation(points):
	points = points.duplicate(true)
	
	# Get Seed Point
	var seed_point = points.pop_at(0)
	
	# Sort Points by Distance from Seed
	var distance_to_seed = func(point):
		return (point - seed_point).length_squared()
	points.sort_custom(func(a, b):
		return distance_to_seed.call(a) < distance_to_seed.call(b))
	
	# Get Point Closest to Seed
	var closest_point = points.pop_at(0)
	
	# Sort Points by Radius of Circumcircle with Seed Point and Closest Point
	points.sort_custom(func(a, b):
		return calc_circumcircle_radius(a, closest_point, seed_point) \
			< calc_circumcircle_radius(b, closest_point, seed_point))
	
	# Get Point that Makes the Smallest Circumcircle
	var min_cc_point = points.pop_at(0)
	# Get the Circumcenter for the Previous Point
	var circumcenter = calc_circumcenter(min_cc_point, closest_point, seed_point)
	
	# Initial Convex Hull
	var hull = get_counter_clockwise_triangle(min_cc_point, closest_point, seed_point)
	
	# Sort Points by Distance from the Seed Circumcircle's Circumcenter
	var distance_to_circumcenter = func(point):
		return (point - circumcenter).length_squared()
	points.sort_custom(func(a, b):
		return distance_to_circumcenter.call(a) \
		< distance_to_circumcenter.call(b))
	
#	print(hull + points)
	
	# Use Sorted Points to Grow Hull and Add Triangles
	var final_vertices = hull.duplicate(true)
	for point in points:
		var visible_points = add_vertex_to_convex_hull(hull, point)
		for i in range(len(visible_points) - 1):
			var cur = visible_points[i]
			var next = visible_points[i+1]
			
			# works for both CW and CCW order
			final_vertices.append(point)
			final_vertices.append(next)
			final_vertices.append(cur)
	
#	var a = []
#	var b = [final_vertices[0], final_vertices[1], final_vertices[2]] + points
#	print()
#	print(b)
#	print(final_vertices)
#	for x in final_vertices:
#		a.append(b.find(x))
#	print(a)
	
	return final_vertices


static func add_vertex_to_convex_hull(hull: Array, new_point:Vector2):
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
				|| (!find_upper && angle <= 0):
				return prev_i
			
			prev_direction = cur_direction
			
			i_count += 1
			prev_i = i
			i = posmod((i + (1 if find_upper else -1)), hull_length)
		assert(false, "Tangent point could not be found.")
		
	var upper_tangent_index = find_tangent_point.call(true)
	var lower_tangent_index = find_tangent_point.call(false)
	
#	print("closest_hull_point_index: " + str(closest_hull_point_index))
#	print("upper_tangent_index: " + str(upper_tangent_index))
#	print("lower_tangent_index: " + str(lower_tangent_index))
	
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
				assert(false, "Iterated to upper tangent somehow.")
		elif i < lower_tangent_index: # [---] U ... L ...
			var p = hull.pop_front()
			visible_points.append(p)
			
			num_times_front_popped += 1
		else: # i == L
			assert(false, "Iterated to lower tangent somehow.")
		
		i = posmod((i+1), hull_length) # increment
	visible_points.append(upper_tangent)
	
	# Insert New Point into Hull between the Tangents
	var updated_lower_tangent_index = \
		lower_tangent_index - num_times_front_popped
	var insert_index = updated_lower_tangent_index + 1
	hull.insert(insert_index, new_point)
	
#	print("new point inserted at: ", str(insert_index))
#	print("hull: " + str(hull))
#	print("visible_points: " + str(visible_points))

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
