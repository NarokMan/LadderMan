extends "res://scripts/player.gd"

const SPEED = 300.0
const JUMP_VELOCITY = -800.0

func _ready() -> void:
	super()
	walk_speed = SPEED
	jump_speed = JUMP_VELOCITY
	spawn_point = global_position
	ladder_rect = get_parent().get_node("ClimbLadder").get_rect().abs()
	ladder_rect.position += get_parent().get_node("ClimbLadder").global_position

func vertical_gravity() -> float:
	return get_gravity().y

func horizontal_input() -> float:
	var team_axis := Input.get_axis("ui_left", "ui_right")
	return team_axis if team_axis != 0 else super()

func jump_pressed() -> bool:
	return Input.is_action_just_pressed("ui_accept") or super()
