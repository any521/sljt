extends Node2D
## 入口 —— 构建战斗界面并驱动 CombatManager
##
## 接线原则：UI 只监听 CombatManager 的信号，绝不反向调用其内部状态。
## CombatManager 完全不认识 UI，因此战斗规则可以脱离画面独立测试。

const COMBAT_VIEW := preload("res://src/ui/combat_view.gd")

var view: Control


func _ready() -> void:
	view = get_node_or_null("CombatView") as Control
	if view == null:
		view = COMBAT_VIEW.new()
		add_child(view)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		view.restart()
