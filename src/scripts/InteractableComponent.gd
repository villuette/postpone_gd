extends Node
class_name InteractableComponent
@export var hover_name: String = "NULLNAME"

signal interacted()

func interact(controller: InteractionComponent):
	_on_interact_logic(controller)
	

func _on_interact_logic(controller):
	print("_on_interact_logic is empty: ", self)
	#controller.display_dialogue(lines, time_per_line)

func get_hover_text():
	return "Взаимодействовать с: %s" % hover_name
