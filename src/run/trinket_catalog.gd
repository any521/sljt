extends RefCounted
class_name TrinketCatalog
## Chapter-one passive items. IDs are stored in RunState and applied by CombatManager.

const FIELD_DRESSING := "field_dressing"
const SPARE_CAPACITOR := "spare_capacitor"
const CERAMIC_PLATE := "ceramic_plate"
const IDS := [FIELD_DRESSING, SPARE_CAPACITOR, CERAMIC_PLATE]

static func info(id: String) -> Dictionary:
	match id:
		FIELD_DRESSING: return {"name": "宋梅的急救贴", "price": 90, "description": "每次战斗胜利后恢复 4 点生命。"}
		SPARE_CAPACITOR: return {"name": "备用电容", "price": 100, "description": "每场战斗首回合额外获得 1 点能量。"}
		CERAMIC_PLATE: return {"name": "陶瓷护板", "price": 85, "description": "每场战斗开始时获得 4 点格挡。"}
	return {}
