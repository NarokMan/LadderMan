@tool
class_name RopePivot
extends Node2D
## A hook point the Rope Ladder can hang from. Drop rope_pivot.tscn into a level wherever you
## want a swing point. Uses the ring from the rope ladder art.

const TEXTURE := preload("res://assets/Ladders/ropeLadder.png")
const RING_REGION := Rect2(560, 76, 134, 116)   # the ring in the rope ladder PNG

## On-screen size of the ring. A rope ladder hung here uses the same scale.
@export var art_scale := 0.2:
	set(value):
		art_scale = value
		queue_redraw()


func _ready() -> void:
	add_to_group("rope_pivots")


func _draw() -> void:
	var pos := (RING_REGION.position - RopeLadder.RING_CENTER) * art_scale
	draw_texture_rect_region(TEXTURE, Rect2(pos, RING_REGION.size * art_scale), RING_REGION)
