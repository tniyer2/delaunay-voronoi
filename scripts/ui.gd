extends Control


var active_player = null
@onready var wisdom_text = get_node('Panel/Wisdom/Text')


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func set_active_player(player):
	active_player = player
	wisdom_text.text = '+' + str(player.wisdom)
