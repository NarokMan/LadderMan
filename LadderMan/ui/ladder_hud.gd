extends CanvasLayer
## Ladder hotbar at the bottom of the screen: one slot per ladder in the player's loadout.
## Each ladder draws its own icon (see Ladder.draw_hud_icon).

@export var player_path: NodePath

## Slot sizes in pixels.
const SLOT_SIZE := 56.0
const SELECTED_SIZE := 84.0
const GAP := 8.0
const PADDING := 10.0
const BOTTOM_MARGIN := 16.0
const BACKGROUND := Color(0, 0, 0, 0.55)
## How fast slots grow/shrink when the selection changes.
const ANIM_SPEED := 14.0

var _player: Player
var _inventory: LadderInventory
var _selected := 0
var _bar: Control
var _slots: Array[Control] = []
var _sizes: Array[float] = []
var _panel := Rect2()


class Bar extends Control:
	var hud: Node
	func _draw() -> void:
		hud.draw_bar(self)


class Slot extends Control:
	var hud: Node
	var index := 0
	func _draw() -> void:
		hud.draw_slot(self, index)


func _ready() -> void:
	_player = get_node_or_null(player_path) as Player
	_bar = Bar.new()
	_bar.hud = self
	_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	if _player == null:
		return
	_inventory = _player.inventory
	_selected = _inventory.selected_index
	_inventory.selection_changed.connect(func(i: int) -> void: _selected = i)
	for i in _inventory.size():
		var proto := _inventory.get_prototype(i)
		var slot := Slot.new()
		slot.hud = self
		slot.index = i
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Pixel-art ladders stay crisp; smooth art gets smooth filtering.
		slot.texture_filter = proto.texture_filter
		if proto.texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE:
			slot.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_bar.add_child(slot)
		_slots.append(slot)
		_sizes.append(SLOT_SIZE)


func _process(delta: float) -> void:
	if _player == null or _slots.is_empty():
		return
	var t := 1.0 - exp(-ANIM_SPEED * delta)
	var width := PADDING * 2.0 + GAP * (_slots.size() - 1)
	for i in _slots.size():
		var target := SELECTED_SIZE if i == _selected else SLOT_SIZE
		_sizes[i] = lerpf(_sizes[i], target, t)
		width += _sizes[i]
	var height := SELECTED_SIZE + PADDING * 2.0
	var screen := _bar.size
	_panel = Rect2((screen.x - width) / 2.0, screen.y - BOTTOM_MARGIN - height, width, height)

	# Slots sit on the bottom of the bar, so the selected one grows upward.
	var x := _panel.position.x + PADDING
	for i in _slots.size():
		var s := _sizes[i]
		_slots[i].position = Vector2(x, _panel.end.y - PADDING - s)
		_slots[i].size = Vector2(s, s)
		_slots[i].queue_redraw()
		x += s + GAP
	_bar.queue_redraw()


func draw_bar(ci: Control) -> void:
	if _player == null or _slots.is_empty():
		return
	ci.draw_rect(_panel, BACKGROUND)
	# Selected ladder's name above the bar.
	var proto := _inventory.get_prototype(_selected)
	var font := ThemeDB.fallback_font
	var text := proto.display_name
	var pos := Vector2(_panel.position.x, _panel.position.y - 12.0)
	ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, _panel.size.x, 20, 6, Color.BLACK)
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, _panel.size.x, 20, proto.hud_color.lightened(0.3))
	# Small controls reminder in the top-left corner.
	var hint := "Q/E, 1-%d or scroll: switch    F / click: use (hold: extend / big throw)    R: pick up\nW/S: climb    A/D: walk / pump swing    Space: jump / let go    Mouse: aim" % _slots.size()
	ci.draw_multiline_string_outline(font, Vector2(16, 28), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, -1, 4, Color.BLACK)
	ci.draw_multiline_string(font, Vector2(16, 28), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, -1, Color(1, 1, 1, 0.7))


func draw_slot(ci: Control, i: int) -> void:
	var proto := _inventory.get_prototype(i)
	var rect := Rect2(Vector2.ZERO, ci.size)
	var selected := i == _selected
	var uses := _inventory.get_uses_left(i)
	var font := ThemeDB.fallback_font

	ci.draw_rect(rect, Color(1, 1, 1, 0.08))
	if selected:
		ci.draw_rect(rect.grow(-1.5), proto.hud_color, false, 3.0)

	# Icon (dimmed when out of uses).
	ci.modulate.a = 0.35 if uses == 0 else 1.0
	proto.draw_hud_icon(ci, rect.grow(-rect.size.x * 0.14))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

	# Number key (top-left) and uses left (bottom-right).
	ci.draw_string_outline(font, Vector2(4, 14), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color.BLACK)
	ci.draw_string(font, Vector2(4, 14), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.8))
	if uses >= 0:
		var pos := Vector2(0, rect.size.y - 5.0)
		ci.draw_string_outline(font, pos, str(uses), HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 5.0, 16, 4, Color.BLACK)
		ci.draw_string(font, pos, str(uses), HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 5.0, 16, Color.WHITE)
