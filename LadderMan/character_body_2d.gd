class_name Player
extends CharacterBody2D
## Ladder Man's movement: walking, jumping, climbing, and handing control to ladders.
## Which ladders he carries and uses lives in the LadderInventory child node.

## Controls (Project Settings > Input Map):
##		move_left/right  	A/D or arrows
##		jump           		Space
##		move_up/down     	W/S or arrows
##		use_ladder     		F or left mouse
##		prev/next_ladder 	Q/E (also 1-9 and mouse wheel, see LadderInventory)
##		pickup_ladder  		R

const SPEED = 300.0
const ACCELERATION = 2000.0
const DECELERATION = 3000.0
const AIR_ACCELERATION = 1200.0
const AIR_DRAG = 150.0
const JUMP_VELOCITY = -400.0
const CLIMB_SPEED = 260.0
## Fall below this y and you respawn at the start position.
const RESPAWN_Y = 2000.0

#Export variables are set in the inspector

## Face toward the mouse. If off, faces the walking direction.
@export var mouse_aim := true
@export var art_faces_left := true

## 1 = facing right, -1 = facing left. Ladders are placed in this direction.
var facing := 1.0
## The ladder being climbed, or null.
var climb_ladder: Ladder
var climbing: bool:
	get: return climb_ladder != null
## A ladder currently driving the player's movement (e.g. swinging on a rope ladder), or null.
var controller: Ladder
## This physics frame's input. Ladders read input from here instead of from Input.
var input := PlayerInput.new()

@onready var inventory: LadderInventory = $LadderInventory
@onready var _shape: CollisionShape2D = $CollisionShape2D

var _last_landing_speed := 0.0
var _last_landing_frame := -100
var _touching: Array[Ladder] = []
var _modifiers := {}   # name -> movement modifier
var _spawn_position: Vector2


func _ready() -> void:
	add_to_group("player")
	_spawn_position = global_position


func _process(_delta: float) -> void:
	if mouse_aim:
		var dx := get_global_mouse_position().x - global_position.x
		if absf(dx) > 4.0:  # small deadzone so it doesn't flicker when the mouse is right on him
			facing = signf(dx)
	$Sprite2D.flip_h = (facing > 0.0) == art_faces_left


func _physics_process(delta: float) -> void:
	input.poll()
	for ladder in _touching.duplicate():
		ladder.on_player_inside(self, delta)

	inventory.update(input, delta)

	if is_instance_valid(controller):
		controller.control_player(self, delta)
	elif climbing:
		_climb(delta)
	else:
		_move(delta)
		_try_start_climbing()

	var was_on_floor := is_on_floor()
	var fall_speed := velocity.y
	move_and_slide()
	if is_instance_valid(controller):
		controller.after_player_moved(self, delta)
	if is_on_floor() and not was_on_floor:
		_last_landing_speed = fall_speed
		_last_landing_frame = Engine.get_physics_frames()

	if global_position.y > RESPAWN_Y:
		respawn()


func _move(delta: float) -> void:
	var grounded := is_on_floor()
	if not grounded:
		velocity += get_gravity() * delta

	if input.jump_pressed and grounded:
		velocity.y = minf(velocity.y, JUMP_VELOCITY)

	var direction := input.move.x
	if direction and not mouse_aim:
		facing = signf(direction)

	if not grounded:
		# In the air, keep momentum
		if direction == 0.0:
			velocity.x = move_toward(velocity.x, 0.0, AIR_DRAG * delta)
		elif signf(velocity.x) != signf(direction) or absf(velocity.x) < SPEED:
			velocity.x = move_toward(velocity.x, direction * SPEED, AIR_ACCELERATION * delta)
	else:
		var target := direction * SPEED
		# Speeding up in the direction you're already moving uses ACCELERATION
		# stopping or turning around, uses DECELERATION
		var speeding_up := direction != 0.0 and signf(velocity.x) != -signf(direction) and absf(velocity.x) < SPEED
		velocity.x = move_toward(velocity.x, target, (ACCELERATION if speeding_up else DECELERATION) * delta)

	for key in _modifiers.keys():
		if not _modifiers[key].modify_velocity(self, delta):
			_modifiers.erase(key)


func _try_start_climbing() -> void:
	var ladder := _find_climbable()
	if ladder == null:
		return
	var feet_y := global_position.y + get_half_size().y
	var above_base := feet_y < ladder.global_position.y - 8.0
	if input.move.y < 0.0 or (input.move.y > 0.0 and above_base):
		start_climbing(ladder)


func _climb(delta: float) -> void:
	if climb_ladder not in _touching:
		stop_climbing()
		return

	velocity.y = input.move.y * CLIMB_SPEED
	# pull player toward the ladder's center.
	velocity.x = clampf((climb_ladder.global_position.x - global_position.x) / delta, -SPEED, SPEED)

	if input.jump_pressed:
		stop_climbing()
		velocity.y = JUMP_VELOCITY * 0.85
		velocity.x = input.move.x * SPEED
	elif velocity.y > 0.0 and is_on_floor():
		stop_climbing()


# ---------------------------------------------------------------------------
# API used by ladders
# ---------------------------------------------------------------------------

## Half the size of the player's collision box (accounts for the shape's scale).
func get_half_size() -> Vector2:
	var rect := _shape.shape as RectangleShape2D
	return rect.size * _shape.scale.abs() / 2.0


## Downward speed of a landing that happened in the last couple of frames, otherwise 0.
func recent_landing_speed() -> float:
	if Engine.get_physics_frames() - _last_landing_frame <= 2:
		return _last_landing_speed
	return 0.0


## Sets velocity directly (bounces, launches, explosions). Knocks the player off any ladder.
func launch(new_velocity: Vector2) -> void:
	stop_climbing()
	clear_controller()
	velocity = new_velocity


## Direction to throw things in: toward the mouse, or forward and a bit up without mouse aim.
func get_aim_direction() -> Vector2:
	if mouse_aim:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 1.0:
			return to_mouse.normalized()
	return Vector2(facing, -0.5).normalized()


## Hands movement over to a ladder (it gets control_player/after_player_moved calls).
func set_controller(ladder: Ladder) -> void:
	stop_climbing()
	_modifiers.clear()
	controller = ladder


func clear_controller() -> void:
	controller = null


## Adds (or replaces) a movement modifier under [param key]. Used by ladders that tweak normal
## walking without taking over (e.g. the speed ladder's boost). [param modifier] must have
## [code]modify_velocity(p: Player, delta: float) -> bool[/code]; it runs after the walking code
## each frame and is dropped once it returns false. Climbing, controllers and respawn clear them.
func set_movement_modifier(key: StringName, modifier: Object) -> void:
	_modifiers[key] = modifier


## Hit by an enemy or hazard. For now: back to the start.
func hurt() -> void:
	respawn()


func start_climbing(ladder: Ladder) -> void:
	climb_ladder = ladder
	_modifiers.clear()
	# Let the player pass through the ladder's top platform while climbing.
	if is_instance_valid(ladder.top_platform):
		add_collision_exception_with(ladder.top_platform)


func stop_climbing() -> void:
	if is_instance_valid(climb_ladder) and is_instance_valid(climb_ladder.top_platform):
		remove_collision_exception_with(climb_ladder.top_platform)
	climb_ladder = null


func respawn() -> void:
	stop_climbing()
	clear_controller()
	global_position = _spawn_position
	velocity = Vector2.ZERO
	_modifiers.clear()
	inventory.refill_uses()


## Ladders the player is currently overlapping.
func get_touching() -> Array[Ladder]:
	return _touching


## Called by Ladder when the player enters its area.
func ladder_touched(ladder: Ladder) -> void:
	if ladder not in _touching:
		_touching.append(ladder)


## Called by Ladder when the player leaves its area (or the ladder leaves the tree).
func ladder_untouched(ladder: Ladder) -> void:
	_touching.erase(ladder)
	if ladder == climb_ladder:
		stop_climbing()


func _find_climbable() -> Ladder:
	for ladder in _touching:
		if ladder.climbable:
			return ladder
	return null
