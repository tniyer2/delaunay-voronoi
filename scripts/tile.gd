class_name Tile extends Sprite2D

var type = 'None'
var plains_texture = preload("res://sprites/plains.png")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func set_type(type_):
	type = type_
	if (type_ == 'plains'):
		self.set_texture(plains_texture)
	else:
		type = 'None'
