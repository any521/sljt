extends Control
signal option_chosen(deck_index: int)

@export var option_prefab: PackedScene
@onready var title_label: Label = $Panel/Title
@onready var body_label: Label = $Panel/Body
@onready var list_box: GridContainer = $Panel/Scroll/List
@onready var back_button: Button = $Panel/Back

func _ready() -> void:
	back_button.pressed.connect(func(): option_chosen.emit(-1))

func present(title_text: String, body_text: String, cards: Array[CardData], indexes: Array[int], skip_text: String = "暂不操作，继续前进", captions: Array[String] = []) -> void:
	title_label.text = title_text
	body_label.text = body_text
	back_button.text = skip_text
	for old in list_box.get_children(): old.queue_free()
	for index in indexes:
		var card: CardData = cards[index]
		var option: Button = option_prefab.instantiate()
		list_box.add_child(option)
		option.configure(card, captions[index] if index < captions.size() else "选择此牌")
		option.pressed.connect(_choose.bind(index))
	show()

func _choose(index: int) -> void:
	option_chosen.emit(index)
