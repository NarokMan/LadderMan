extends Node2D
const PlayerScene = preload("res://scenes/player/Player.tscn")
const EnemyScene = [
	preload("res://scenes/enemies/TestEnemy1.tscn"),
	preload("res://scenes/enemies/TestEnemy2.tscn"),
	preload("res://scenes/enemies/TestEnemy3.tscn")]
const NAMES = ["TEST ENEMY"]
var player: CharacterBody2D
var enemy: CharacterBody2D
var info: Label
var selected: int = 0
var platforms: Array[Rect2] = [Rect2(40,620,1020,50),Rect2(150,360,100,20),Rect2(760,420,220,20)]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	bind_key("left",KEY_A)
	bind_key("right",KEY_D)
	bind_key("up",KEY_W)
	bind_key("down",KEY_S)
	bind_key("jump",KEY_SPACE)
	bind_key("attack",KEY_J)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack",mouse)
	for rect in platforms:
		platform(rect)
	platform(Rect2(20,100,20,570))
	platform(Rect2(1060,100,20,570))
	player = PlayerScene.instantiate()
	player.position = Vector2(130,570)
	add_child(player)
	spawn_enemy(0)
	
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: spawn_enemy(0)
			KEY_2: spawn_enemy(1)
			KEY_3: spawn_enemy(2)
	
func bind_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action,event)
	
func platform(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func spawn_enemy(index: int) -> void:
	for old in get_tree().get_nodes_in_group("enemies"):
		remove_child(old)
		old.queue_free()
	selected = index
	enemy = EnemyScene[index].instantiate()
	enemy.position = Vector2(850,570)
	add_child(enemy)

func _draw() -> void:
	for rect in platforms:
		draw_rect(rect,Color("343d50"))
		draw_line(rect.position,rect.position+Vector2(rect.size.x,0),Color("79889a"),3)
	# Ladder exits beside the platform, allowing the miner to step onto its top.
	for x in [260,290]:
		draw_line(Vector2(x,310),Vector2(x,620),Color("bb925c"),5)
	for y in range(315,620,18):
		draw_line(Vector2(260,y),Vector2(290,y),Color("e0bd83"),4)
