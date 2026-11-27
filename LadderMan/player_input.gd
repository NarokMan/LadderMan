class_name PlayerInput
extends RefCounted
## One physics frame's worth of player input, read once by the Player (see [method poll]).
## Ladders and the LadderInventory read input from here, should make reworking inputs simpler in the future.

## x = left/right (-1..1), y = up/down (-1 = up, 1 = down).
var move := Vector2.ZERO
var jump_pressed := false
var jump_held := false
var use_pressed := false
var use_held := false
var pickup_pressed := false
var next_pressed := false
var prev_pressed := false


## Fills this in from the Input Map actions.
func poll() -> void:
	move = Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	jump_pressed = Input.is_action_just_pressed("jump")
	jump_held = Input.is_action_pressed("jump")
	use_pressed = Input.is_action_just_pressed("use_ladder")
	use_held = Input.is_action_pressed("use_ladder")
	pickup_pressed = Input.is_action_just_pressed("pickup_ladder")
	next_pressed = Input.is_action_just_pressed("next_ladder")
	prev_pressed = Input.is_action_just_pressed("prev_ladder")
