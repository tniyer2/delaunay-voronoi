class_name World


const TILE_WIDTH = 29
const TILE_HEIGHT = 28
const TILE_DEGREES = 28

var width: int
var height: int
var tiles = []


func _init(width_, height_):
	width = width_
	height = height_
	
	create_empty_tiles()
	generate_terrain()


func create_empty_tiles():
	for i in width:
		var cur = []
		tiles.append(cur)
		for j in height:
			var tile = create_empty_tile(i, j)
			cur.append(tile)


func create_empty_tile(hex_pos_x, hex_pos_y):
	var tile = Tile.new()
	tile.set_type('plains') # @TODO: get rid of this
	
	var hex_coords = hex_to_2d(hex_pos_x, hex_pos_y, TILE_WIDTH, TILE_HEIGHT)
	
	tile.rotation_degrees = TILE_DEGREES
	
	var base_position = Vector2(300, 80)
	var scale = Vector2(2, 2)
	tile.position = (hex_coords * scale) + base_position
	tile.scale = scale
	
	return tile


func generate_terrain():
#	seed(828394)
#	seed(23849)
#	seed(29838)
	seed(672058)
	var random_points = get_random_points(20)
	var _d = Voronoi.generate_voronoi_diagram(random_points)


func get_random_points(num_points):
	var pos = []
	for i in num_points:
		pos.append(Vector2(randf(), randf()))
	return pos


func hex_to_2d(x, y, tile_width, tile_height):
	# Offset every other tile
	var offset_x = (y % 2) * (tile_width / 2)
	
	var new_x = (x * tile_width) + offset_x
	var new_y = y * tile_height
	
	return Vector2(new_x, new_y)
