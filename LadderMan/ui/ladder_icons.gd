class_name LadderIcons
extends RefCounted
## Drawing helpers for ladders' hotbar icons (see Ladder.draw_hud_icon).


## Draws [param region] of [param texture] as big as fits inside [param rect].
static func draw_texture(ci: CanvasItem, rect: Rect2, texture: Texture2D, region: Rect2) -> void:
	var s := minf(rect.size.x / region.size.x, rect.size.y / region.size.y)
	var size := region.size * s
	ci.draw_texture_rect_region(texture, Rect2(rect.get_center() - size / 2.0, size), region)


## After this, draw icon shapes centered on (0, 0) in a box of [param content_size]; they get
## scaled to fit [param rect]. (The HUD resets the transform after.)
static func fit(ci: CanvasItem, rect: Rect2, content_size: Vector2) -> void:
	var s := minf(rect.size.x / content_size.x, rect.size.y / content_size.y)
	ci.draw_set_transform(rect.get_center(), 0.0, Vector2(s, s))
