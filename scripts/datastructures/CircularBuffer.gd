class_name CircularBuffer

## Data structure that loops around itself and overwrites data once it reaches the end

var BUFFER_SIZE : int
var items = []

func _init(buffer_size: int):
	BUFFER_SIZE = buffer_size
	items.resize(BUFFER_SIZE)

func insert_item(position: int, data) -> void:
	items[position % BUFFER_SIZE] = data

func get_item(position: int):
	return items[position % BUFFER_SIZE]

func remove_at(position: int):
	items[position % BUFFER_SIZE] = null
