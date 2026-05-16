extends Node
class_name DoTController
signal apply_dot_damage(type, value)

@export var damage_interval: float = 1.0
@export var damage_amount: float = 5.0
var has_mind_yet = true
func _ready() -> void:
	# Создаем таймер прямо в коде, чтобы не плодить узлы в дереве
	var timer: Timer = Timer.new()
	add_child(timer)
	timer.wait_time = damage_interval
	timer.autostart = true
	timer.timeout.connect(on_timer_tick)
	timer.start()


#func on_stats_changed(type, value):
	#if type == "mind" and value <= 0:
		#has_mind_yet = false
		
		
func on_timer_tick(): 
	if has_mind_yet:
		apply_dot_damage.emit("mind", damage_amount)
	else:
		apply_dot_damage.emit("health", damage_amount)	
		


func _on_stats_manager_stat_changed(type: String, current: float) -> void:
	if type == "mind" and current <= 0:
		has_mind_yet = false
