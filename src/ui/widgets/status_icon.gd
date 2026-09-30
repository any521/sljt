extends Panel
## One visible status stack with a plain-language hover explanation.

const DETAILS := {
	"weak": ["弱", "虚弱", "造成的攻击伤害降低 25%。层数每回合减少 1。", Color("d4b7e8")],
	"vulnerable": ["易", "易伤", "受到的攻击伤害提高 50%。层数每回合减少 1。", Color("f0a3a3")],
	"strength": ["力", "力量", "每层使攻击的基础伤害增加 1。", Color("f4ca8c")],
	"dexterity": ["敏", "敏捷", "敏捷状态；当前战斗规则暂未让它影响格挡值。", Color("9cdcc2")],
	"poison": ["腐", "腐蚀", "回合开始时失去等同层数的生命，随后层数减少 1。", Color("a9db8f")],
	"shield": ["盾", "护盾", "先于普通格挡抵消受到的伤害。", Color("99d8f2")],
	"ritual": ["仪", "仪式", "仪式状态；当前战斗规则暂未实现回合增益。", Color("e1b8e9")],
}

func configure(status_key: String, stacks: int) -> void:
	var info: Array = DETAILS.get(status_key, ["?", status_key, "当前状态层数。", Color.WHITE])
	$Symbol.text = info[0]
	$Stacks.text = str(stacks)
	$Symbol.add_theme_color_override("font_color", info[3])
	tooltip_text = "%s · %d 层\n%s" % [info[1], stacks, info[2]]
