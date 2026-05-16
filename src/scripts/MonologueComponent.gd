extends InteractableComponent
class_name MonologueComponent
@export_group("Monologue")
@export var lines: Array[String] = ["Это просто коробка.", "В ней ничего нет...", "Уходи."]
@export var time_per_line: float = 1.5

func _on_interact_logic(controller):
	controller.display_dialogue(lines, time_per_line)
