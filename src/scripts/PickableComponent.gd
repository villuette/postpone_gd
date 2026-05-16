extends InteractableComponent
class_name PickableComponent
@export var item_data: ItemData

func _on_interact_logic(controller: InteractionComponent):
	controller.collect_item(item_data)
	get_parent().queue_free()
