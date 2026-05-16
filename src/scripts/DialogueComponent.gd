extends InteractableComponent
class_name DialogueComponent
@export_group("Dialogue")
var dialogue_data = null
func _on_interact_logic(controller: InteractionComponent):
	print("do some dialog stuff")
	controller.controller_dialog_start(dialogue_data)
