class_name GrenadeLadder
extends Ladder
## The rungs are dynamite. Tapping use pulls one rung off and throw it toward the mouse.
## Hold use (until the ladder over his head starts flashing) to throw the whole ladder as one big bomb.
## Explosions kill enemies(eventually), break tiles marked "breakable" in the TileSet, and knock Ladder Man
## around (blast jumping works). Rungs refill on respawn.


const TEXTURE := preload("res://assets/Ladders/grenadeLadder.png")
# Pixel rows in the source image (see the PNG).
const RUNG_TOP := 16.0       # first dynamite rung starts here
const RUNG_H := 8.0          # each rung is this tall
const RUNG_STEP := 14.0   # distance from one rung to the next
const RAILS_ONLY_TOP := 80.0 # an 8-row slice with just the rails (used where a rung was pulled off)
const STICK_REGION := Rect2(15, 16, 38, 8)   # one rung including its fuse
## Number of dynamite rungs per life (matches the art).
const RUNGS := 5
## How long the explosion flash lasts (seconds).
const EXPLOSION_TIME := 0.35

## On-screen size of the pixel art.
@export var art_scale := 1.5

## Seconds to hold use before releasing throws the whole ladder.
@export var big_bomb_hold_time := 0.6
@export var throw_speed := 650.0
## Seconds from throw until it explodes.
@export var fuse_time := 1.5
## Blast radius of one rung, and extra radius per rung for the big bomb.
@export var blast_radius := 80.0
@export var big_blast_radius_per_rung := 30.0
## How hard the blast pushes Ladder Man (at the center).
@export var player_knockback := 900.0
## Gravity on thrown sticks/bombs (pixels/second²).
@export var throw_gravity := 1400.0
## Extra fuse time for the big bomb (seconds).
@export var big_bomb_extra_fuse := 0.5

enum State { HELD, FLYING, EXPLODING }
var state := State.HELD
var rung_count := 1
var _hold := 0.0
var _fuse := 0.0
var _velocity := Vector2.ZERO
var _resting := false
var _boom_time := 0.0
var _radius := 0.0


func _init() -> void:
	display_name = "Grenade Ladder"
	hud_color = Color(1.0, 0.3, 0.25)
	max_active = 0        # thrown, not placed: no limit on how many are flying
	can_pick_up = false
	max_uses = RUNGS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # keep the pixel art crisp


func deploy(p: Player) -> bool:
	if uses_left() <= 0:
		return false
	global_position = p.global_position
	return true


func use_held(delta: float) -> void:
	if state == State.HELD:
		_hold += delta
		queue_redraw()


func use_released() -> void:
	if state != State.HELD:
		return
	var big := _hold >= big_bomb_hold_time and uses_left() > 1
	rung_count = uses_left() if big else 1
	consume_uses(rung_count)
	_radius = blast_radius if rung_count == 1 else blast_radius + big_blast_radius_per_rung * rung_count
	global_position = player.global_position + Vector2(0, -player.get_half_size().y)
	_velocity = player.get_aim_direction() * throw_speed + player.velocity * 0.5
	state = State.FLYING
	queue_redraw()


func _physics_process(delta: float) -> void:
	match state:
		State.HELD:
			if is_instance_valid(player):
				global_position = player.global_position + Vector2(0, -player.get_half_size().y - TEXTURE.get_height() * art_scale / 2.0)
		State.FLYING:
			_fly(delta)
		State.EXPLODING:
			_boom_time += delta
			queue_redraw()
			if _boom_time > EXPLOSION_TIME:
				queue_free()


func _fly(delta: float) -> void:
	_fuse += delta
	if _fuse >= fuse_time + (big_bomb_extra_fuse if rung_count > 1 else 0.0):
		_explode()
		return
	if _resting:
		queue_redraw()
		return
	_velocity.y += throw_gravity * delta
	var next := global_position + _velocity * delta
	var hit := raycast(global_position, next)
	if hit.is_empty():
		global_position = next
	else:
		global_position = hit.position + hit.normal * 2.0
		_velocity = _velocity.bounce(hit.normal) * 0.35
		if _velocity.length() < 60.0:
			_resting = true
	rotation += _velocity.x * delta * 0.02
	queue_redraw()


func _explode() -> void:
	state = State.EXPLODING
	rotation = 0.0
	TileBreaker.break_around(get_tree(), global_position, _radius)
	if is_instance_valid(player):
		var offset := player.global_position - global_position
		var reach := _radius * 1.4
		if offset.length() < reach:
			var strength := player_knockback * (1.0 - offset.length() / reach) * (1.0 + 0.15 * (rung_count - 1))
			var dir := (offset.normalized() if offset.length() > 1.0 else Vector2.UP) + Vector2(0, -0.6)
			player.launch(dir.normalized() * strength)
	queue_redraw()


func _draw() -> void:
	match state:
		State.HELD:
			# Show the ladder over his head, it flashes once holding long enough to throw the whole ladder.
			var ready_big := _hold >= big_bomb_hold_time and uses_left() > 1
			var flash := ready_big and int(Time.get_ticks_msec() / 80) % 2 == 0
			_draw_bomb_ladder(uses_left(), Color(2.0, 2.0, 2.0) if flash else Color.WHITE)
		State.FLYING:
			if rung_count == 1:
				_draw_stick()
			else:
				_draw_bomb_ladder(rung_count, Color.WHITE)
			# Fuse spark.
			if int(Time.get_ticks_msec() / 60) % 2 == 0:
				draw_circle(Vector2(STICK_REGION.size.x * art_scale / 2.0, -4.0), 3.0, Color.YELLOW)
		State.EXPLODING:
			var t := _boom_time / EXPLOSION_TIME
			draw_circle(Vector2.ZERO, _radius * (0.4 + 0.6 * t), Color(1.0, 0.6, 0.1, 0.8 * (1.0 - t)))
			draw_circle(Vector2.ZERO, _radius * 0.5 * (1.0 - t), Color(1.0, 1.0, 0.7, 1.0 - t))


func _draw_stick() -> void:
	var size := STICK_REGION.size * art_scale
	draw_texture_rect_region(TEXTURE, Rect2(-size / 2.0, size), STICK_REGION)


## Draws the ladder centered on the origin, showing only the bottom [param rungs] rungs.
## Draws on [param ci] (default: this node) at [param s] times the PNG size (default: art_scale).
func _draw_bomb_ladder(rungs: int, tint: Color, ci: CanvasItem = self, s: float = -1.0) -> void:
	if s < 0.0:
		s = art_scale
	var w := TEXTURE.get_width()
	var origin := -TEXTURE.get_size() * s / 2.0
	var bands: Array[Vector2] = []   # (source top row, height) drawn top to bottom
	bands.append(Vector2(0, RUNG_TOP))
	for i in RUNGS:
		var top := RUNG_TOP + i * RUNG_STEP
		var has_rung := i >= RUNGS - rungs
		bands.append(Vector2(top if has_rung else RAILS_ONLY_TOP, RUNG_H))
		var gap_end := RUNG_TOP + (i + 1) * RUNG_STEP if i < RUNGS - 1 else float(TEXTURE.get_height())
		bands.append(Vector2(top + RUNG_H, gap_end - top - RUNG_H))
	var y := 0.0
	for band in bands:
		ci.draw_texture_rect_region(TEXTURE, Rect2(origin + Vector2(0, y * s), Vector2(w, band.y) * s),
			Rect2(0, band.x, w, band.y), tint)
		y += band.y


func draw_hud_icon(ci: CanvasItem, rect: Rect2) -> void:
	# Shows only the rungs left (the HUD sets player/slot_index on its icon copy).
	var left := uses_left()
	if left < 0:
		left = RUNGS
	LadderIcons.fit(ci, rect, Vector2(40, 86))
	_draw_bomb_ladder(left, Color.WHITE, ci, 1.0)
