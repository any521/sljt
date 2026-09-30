extends RefCounted
class_name CharacterRules
## The active captain's hand rhythm. CombatManager consumes this data only.

const SHEN_MING := "shen_ming"
const SONG_MEI := "song_mei"

var id: String
var display_name: String
var opening_draw := 5
var turn_draw := 3
var retain_hand := true
var voluntary_discard_limit := 2
var end_turn_hand_limit := 8

func _init(character_id: String = SHEN_MING) -> void:
	id = character_id
	match id:
		SONG_MEI:
			display_name = "宋梅"
			turn_draw = 5
			retain_hand = false
			voluntary_discard_limit = 0
		_:
			id = SHEN_MING
			display_name = "沈明"
