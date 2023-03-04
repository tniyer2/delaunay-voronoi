class_name Voronoi extends Object


static func generate_voronoi_diagram(points):
	return generate_delaunay_triangulation(points)


# Uses Sweep Hull
static func generate_delaunay_triangulation(points):
	points = points.duplicate(true)
	
	var seed_point = points.pop_at(0)
	
	var distance_to_seed = func(point):
		return (point - seed_point).length_squared()
	points.sort_custom(func(a, b):
		return distance_to_seed.call(a) < distance_to_seed.call(b))
	
	var closest_point = points.pop_at(0)
		
	points.sort_custom(func(a, b):
		return calc_circumcircle_radius(a, closest_point, seed_point) \
			< calc_circumcircle_radius(b, closest_point, seed_point))
	
	var min_cc_point = points.pop_at(0)
	
	var circumcenter = calc_circumcenter(seed_point, closest_point, min_cc_point)
	
	var distance_to_circumcenter = func(point):
		return (point - circumcenter).length_squared()
	
	points.sort_custom(func(a, b):
		return distance_to_circumcenter.call(a) \
		< distance_to_circumcenter.call(b))
	
	# initial convex hull
	var convex_hull = get_clockwise_triangle(seed_point, closest_point, min_cc_point)
	
	return convex_hull + points


static func get_clockwise_triangle(a: Vector2, b: Vector2, c: Vector2):
	if (b - a).angle_to(b - c) < PI:
		return [a, c, b]
	else:
		return [a, b, c]


static func calc_circumcircle_radius(a: Vector2, b: Vector2, c: Vector2):
	var angle = (b - a).angle_to(c - a)
	if angle > PI:
		angle = (2 * PI) - angle
	return (b - c).length() / (2 * sin(angle))


static func calc_circumcenter(a: Vector2, b: Vector2, c: Vector2):
	var d = 2 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	
	var al = a.length_squared()
	var bl = b.length_squared()
	var cl = c.length_squared()
	
	var cx = (al * (b.y - c.y) + bl * (c.y - a.y) + cl * (a.y - b.y)) / d
	var cy = (al * (c.x - b.x) + bl * (a.x - c.x) + cl * (b.x - a.x)) / d
	
	return Vector2(cx, cy)
