# ContextMenu.gd
extends PanelContainer

signal action_selected(action: ItemData.Action)

@onready var buttons_container = $VBoxContainer

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		# Проверяем, попал ли клик в область меню
		if not get_global_rect().has_point(event.global_position):
			# Если кликнули мимо — меню самоуничтожается
			queue_free()

func setup(item_data: ItemData):
	# Очищаем старые кнопки
	for child in buttons_container.get_children():
		child.queue_free()
	
	# Создаем новые кнопки на основе данных предмета
	for action in item_data.actions:
		var btn = Button.new()
		btn.text = item_data.get_action_name(action)
		btn.pressed.connect(_on_button_pressed.bind(action))
		buttons_container.add_child(btn)

func _on_button_pressed(action: ItemData.Action):
	action_selected.emit(action)
	queue_free() # Закрываем меню после выбора
