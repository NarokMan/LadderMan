extends Node2D

func get_rect() -> Rect2:
	# Extra space above the rails lets the player's center clear the landing.
	return Rect2(-22, -18, 44, 200)

func _draw() -> void:
	for x in [-14, 14]:
		draw_line(Vector2(x, 0), Vector2(x, 180), Color("bb925c"), 5)
	for y in range(5, 180, 16):
		draw_line(Vector2(-14,y), Vector2(14,y), Color("e0bd83"), 4)
