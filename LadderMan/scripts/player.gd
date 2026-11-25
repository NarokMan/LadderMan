extends CharacterBody2D
## Temporary miner controller: arms/ladder support, no legs.
@onready var sprite: Sprite2D = $Sprite2D
var health: int = 10
var invulnerable: float = 0.0
var swing: float = 0.0
var facing: float = 1.0
var climbing: bool = false
var spawn_point := Vector2(130,570)
var ladder_rect := Rect2(250,310,50,310)

# Defaults retain the standalone enemy lab's controls and physics.
var walk_speed := 220.0
var jump_speed := -460.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	if get_node_or_null("CollisionShape2D") != null:
		return
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28,38)
	collision.shape = shape
	add_child(collision)

func _physics_process(delta: float) -> void:
	invulnerable = maxf(0,invulnerable-delta)
	swing = maxf(0,swing-delta)
	var horizontal := horizontal_input()
	var vertical := Input.get_axis("up","down")
	if horizontal != 0:
		facing = signf(horizontal)
	if ladder_rect.has_point(global_position) and vertical != 0:
		climbing = true
	if not ladder_rect.has_point(global_position):
		climbing = false
	velocity.x = horizontal * walk_speed
	if climbing:
		velocity.y = vertical * 180
		if velocity.y < 0:
			velocity.y = maxf(velocity.y, (ladder_rect.position.y - global_position.y) / delta)
	else:
		velocity.y += vertical_gravity() * delta
	if jump_pressed() and (is_on_floor() or climbing):
		velocity.y = jump_speed
		climbing = false
	if Input.is_action_just_pressed("attack") and swing <= 0:
		swing = 0.28
		for enemy in get_tree().get_nodes_in_group("enemies"):
			var d: Vector2 = enemy.global_position-global_position
			if d.x*facing >= -8 and d.x*facing < 100 and absf(d.y) < 55:
				var ray := PhysicsRayQueryParameters2D.create(global_position,enemy.global_position,1)
				if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
					enemy.take_damage(1,global_position)
	move_and_slide()
	if global_position.y > 850:
		take_damage(2,global_position)
		global_position = spawn_point
		velocity = Vector2.ZERO
		climbing = false

	# Assumes the original image faces right.
	sprite.flip_h = facing > 0

	# Blink while temporarily invulnerable after taking damage.
	sprite.visible = not (
		invulnerable > 0
		and int(invulnerable * 15) % 2 == 0)
	queue_redraw()

func vertical_gravity() -> float:
	return 1000.0

func horizontal_input() -> float:
	return Input.get_axis("left","right")

func jump_pressed() -> bool:
	return Input.is_action_just_pressed("jump")

func take_damage(amount: int, _source: Vector2) -> void:
	if invulnerable > 0:
		return
	health -= amount
	invulnerable = 1.0
	if health <= 0:
		health = 10
		global_position = spawn_point
		velocity = Vector2.ZERO
		climbing = false

func _draw() -> void:
	# Hide the ladder swing during the damage blink.
	if invulnerable > 0 and int(invulnerable * 15) % 2 == 0:
		return

	# Draw the ladder weapon while attacking.
	if swing > 0:
		# The two long rails.
		for y in [-10, 8]:
			draw_line(
				Vector2(facing * 18, y),
				Vector2(facing * 98, y),
				Color("ffe3a4"),
				4
			)

		# The ladder rungs.
		for x in range(25, 95, 14):
			draw_line(
				Vector2(facing * x, -10),
				Vector2(facing * x, 8),
				Color("ffe3a4"),
				3
			)
