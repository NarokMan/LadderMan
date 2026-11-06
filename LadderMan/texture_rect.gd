extends TextureRect


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var random_int = randi_range(1, 10)
	print(random_int)
	var mark = load("res://assets/ground_mark.png") as Texture2D
	var blank = load("res://assets/ground_blank.png") as Texture2D
	if(random_int%2 == 0):
		$TextureRect.texture = mark
	else:
		$TextureRect.texture = blank
		
