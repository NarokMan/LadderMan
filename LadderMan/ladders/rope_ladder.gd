class_name RopeLadder
extends Ladder
## Only works near a hook point (RopePivot) placed in the level. Press use and the rope ladder
## hooks onto the pivot closest to where you're aiming (within range). If you're within reach of
## the rope you grab it straight away and swing; otherwise it just hangs there for you to jump to.
##
## While swinging: A/D pump the swing, W/S climb up/down the rope (shorter rope = faster swing),
## Space lets go and keeps your momentum. Hold W while touching a hanging rope to grab it.

const TEXTURE := preload("res://assets/Ladders/ropeLadder.png")
# Pixel positions in the source image (see the PNG).
const RING_CENTER := Vector2(627, 140)  # the hook ring; the ladder's origin sits here
const SRC_X := 476.0
const SRC_W := 302.0
const HEAD_TOP := 188.0     # rope starts just below the ring
const SEGMENT_TOP := 546.0  # one rung + rope, repeated to make the ladder longer
const SEGMENT_H := 135.0
const TAIL_TOP := 1083.0    # last rung and rope ends
const TAIL_END := 1180.0

## On-screen size of the art (0.2 = a fifth of the PNG's size).
@export var art_scale := 0.2
## How many repeated rung sections make up the ladder (sets its length).
@export var segments := 8
## Max distance from the player to a pivot for the rope to reach it.
@export var throw_range := 450.0
## Shortest you can climb the rope to.
@export var min_length := 40.0
@export var climb_speed := 160.0
## How hard A/D pump the swing (pixels/second²).
@export var pump_strength := 300.0
## Air resistance on the swing.
@export var swing_damping := 0.1
## Extra upward speed when letting go.
@export var release_boost := 150.0
## How fast a rope stops swinging
@export var idle_damping := 1.5
## Furthest the swing can go from straight down (radians)
const MAX_SWING_ANGLE := PI * 0.7

var theta := 0.0     # angle from straight down, radians (positive = swung to the right)
var omega := 0.0     # angular speed
var length := 0.0    # distance from pivot to the player while held
var _regrab_cooldown := 0.0


func _init() -> void:
	display_name = "Rope Ladder"
	hud_color = Color(0.9, 0.7, 0.4)


func get_rope_length() -> float:
	return (TAIL_END - RING_CENTER.y + SEGMENT_H * segments - (TAIL_TOP - SEGMENT_TOP)) * art_scale

func get_max_hang() -> float:
	return get_rope_length() - 20.0

func get_width() -> float:
	return SRC_W * art_scale


func deploy(p: Player) -> bool:
	var pivot := _find_pivot(p)
	if pivot == null:
		return false
	global_position = pivot.global_position
	if pivot is RopePivot:
		art_scale = pivot.art_scale  # the ring and the rope always match
	var top := (HEAD_TOP - RING_CENTER.y) * art_scale
	set_area_rect(Rect2(-get_width() / 2.0, top, get_width(), get_rope_length() - top))
	var offset := p.global_position - global_position
	if offset.length() <= get_max_hang():
		grab(p)
	return true


func _find_pivot(p: Player) -> Node2D:
	# Prefer the pivot closest to where the player is aiming.
	var aim_point := p.global_position + p.get_aim_direction() * 200.0
	var best: Node2D
	var best_score := INF
	for node in get_tree().get_nodes_in_group("rope_pivots"):
		var pv := node as Node2D
		if pv == null or pv.global_position.distance_to(p.global_position) > throw_range:
			continue
		var score := pv.global_position.distance_to(aim_point)
		if score < best_score:
			best = pv
			best_score = score
	return best


func grab(p: Player) -> void:
	var offset := p.global_position - global_position
	length = clampf(offset.length(), min_length, get_max_hang())
	theta = atan2(offset.x, offset.y)
	# Keep the player's momentum along the swing direction.
	omega = p.velocity.dot(Vector2(cos(theta), -sin(theta))) / length
	p.set_controller(self)


func release(p: Player) -> void:
	p.launch(Vector2(cos(theta), -sin(theta)) * omega * length + Vector2(0, -release_boost))
	_regrab_cooldown = 0.3


func on_player_inside(p: Player, _delta: float) -> void:
	if p.controller == null and _regrab_cooldown <= 0.0 and p.input.move.y < 0.0:
		grab(p)


func control_player(p: Player, delta: float) -> void:
	if p.input.jump_pressed:
		release(p)
		return
	length = clampf(length + p.input.move.y * climb_speed * delta, min_length, get_max_hang())
	var pump := p.input.move.x
	omega += (-p.get_gravity().y * sin(theta) + pump * pump_strength) / length * delta
	omega *= 1.0 - swing_damping * delta
	theta += omega * delta
	## Don't swing up past the pivot.
	if absf(theta) > MAX_SWING_ANGLE:
		theta = clampf(theta, -MAX_SWING_ANGLE, MAX_SWING_ANGLE)
		omega = 0.0
	var target := global_position + Vector2(sin(theta), cos(theta)) * length
	p.velocity = (target - p.global_position) / delta


func after_player_moved(p: Player, _delta: float) -> void:
	if p.get_slide_collision_count() == 0:
		return
	# Bumped into something: sync to where the player actually ended up and lose most of the speed.
	var offset := p.global_position - global_position
	theta = atan2(offset.x, offset.y)
	length = clampf(offset.length(), min_length, get_max_hang())
	omega *= 0.3


func _physics_process(delta: float) -> void:
	_regrab_cooldown -= delta
	var held := is_instance_valid(player) and player.controller == self
	if not held:
		# Hanging free: swing back down to rest.
		var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
		omega += -gravity * sin(theta) / get_rope_length() * delta
		omega *= 1.0 - idle_damping * delta
		theta += omega * delta
	rotation = -theta


func _draw() -> void:
	var s := art_scale
	var x := (SRC_X - RING_CENTER.x) * s
	var w := SRC_W * s
	var y := (HEAD_TOP - RING_CENTER.y) * s
	var pieces := [Vector2(HEAD_TOP, SEGMENT_TOP)]
	for i in segments:
		pieces.append(Vector2(SEGMENT_TOP, SEGMENT_TOP + SEGMENT_H))
	pieces.append(Vector2(TAIL_TOP, TAIL_END))
	for piece in pieces:
		var h: float = (piece.y - piece.x) * s
		draw_texture_rect_region(TEXTURE, Rect2(x, y, w, h), Rect2(SRC_X, piece.x, SRC_W, piece.y - piece.x))
		y += h


func draw_hud_icon(ci: CanvasItem, rect: Rect2) -> void:
	LadderIcons.draw_texture(ci, rect, TEXTURE, Rect2(SRC_X, 76, SRC_W, TAIL_END - 76))
