class_name LadderInventory
extends Node
## The player's ladders: the loadout, which one is selected, the ladders currently placed in the
## level, and uses left for limited ladders. Lives as a child of the Player, which calls [method update] every physics frame.
## Selection: next/prev_ladder actions (Q/E), number keys 1-9, mouse wheel.

## Emitted when the selected ladder changes (for UI).
signal selection_changed(index: int)

## Ladder scenes this player can use, in HUD order.
@export var loadout: Array[PackedScene] = []
## Max gap in pixels between the player and a placed ladder for the pickup key to remove it.
@export var pickup_radius := 96.0

var selected_index := 0

var _player: Player
var _prototypes: Array[Ladder] = []  ## one un-placed instance per slot: config + HUD icons
var _active := {}     ## slot -> Array[Ladder] placed in the level, oldest first
var _uses_left := {}  ## slot -> uses remaining (only ladders with max_uses >= 0)
var _held: Ladder     ## ladder receiving use_held() while the use button is down


func _ready() -> void:
	_player = get_parent() as Player
	for i in loadout.size():
		var proto := loadout[i].instantiate() as Ladder
		proto.player = _player  # lets icons read state like uses left
		proto.slot_index = i
		_prototypes.append(proto)
	refill_uses()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for proto in _prototypes:
			proto.free()


func update(input: PlayerInput, delta: float) -> void:
	if loadout.is_empty():
		return
	if input.next_pressed:
		select(selected_index + 1)
	if input.prev_pressed:
		select(selected_index - 1)

	if input.use_pressed:
		_held = _use_selected()
	if is_instance_valid(_held):
		if input.use_held:
			_held.use_held(delta)
		else:
			_held.use_released()
			_held = null

	if input.pickup_pressed:
		_pick_up_nearest()


func _unhandled_input(event: InputEvent) -> void:
	# Mouse wheel scrolls through the hotbar.
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select(selected_index + 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			select(selected_index - 1)
	# Number keys 1-9 jump straight to a slot.
	if event is InputEventKey and event.pressed and not event.echo:
		var slot: int = event.physical_keycode - KEY_1
		if slot >= 0 and slot < mini(9, loadout.size()):
			select(slot)


func select(index: int) -> void:
	if loadout.is_empty():
		return
	selected_index = posmod(index, loadout.size())
	selection_changed.emit(selected_index)


func size() -> int:
	return loadout.size()


## An un-placed instance of the ladder in [param slot], for reading its config or drawing its icon.
func get_prototype(slot: int) -> Ladder:
	return _prototypes[slot]


## Ladders from [param slot] currently in the level, oldest first.
func get_placed(slot: int) -> Array[Ladder]:
	var result: Array[Ladder] = []
	for ladder in _active.get(slot, []):
		if is_instance_valid(ladder) and not ladder.is_queued_for_deletion():
			result.append(ladder)
	return result


func count_active(slot: int) -> int:
	return get_placed(slot).size()


## Uses left for a slot, or -1 if that ladder has unlimited uses.
func get_uses_left(slot: int) -> int:
	return _uses_left.get(slot, -1)


func consume_uses(slot: int, amount: int) -> void:
	if _uses_left.has(slot):
		_uses_left[slot] = maxi(0, _uses_left[slot] - amount)


## Resets limited-use ladders (grenade ladder) to full.
func refill_uses() -> void:
	_uses_left.clear()
	for i in _prototypes.size():
		if _prototypes[i].max_uses >= 0:
			_uses_left[i] = _prototypes[i].max_uses


func _use_selected() -> Ladder:
	for ladder in _player.get_touching():
		if ladder.slot_index == selected_index and ladder.try_reuse(_player):
			return ladder

	var ladder := loadout[selected_index].instantiate() as Ladder
	ladder.player = _player
	ladder.slot_index = selected_index
	_player.get_parent().add_child(ladder)
	if not ladder.deploy(_player):
		ladder.queue_free()
		return null

	var placed := get_placed(selected_index)
	placed.append(ladder)
	if ladder.max_active > 0 and placed.size() > ladder.max_active:
		placed.pop_front().remove()
	_active[selected_index] = placed
	return ladder


func _pick_up_nearest() -> void:
	var best: Ladder
	var best_dist := pickup_radius
	for slot in _active:
		for ladder in get_placed(slot):
			if ladder.can_pick_up:
				var dist := ladder.distance_to_body(_player)
				if dist <= best_dist:
					best = ladder
					best_dist = dist
	if best:
		best.remove()
