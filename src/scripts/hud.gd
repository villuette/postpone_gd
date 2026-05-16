extends Control
class_name Hud
# В скрипте интерфейса (например, StatsBars.gd или HUD.gd)
@onready var interaction_label = $InteractionLabel
@onready var predictive_crosshair = $predictive_crosshair
@export var subtitles_label: Label

func update_interaction_hint(text: String):
	interaction_label.text = text
	interaction_label.visible = text != ""


func update_predictive_crosshair_position(hit_world_point: Vector3):
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return

	var screen_pos = camera.unproject_position(hit_world_point)
	predictive_crosshair.position = screen_pos - (predictive_crosshair.size / 2)


func _on_interaction_component_subtitles_updated(text: String) -> void:
	subtitles_label.text = text
