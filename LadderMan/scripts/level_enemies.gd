extends Node2D

const ENEMIES := [
	preload("res://scenes/enemies/TestEnemy1.tscn"),
	preload("res://scenes/enemies/TestEnemy2.tscn"),
	preload("res://scenes/enemies/TestEnemy3.tscn"),
]
var current_enemy: CharacterBody2D

func _ready() -> void:
	spawn_enemy(0)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: spawn_enemy(0)
			KEY_2: spawn_enemy(1)
			KEY_3: spawn_enemy(2)

func spawn_enemy(index: int) -> void:
	if is_instance_valid(current_enemy):
		remove_child(current_enemy)
		current_enemy.queue_free()
	current_enemy = ENEMIES[index].instantiate()
	current_enemy.position = $EnemySpawn.position
	add_child(current_enemy)
