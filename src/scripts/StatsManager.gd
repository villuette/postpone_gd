class_name StatsManager extends Node


signal stat_changed(type: String, current: float)
signal died
var owning_player

	
func _toggle_stamina_regeneration(running_status: bool):
	is_running = running_status
	
@export_group("Specials")
@export var immortality: bool = false
@export_group("Health")
@export var health_regen_speed: float = 0
@export var max_health = 100

@export_group("Mind")
@export var max_mind = 100

@export_group("Stamina")
@export var is_running = false
@export var max_stamina = 100
@export var stamina_drain_speed: float = 40.0
@export var stamina_regen_speed: float = 5.0

var health: float = max_health:
	set(v):
		health = clamp(v, 0, max_health)
		stat_changed.emit("health", health)
		if health == 0:
			if not immortality:
				died.emit()
			
var mind: float = max_mind:
	set(v):
		mind = clamp(v, 0, max_mind)
		stat_changed.emit("mind", mind)
		
var stamina: float = max_stamina:
	set(v):
		stamina = clamp(v, 0, max_stamina)
		stat_changed.emit("stamina", stamina)
		
func _process(delta: float) -> void:
	if !is_running:
		stamina += delta * stamina_regen_speed
	else:
		stamina -= delta * stamina_drain_speed
	
func damage_by_type(type, damage):
	match type:
		"stamina":
			stamina -=damage
		"health":
			health -=damage
		"mind":
			mind -= damage
