extends Control
class_name EscMenu
@onready var container = $VBoxContainer
var current_player: CharacterBody3D

# Переменные для логики переназначения клавиш
var waiting_for_action: String = ""
var waiting_button: Button = null
signal close_requested

# Список действий, которые мы хотим вынести в настройки
var actions_to_show = {
	"move_forward": "Forward",
	"move_back": "Backward",
	"move_left": "Left",
	"move_right": "Right",
	"jump": "Jump",
	"interact": "Interact"
}


func build_menu():
	current_player = Game.local_player
	# 1. Очистка
	for child in container.get_children():
		child.queue_free()

	# 2. Создаем TabContainer для разделения вкладок
	var tabs = TabContainer.new()
	container.add_child(tabs)

	# --- ВКЛАДКА GENERAL ---
	var general_tab = VBoxContainer.new()
	general_tab.name = "General"
	tabs.add_child(general_tab)

	for key in GlobalSettings.settings_data:
		_create_setting_row(key, GlobalSettings.settings_data[key], general_tab)

	# --- ВКЛАДКА CONTROLS ---
	var controls_tab = VBoxContainer.new()
	controls_tab.name = "Controls"
	tabs.add_child(controls_tab)

	for action_name in actions_to_show:
		_create_control_row(action_name, actions_to_show[action_name], controls_tab)

	# 3. Кнопки внизу (вне табов)
	var btn_h_box = HBoxContainer.new()
	container.add_child(btn_h_box)

	var accept_btn = Button.new()
	accept_btn.text = "SAVE & CLOSE"
	accept_btn.pressed.connect(_on_accept_pressed)
	btn_h_box.add_child(accept_btn)

	var quit_btn = Button.new()
	quit_btn.text = "QUIT"
	quit_btn.pressed.connect(get_tree().quit)
	btn_h_box.add_child(quit_btn)


# Измененная функция (добавлен аргумент target_container)
func _create_setting_row(key: String, data: Dictionary, target_container: Control):
	var h_box = HBoxContainer.new()
	target_container.add_child(h_box)

	var label = Label.new()
	label.text = key
	label.custom_minimum_size.x = 120
	h_box.add_child(label)

	if data["type"] == "slider":
		var input = LineEdit.new()
		input.text = str(data["val"])
		input.custom_minimum_size.x = 80
		h_box.add_child(input)

		var slider = HSlider.new()
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.min_value = data["min"]
		slider.max_value = data["max"]
		slider.step = 0.01
		slider.value = data["val"]

		slider.value_changed.connect(
			func(v):
				input.text = str(v)
				_preview_setting(key, v)
		)
		h_box.add_child(slider)

	elif data["type"] == "checkbox":
		var cb = CheckButton.new()
		cb.button_pressed = data["val"]
		cb.toggled.connect(func(v): _preview_setting(key, v))
		h_box.add_child(cb)


# НОВАЯ ФУНКЦИЯ: Создание строки для клавиши
func _create_control_row(action_name: String, display_name: String, target_container: Control):
	var h_box = HBoxContainer.new()
	target_container.add_child(h_box)

	var label = Label.new()
	label.text = display_name
	label.custom_minimum_size.x = 120
	h_box.add_child(label)

	var btn = Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Показываем текущую клавишу
	btn.text = _get_action_text(action_name)
	btn.pressed.connect(_start_rebind.bind(action_name, btn))
	h_box.add_child(btn)


func _get_action_text(action_name: String) -> String:
	var events = InputMap.action_get_events(action_name)
	if events.size() > 0:
		return events[0].as_text().replace(" (Physical)", "")
	return "None"


func _start_rebind(action_name: String, btn: Button):
	waiting_for_action = action_name
	waiting_button = btn
	btn.text = "Press any key..."
	btn.release_focus()  # Чтобы нажатие Space не сработало как клик по кнопке


# Ловим нажатие новой клавиши
func _input(event):
	if waiting_for_action == "":
		return

	if event is InputEventKey or (event is InputEventMouseButton and event.is_pressed()):
		# Переназначаем в InputMap
		InputMap.action_erase_events(waiting_for_action)
		InputMap.action_add_event(waiting_for_action, event)

		# Обновляем UI
		waiting_button.text = _get_action_text(waiting_for_action)

		# Сохраняем изменение в данные (чтобы GlobalSettings мог записать в файл)
		# Если в GlobalSettings нет секции для клавиш, стоит её создать
		if not GlobalSettings.settings_data.has("Controls"):
			GlobalSettings.settings_data["Controls"] = {"type": "input", "val": {}}

		GlobalSettings.settings_data["Controls"]["val"][waiting_for_action] = event

		# Сбрасываем состояние ожидания
		waiting_for_action = ""
		waiting_button = null
		# Помечаем ввод как обработанный, чтобы он не "провалился" в игру
		get_viewport().set_input_as_handled()


func _preview_setting(key: String, value):
	GlobalSettings.settings_data[key]["val"] = value
	if key == "Sensitivity":
		current_player.sensitivity = value
	elif key == "FOV":
		current_player.camera.fov = value
	elif key == "Fullscreen":
		GlobalSettings.apply_setting(key, value)


func _on_accept_pressed():
	if waiting_for_action != "":
		return
	GlobalSettings.save_settings()
	close_requested.emit()
	print("Settings and Keybindings saved.")
