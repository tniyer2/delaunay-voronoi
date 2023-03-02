extends Node


func create_world():
	return World.new(10, 10)


# Called when the node enters the scene tree for the first time.
func _ready():
	var world = create_world()
	for row in world.tiles:
		for tile in row:
			add_child(tile)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
