class_name World

var tiles = []

func _init(x_size, y_size):
	for i in x_size:
		var cur = []
		tiles.append(cur)
		for j in y_size:
			var tile = Tile.new()
			tile.set_type('plains')
			var scale = Vector2(2, 2)
			tile.position = (get_hex_coord(i, j, 29, 28) * scale) + Vector2(300, 80)
			tile.scale = scale
			tile.rotation_degrees = 28
			cur.append(tile)

func get_hex_coord(x, y, x_size, y_size):
	var additional_x = (y % 2) * (x_size / 2)
	var new_x = (x * x_size) + additional_x
	var new_y = y * y_size
	return Vector2(new_x, new_y)
