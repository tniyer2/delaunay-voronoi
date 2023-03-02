extends Node

@onready var ui_node = get_node('../CanvasLayer/UI')

var players = []
var active_player_index = -1
var is_after_ready = true

func create_world():
	return World.new(10, 10)


# Called when the node enters the scene tree for the first time.
func _ready():
	players.append(Player.new(true))
	active_player_index = 0
	
	var world = create_world()
	for row in world.tiles:
		for tile in row:
			add_child(tile)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if is_after_ready:
		is_after_ready = false
		after_ready()


func after_ready():
	activate_cur_player()


func end_turn():
	active_player_index += 1
	active_player_index %= len(players)
	
	activate_cur_player()

func activate_cur_player():
	players[active_player_index].start_turn(ui_node)
