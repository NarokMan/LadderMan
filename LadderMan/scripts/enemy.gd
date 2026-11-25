extends CharacterBody2D
## Reusable enemy. World geometry must use collision layer 1.
## Target must belong to "player" and implement take_damage(amount, source).
signal defeated(reward: int)
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@export_enum("Patrol", "Charge", "Hop") var kind: int = 0
@export var max_health: int = 3
@export var speed: float = 100.0
@export var detection_range: float = 300.0
@export var reward: int = 10
var health: int
var facing: float = -1.0
var state: String = "PATROL"
var timer: float = 0.0
var cooldown: float = 1.0
var flash: float = 0.0
var age: float = 0.0
var target: Node2D
var floor_probe: RayCast2D
var sight: RayCast2D
var pulse: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(42, 64) if kind == 3 else Vector2(30, 48)
	shape.shape = rect
	add_child(shape)
	floor_probe = RayCast2D.new()
	floor_probe.collision_mask = 1
	floor_probe.target_position = Vector2(0, 48)
	add_child(floor_probe)
	sight = RayCast2D.new()
	sight.collision_mask = 1
	add_child(sight)
	target = get_tree().get_first_node_in_group("player") as Node2D

func _physics_process(delta: float) -> void:
	age += delta
	flash = maxf(0, flash - delta)
	pulse = maxf(0, pulse - delta)
	cooldown -= delta
	timer -= delta
	velocity.y += 1000 * delta
	var offset := Vector2.ZERO
	var sees_player := false
	if is_instance_valid(target):
		offset = target.global_position - global_position
		sight.target_position = offset
		sight.force_raycast_update()
		sees_player = offset.length() < detection_range and not sight.is_colliding()
	var grounded := is_on_floor()
	match state:
		"PATROL":
			velocity.x = facing * speed
			if sees_player and kind != 0:
				facing = -1.0 if offset.x < 0 else 1.0
			if kind != 0 and sees_player and cooldown <= 0 and grounded:
				state = "WARN"
				timer = 0.65 if kind != 3 else 1.0
				velocity.x = 0
		"WARN":
			velocity.x = 0
			if timer <= 0:
				state = "ATTACK"
				timer = 0.65
				if kind == 2:
					velocity.y = -480
				elif kind == 3:
					stomp()
		"ATTACK":
			velocity.x = facing * (340 if kind == 1 else 155) if kind != 3 else 0.0
			if (kind == 2 and grounded and velocity.y >= 0) or (kind != 2 and timer <= 0):
				state = "RECOVER"
				timer = 0.85
		"RECOVER":
			velocity.x = 0
			if timer <= 0:
				state = "PATROL"
				cooldown = 1.3
	# Turn before cliffs. During a charge, stop instead of turning instantly.
	floor_probe.position = Vector2(facing * (32 if kind == 3 else 25), 0)
	floor_probe.force_raycast_update()
	if grounded and (not floor_probe.is_colliding() or is_on_wall()):
		facing *= -1
		velocity.x = 0
		if state == "ATTACK":
			state = "RECOVER"
			timer = 0.85
	move_and_slide()
	if is_instance_valid(target):
		var d: Vector2 = target.global_position - global_position
		if absf(d.x) < (40 if kind == 3 else 30) and absf(d.y) < 40:
			target.take_damage(1, global_position)
	if global_position.y > 1100:
		queue_free()
	if sprite != null:
		sprite.flip_h = facing > 0
	queue_redraw()

func stomp() -> void:
	pulse = 0.4
	if not is_instance_valid(target):
		return
	var d: Vector2 = target.global_position - global_position
	# Ground-level pulse: climbing or jumping avoids it. Geometry blocks it.
	sight.target_position = d
	sight.force_raycast_update()
	if absf(d.x) < 155 and absf(d.y) < 48 and not sight.is_colliding():
		target.take_damage(2, global_position)

func take_damage(amount: int, _source: Vector2) -> void:
	if health <= 0:
		return
	health -= amount
	flash = 0.15
	if health <= 0:
		defeated.emit(reward)
		queue_free()

func _draw() -> void:
	# Health bar background.
	draw_rect(
		Rect2(-25, -52, 50, 5),
		Color("343848")
	)

	# Remaining health.
	var health_ratio := maxf(0.0, float(health) / max_health)
	draw_rect(
		Rect2(-25, -52, 50 * health_ratio, 5),
		Color("7bd6a5")
	)

	# Attack warning.
	if state == "WARN":
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-5, -60),
			"!",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			26,
			Color("ffcf70")
		)

		if kind == 3:
			draw_line(
				Vector2(-155, 32),
				Vector2(155, 32),
				Color("ffcf70"),
				3
			)

	# Enemy stomp effect.
	if pulse > 0:
		draw_arc(
			Vector2(0, 30),
			155 * (1 - pulse / 0.4),
			PI,
			TAU,
			32,
			Color("ffcf70"),
			5
		)
