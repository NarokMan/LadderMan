class_name Ladder
extends Node2D


##  1. The player presses "use_ladder" with this ladder type selected.
##  2. The player instances the ladder's scene, adds it to the level and calls deploy().
##     If deploy returns false (e.g. no ground to place on) the ladder is thrown away.
##  3. While "use_ladder" stays held, the player calls [method use_held] every physics frame,
##     then [method use_released] once when the button is let go.
##  4. While the player overlaps the ladder's area, the player calls [method on_player_inside]
##     every physics frame. This is where things like bouncing or speed boosts happen.
##
## Config vars are @export: subclasses set their defaults in _init(), and a ladder's .tscn can
## override them in the inspector.

## Physics layer bits (match the names in Project Settings > Layer Names > 2D Physics).
const WORLD_LAYER := 1    # layer 1: ground tiles, ladder tops you can stand on
const PLAYER_LAYER := 2   # layer 2: the player
const LADDER_LAYER := 3   # layer 3: ladder trigger areas

# --- Config: subclasses set defaults in their own _init(); .tscn files can override ---
## Name shown in the HUD.
@export var display_name := "Ladder"
## Color used for this ladder in the HUD.
@export var hud_color := Color(0.72, 0.52, 0.28)
## How many of this type can be placed at once. Placing another removes the oldest. 0 = no limit.
@export var max_active := 1
## Whether the player can climb this ladder with up/down.
@export var climbable := false
## Whether the "pickup_ladder" key can remove it.
@export var can_pick_up := true
## Limited uses per life (e.g. dynamite rungs). -1 = unlimited. Refilled on respawn.
@export var max_uses := -1

# --- State ---
## The player who placed this ladder.
var player: Player
## Which loadout slot this ladder came from.
var slot_index := -1
## Optional one-way platform at the top of the ladder (see [method make_top_platform]).
var top_platform: AnimatableBody2D

var _area: Area2D
var _area_shape: CollisionShape2D
var _players_inside: Array[Player] = []


# ---------------------------------------------------------------------------
# Virtual methods - override these in ladder types
# ---------------------------------------------------------------------------

## Called right after the ladder is added to the level. Position the ladder and set it up.
## Return false to cancel (the ladder is then deleted and nothing happens).
func deploy(_p: Player) -> bool:
	return true

## Called every physics frame while the use button stays held after deploying.
func use_held(_delta: float) -> void:
	pass

## Called once when the use button is released after deploying.
func use_released() -> void:
	pass

## Called when the player presses use while touching an already-placed ladder of this same type.
## Return true to "reuse" this ladder instead of placing a new one (it then gets use_held/use_released).
func try_reuse(_p: Player) -> bool:
	return false

## Called every physics frame while the player overlaps this ladder, before the player moves.
func on_player_inside(_p: Player, _delta: float) -> void:
	pass

## Draws this ladder's hotbar icon onto [param ci] inside [param rect]. Override to use the
## ladder's art (see LadderIcons). Default: a plain square in hud_color.
func draw_hud_icon(ci: CanvasItem, rect: Rect2) -> void:
	ci.draw_rect(rect.grow(-rect.size.x * 0.2), hud_color)

## Removes the ladder from the level. Override for a removal animation if you want.
func remove() -> void:
	queue_free()

## Only called while this ladder is the player's controller (see [method Player.set_controller]).
## Set the player's velocity here instead of the normal walking code; move_and_slide runs after.
func control_player(_p: Player, _delta: float) -> void:
	pass

## Called right after the player's move_and_slide while this ladder is the controller.
func after_player_moved(_p: Player, _delta: float) -> void:
	pass


# ---------------------------------------------------------------------------
# Helpers for subclasses
# ---------------------------------------------------------------------------

## Sets the trigger area (the zone where the player counts as "touching" this ladder).
## The rect is in local coordinates; the ladder's origin is where it meets the ground.
func set_area_rect(rect: Rect2) -> void:
	var shape := _area_shape.shape as RectangleShape2D
	shape.size = rect.size
	_area_shape.position = rect.get_center()
	_area_shape.set_deferred("disabled", false)

## Uses left for this ladder's loadout slot (-1 = unlimited).
func uses_left() -> int:
	return player.inventory.get_uses_left(slot_index) if player else -1

func consume_uses(amount := 1) -> void:
	if player:
		player.inventory.consume_uses(slot_index, amount)

# Enemies: tbd

## Gap in pixels between the player's hitbox and this ladder's area (0 if they overlap).
## Used by the pickup key.
func distance_to_body(p: Player) -> float:
	var shape := _area_shape.shape as RectangleShape2D
	var mine := Rect2(_area_shape.global_position - shape.size / 2.0, shape.size)
	var half := p.get_half_size()
	var theirs := Rect2(p.global_position - half, half * 2.0)
	var dx := maxf(0.0, maxf(mine.position.x - theirs.end.x, theirs.position.x - mine.end.x))
	var dy := maxf(0.0, maxf(mine.position.y - theirs.end.y, theirs.position.y - mine.end.y))
	return Vector2(dx, dy).length()

## Creates a one-way platform the player can stand on (e.g. the top of a climbable ladder).
## It's an AnimatableBody2D so moving it (extending the ladder) carries the player along.
func make_top_platform(width: float) -> void:
	top_platform = AnimatableBody2D.new()
	top_platform.sync_to_physics = true  # moves as real motion, so it carries the player
	top_platform.collision_layer = WORLD_LAYER
	top_platform.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 8)
	shape.shape = rect
	shape.position = Vector2(0, 4)
	shape.one_way_collision = true
	top_platform.add_child(shape)
	add_child(top_platform)

## Casts a ray against the world (ignores the player and this ladder's own platform).
## Returns the hit dictionary from intersect_ray, empty if nothing was hit.
func raycast(from: Vector2, to: Vector2) -> Dictionary:
	var exclude: Array[RID] = []
	if player:
		exclude.append(player.get_rid())
	if top_platform:
		exclude.append(top_platform.get_rid())
	var query := PhysicsRayQueryParameters2D.create(from, to, WORLD_LAYER, exclude)
	return get_world_2d().direct_space_state.intersect_ray(query)

## Puts the ladder on the ground [param distance] pixels in front of the player.
## If a wall is in the way, it's placed against the wall instead.
## [param half_width] keeps the ladder from going into that wall.
## Returns false if there's no ground within [param max_drop] pixels below the player's feet.
func place_on_ground(distance: float, half_width: float, max_drop := 256.0) -> bool:
	var origin := player.global_position
	var target_x := origin.x + player.facing * distance
	var wall := raycast(origin, Vector2(target_x + player.facing * half_width, origin.y))
	if not wall.is_empty():
		target_x = wall.position.x - player.facing * half_width
	var feet_y := origin.y + player.get_half_size().y
	var ground := raycast(Vector2(target_x, origin.y), Vector2(target_x, feet_y + max_drop))
	if ground.is_empty():
		return false
	global_position = ground.position
	return true


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _notification(what: int) -> void:
	# Done in _notification instead of _ready/_init so subclasses never need to call super().
	match what:
		NOTIFICATION_ENTER_TREE:
			if _area == null:
				_build_area()
		NOTIFICATION_EXIT_TREE:
			if is_instance_valid(player) and player.controller == self:
				player.clear_controller()
			for p in _players_inside:
				if is_instance_valid(p):
					p.ladder_untouched(self)
			_players_inside.clear()

func _build_area() -> void:
	_area = Area2D.new()
	_area.name = "TouchArea"
	_area.collision_layer = LADDER_LAYER
	_area.collision_mask = PLAYER_LAYER
	_area.monitorable = false
	_area_shape = CollisionShape2D.new()
	_area_shape.shape = RectangleShape2D.new()
	_area_shape.disabled = true  # enabled once a subclass calls set_area_rect()
	_area.add_child(_area_shape)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player and body not in _players_inside:
		_players_inside.append(body)
		body.ladder_touched(self)

func _on_body_exited(body: Node2D) -> void:
	if body is Player and body in _players_inside:
		_players_inside.erase(body)
		body.ladder_untouched(self)
