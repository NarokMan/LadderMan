class_name SpeedLadder
extends Ladder
## A sports-style agility ladder laid flat on the ground, pointing the way the player faces.
## Running over it gives a speed boost in the direction of the arrows.

## Placeholder art.
const RAIL_COLOR := Color(0.45, 0.28, 0.13)
const RUNG_SPACING := 24.0

## Length of the ladder lying on the ground.
@export var length := 192.0
## Run speed multiplier while boosted.
@export var boost_multiplier := 2.5
## How long the boost lasts after leaving the ladder (seconds).
@export var boost_duration := 1.2

## 1 = arrows point right, -1 = arrows point left.
var direction := 1.0


## Player movement modifier (see Player.set_movement_modifier): forces horizontal speed of
## Player.SPEED * multiplier in one direction for a while.
class SpeedBoost:
	var direction: float
	var multiplier: float
	var time_left: float

	func _init(dir: float, mult: float, duration: float) -> void:
		direction = dir
		multiplier = mult
		time_left = duration

	func modify_velocity(p: Player, delta: float) -> bool:
		time_left -= delta
		if p.input.move.x == -direction:
			return false  # pushing against the boost cancels it
		p.velocity.x = direction * Player.SPEED * multiplier
		return time_left > 0.0


func _init() -> void:
	display_name = "Speed Ladder"
	hud_color = Color(0.35, 0.7, 1.0)
	max_active = 2


func deploy(p: Player) -> bool:
	direction = p.facing
	if not place_on_ground(p.get_half_size().x + length / 2.0 + 8.0, length / 2.0):
		return false
	set_area_rect(Rect2(-length / 2.0, -20.0, length, 20.0))
	queue_redraw()
	return true


func on_player_inside(p: Player, _delta: float) -> void:
	if p.is_on_floor():
		p.set_movement_modifier(&"speed_boost", SpeedBoost.new(direction, boost_multiplier, boost_duration))


func _draw() -> void:
	var rungs := _draw_flat_ladder(12.0)
	# arrow between each pair of rungs.
	for i in range(rungs.size() - 1):
		var cx := (rungs[i] + rungs[i + 1]) / 2.0
		var tip := Vector2(cx + direction * 5.0, -6.0)
		draw_line(Vector2(cx - direction * 4.0, -11.0), tip, Color.WHITE, 2.5)
		draw_line(Vector2(cx - direction * 4.0, -1.0), tip, Color.WHITE, 2.5)


## Draws the ladder lying flat on the ground, centered on the origin.
## Returns the x position of each rung.
func _draw_flat_ladder(thickness: float) -> PackedFloat32Array:
	var half := length / 2.0
	var rungs := PackedFloat32Array()
	var x := -half + RUNG_SPACING / 2.0
	while x < half:
		draw_line(Vector2(x, -thickness), Vector2(x, 0), hud_color, 5.0)
		rungs.append(x)
		x += RUNG_SPACING
	draw_line(Vector2(-half, -thickness), Vector2(half, -thickness), RAIL_COLOR, 5.0)
	draw_line(Vector2(-half, -2), Vector2(half, -2), RAIL_COLOR, 5.0)
	return rungs


func draw_hud_icon(ci: CanvasItem, rect: Rect2) -> void:
	# Flat ladder seen from above with arrows.
	LadderIcons.fit(ci, rect, Vector2(64, 64))
	var rail := hud_color.darkened(0.35)
	ci.draw_line(Vector2(-30, -14), Vector2(30, -14), rail, 5.0)
	ci.draw_line(Vector2(-30, 14), Vector2(30, 14), rail, 5.0)
	for x in [-28.0, -9.0, 10.0, 28.0]:
		ci.draw_line(Vector2(x, -14), Vector2(x, 14), hud_color, 4.0)
	for x in [-18.0, 1.0, 20.0]:
		ci.draw_polyline([Vector2(x - 4, -7), Vector2(x + 4, 0), Vector2(x - 4, 7)], Color.WHITE, 3.0)
