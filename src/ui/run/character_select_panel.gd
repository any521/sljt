extends Control
signal character_chosen(character_id: String)

func _ready() -> void:
	$Panel/ShenMing.pressed.connect(func(): character_chosen.emit(CharacterRules.SHEN_MING))
	$Panel/SongMei.pressed.connect(func(): character_chosen.emit(CharacterRules.SONG_MEI))
