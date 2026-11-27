class_name ExtensionLadder
extends Ladder
## Placed standing up in front of the player as just the lower section, with the upper section
## hidden inside. Hold the use button and the upper section telescopes out of the lower one. Climb it with up/down; the top is a platform you can stand on.
## Extending while standing on top lifts you up like an elevator. Press use again while touching it to extend it more.


const TEXTURE := preload("res://assets/Ladders/extensionLadder.png")
# Pixel rows/columns in the source image (see the PNG).
const SRC_X := 64.0            # left edge of the ladder art
const SRC_W := 128.0           # width of the ladder art
const UPPER_TOP := 8.0         # top of the upper section's rail tips
const UPPER_BASE_END := 144.0  # upper section is drawn as-is down to here...
const SEGMENT_TOP := 36.0      # ...then this rung+gap slice repeats as it extends
const SEGMENT_H := 56.0
const LOWER_TOP := 164.0       # lower section starts here
const LOWER_BOTTOM := 372.0    # and ends here (sits on the ground)

## On-screen size of the art (0.5 = half the PNG's pixel size).
@export var art_scale := 0.5
## How far the upper section can slide out, in pixels. Set to INF for no limit.
@export var max_extension := 302.0
## How fast it extends while use is held (pixels/second).
@export var extend_speed := 240.0

var extension := 0.0
var height := 0.0
var _extending := false


func _init() -> void:
	display_name = "Extension Ladder"
	hud_color = Color(0.95, 0.75, 0.35)
	climbable = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # keep the pixel art crisp


func get_width() -> float:
	return SRC_W * art_scale

## Height with the upper section fully hidden.
func get_retracted_height() -> float:
	return (LOWER_BOTTOM - LOWER_TOP) * art_scale


func deploy(p: Player) -> bool:
	# Place it overlapping the player's front edge so they can climb right away.
	if not place_on_ground(p.get_half_size().x, get_width() / 2.0):
		return false
	# Not enough headroom for even the retracted ladder.
	if not raycast(global_position + Vector2(0, -2), global_position + Vector2(0, -get_retracted_height())).is_empty():
		return false
	make_top_platform(get_width() + 16.0)
	_set_extension(0.0)
	_extending = true
	return true


func use_held(delta: float) -> void:
	if _extending:
		_set_extension(extension + extend_speed * delta)


func use_released() -> void:
	_extending = false


func try_reuse(_p: Player) -> bool:
	_extending = extension < max_extension
	return true


func _set_extension(value: float) -> void:
	value = clampf(value, extension, max_extension)
	var base := get_retracted_height()
	# Stop at ceilings.
	var top := global_position + Vector2(0, -base - extension - 2.0)
	var hit := raycast(top, global_position + Vector2(0, -base - value - 4.0))
	if not hit.is_empty():
		value = maxf(extension, global_position.y - hit.position.y - 4.0 - base)
		_extending = false
	if value >= max_extension:
		_extending = false
	extension = value
	height = base + extension
	top_platform.position = Vector2(0, -height)
	# Area pokes a little above the top so standing on top still counts as touching.
	set_area_rect(Rect2(-get_width() / 2.0, -height - 8.0, get_width(), height + 8.0))
	queue_redraw()


func _draw() -> void:
	var s := art_scale
	var x := -get_width() / 2.0
	var w := get_width()
	var lower_h := get_retracted_height()

	# Upper section (behind): fixed top part, then repeated segments, clipped where it
	# disappears into the lower section. When fully retracted nothing of it is drawn.
	var y := -height
	var src_top := UPPER_TOP
	var src_end := UPPER_BASE_END
	while y < -lower_h - 0.01:
		var h := minf((src_end - src_top) * s, -lower_h - y)
		draw_texture_rect_region(TEXTURE, Rect2(x, y, w, h), Rect2(SRC_X, src_top, SRC_W, h / s))
		y += h
		src_top = SEGMENT_TOP
		src_end = SEGMENT_TOP + SEGMENT_H

	# Lower section (in front), standing on the ground.
	draw_texture_rect_region(TEXTURE, Rect2(x, -lower_h, w, lower_h), Rect2(SRC_X, LOWER_TOP, SRC_W, LOWER_BOTTOM - LOWER_TOP))


func draw_hud_icon(ci: CanvasItem, rect: Rect2) -> void:
	LadderIcons.draw_texture(ci, rect, TEXTURE, Rect2(SRC_X, UPPER_TOP, SRC_W, LOWER_BOTTOM - UPPER_TOP))
