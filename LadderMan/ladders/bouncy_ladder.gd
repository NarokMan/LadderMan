class_name BouncyLadder
extends Ladder
## Thrown flat on the ground in front of the player. Acts like a trampoline: landing on it
## bounces you back up, a bit higher each time you fall onto it from higher up.
## Holding jump while you land gives an extra-big bounce.

const TEXTURE := preload("res://assets/Ladders/bouncyLadder.png")
# Pixel positions in the source image (see the PNG).
const SRC_CENTER_X := 48.0   # horizontal center of the art
const SRC_ART_W := 80.0      # width of the visible art
const SRC_BED_Y := 11.0      # top of the ladder bed (what you land on)
const SRC_BOTTOM := 42.0     # bottom of the springs (sits on the ground)
const SRC_SPRING_TOP := 28.0 # bed is above this row, springs below it

## On-screen size of the art (1.5 = 1.5x the PNG's pixel size).
@export var art_scale := 1.5
## Smallest bounce (when you just walk onto it).
@export var min_bounce := 700.0
## Bounce speed = landing speed * this. Above 1.0 means each bounce gets higher.
@export var restitution := 1.1
## Extra speed added when jump is held as you land.
@export var jump_bonus := 300.0
## Bounce speed cap.
@export var max_bounce := 1600.0
## How much the springs compress when bounced on (0.75 = squashed to a quarter of their height).
@export var squash_amount := 0.75
## How fast the springs recover after a bounce (1 / seconds).
@export var squash_recover_speed := 3.0

var _squish := 0.0


func _init() -> void:
	display_name = "Bouncy Ladder"
	hud_color = Color(0.4, 0.9, 0.5)
	max_active = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # keep the pixel art crisp


func deploy(p: Player) -> bool:
	var half_w := SRC_ART_W * art_scale / 2.0
	if not place_on_ground(p.get_half_size().x + half_w + 8.0, half_w):
		return false
	var bed := (SRC_BOTTOM - SRC_BED_Y) * art_scale
	# Land on the bed instead of sinking through to the ground.
	make_top_platform(half_w * 2.0)
	top_platform.position = Vector2(0, -bed)
	set_area_rect(Rect2(-half_w, -bed - 10.0, half_w * 2.0, bed + 10.0))
	return true


func on_player_inside(p: Player, _delta: float) -> void:
	if not p.is_on_floor():
		return
	var speed := maxf(min_bounce, p.recent_landing_speed() * restitution)
	if p.input.jump_held:
		speed += jump_bonus
	p.launch(Vector2(p.velocity.x, -minf(speed, max_bounce)))
	_squish = 1.0


func _process(delta: float) -> void:
	if _squish > 0.0:
		_squish = maxf(0.0, _squish - delta * squash_recover_speed)
		queue_redraw()


func _draw() -> void:
	# Springs compress toward the ground and the bed drops down with them.
	var s := art_scale
	var tex_w := TEXTURE.get_width()
	var tex_h := TEXTURE.get_height()
	var squash := 1.0 - squash_amount * _squish
	var x := -SRC_CENTER_X * s
	var springs_top := -(SRC_BOTTOM - SRC_SPRING_TOP) * s * squash
	draw_texture_rect_region(TEXTURE,
		Rect2(x, springs_top, tex_w * s, (tex_h - SRC_SPRING_TOP) * s * squash),
		Rect2(0, SRC_SPRING_TOP, tex_w, tex_h - SRC_SPRING_TOP))
	draw_texture_rect_region(TEXTURE,
		Rect2(x, springs_top - SRC_SPRING_TOP * s, tex_w * s, SRC_SPRING_TOP * s),
		Rect2(0, 0, tex_w, SRC_SPRING_TOP))


func draw_hud_icon(ci: CanvasItem, rect: Rect2) -> void:
	LadderIcons.draw_texture(ci, rect, TEXTURE, Rect2(SRC_CENTER_X - SRC_ART_W / 2.0, 8, SRC_ART_W, SRC_BOTTOM - 8))
