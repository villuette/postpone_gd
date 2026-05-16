class_name InteractionComponent extends Node


signal interaction_label_updated(text: String)
signal subtitles_updated(text: String) #TODO Subtitles object
signal item_picked_up(data: ItemData)
signal dialogue_started(dialogue_data)
@export var pickup_raycast: RayCast3D
@export var pickup_shapecast: ShapeCast3D
@onready var interact_key = InputMap.action_get_events("pick")[0].as_text().replace(" (Physical)", "")


func _physics_process(delta: float) -> void:
	_check_interaction()
	
func _find_interaction_in_target(node):
	# 1. Может мы попали прямо в узел с компонентом?
	for child in node.get_children():
		if child is InteractableComponent:
			return child
	
	# 2. Если нет, может компонент лежит рядом с нами у родителя?
	var parent = node.get_parent()
	if parent:
		for child in parent.get_children():
			if child is InteractableComponent:
				return child
				
	return null
	
func _check_interaction():
	# По умолчанию прячем подсказку
	var hint_text = ""
	#if pickup_shapecast.get_collider()
	if pickup_raycast.is_colliding():
		var target = pickup_raycast.get_collider()
		if not target: return
		#print("interactable target: ", target)
		var interactable = _find_interaction_in_target(target)
		if interactable is InteractableComponent:
			hint_text = "[%s] - %s" % [interact_key, interactable.get_hover_text()]
		#if target is PickableItem:
			## Если нашли предмет — формируем строку
			#hint_text = "[%s] - Поднять %s" % [interact_key, target.item_data.title]

	# Отправляем в HUD (через твой stats_ui или напрямую)
	interaction_label_updated.emit(hint_text)
	#screen_overlay_ui.update_interaction_hint(hint_text)

func process_interaction():
	if not pickup_raycast.is_colliding():
		return
	var target = pickup_raycast.get_collider()
	if not target: return
	var interactable = _find_interaction_in_target(target)
	if interactable:
		interactable.interact(self)


var _is_dialogue_playing: bool = false


func display_dialogue(lines: Array[String], delay: float):
	if _is_dialogue_playing: return
	
	_is_dialogue_playing = true
	
	for line in lines:
		subtitles_updated.emit(line) # Шлем сигнал в UI через игрока
		await get_tree().create_timer(delay).timeout
	
	subtitles_updated.emit("") # Очищаем субтитры
	_is_dialogue_playing = false


func _on_inventory_item_use_requested(data: ItemData) -> void:
	data.effect.use(Game.local_player) #mention: provide a player inside


func collect_item(data: ItemData):
	print("collected item: id:", data.id)
	item_picked_up.emit(data)
	

func controller_dialog_start(dialog_data):
	print("some player_component stuff..")
	dialogue_started.emit(dialog_data)
	
