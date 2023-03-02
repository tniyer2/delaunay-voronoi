class_name Player extends Object

var wisdom = 0
var faith = 0
var is_human


func _init(is_human_):
	self.is_human = is_human_


func start_turn(ui):
	if is_human:
		ui.set_active_player(self)
