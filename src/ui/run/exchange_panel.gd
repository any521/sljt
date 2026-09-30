extends Control
signal choice_made(index: int)

@onready var rows: Array[Button] = [$Panel/Rows/Exchange0, $Panel/Rows/Exchange1]

func _ready() -> void:
	for i in rows.size():
		rows[i].pressed.connect(func(): choice_made.emit(i))
	$Panel/Leave.pressed.connect(func(): choice_made.emit(2))

func present(sources: Array[CardData], targets: Array[CardData], owned_counts: Array[int]) -> void:
	for i in rows.size():
		rows[i].configure(sources[i], targets[i], owned_counts[i])
	show()
