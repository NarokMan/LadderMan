class_name TileBreaker
extends RefCounted
## Destroys tiles marked "breakable" (TileSet custom data layer) in every TileMapLayer.


## Erases breakable tiles within [param radius] of [param center] (global coords).
static func break_around(tree: SceneTree, center: Vector2, radius: float) -> void:
	for layer in tree.root.find_children("*", "TileMapLayer", true, false):
		var tml := layer as TileMapLayer
		if tml.tile_set == null or not tml.tile_set.has_custom_data_layer_by_name("breakable"):
			continue
		var local := tml.to_local(center)
		var size := tml.tile_set.tile_size
		var reach := Vector2i(ceili(radius / size.x) + 1, ceili(radius / size.y) + 1)
		var middle := tml.local_to_map(local)
		for x in range(middle.x - reach.x, middle.x + reach.x + 1):
			for y in range(middle.y - reach.y, middle.y + reach.y + 1):
				var cell := Vector2i(x, y)
				var data := tml.get_cell_tile_data(cell)
				if data and data.get_custom_data("breakable") and tml.map_to_local(cell).distance_to(local) <= radius:
					tml.erase_cell(cell)
