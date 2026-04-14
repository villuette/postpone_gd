extends Control

@onready var container = $VBoxContainer
var current_player: CharacterBody3D


func build_menu(player_ref: CharacterBody3D):
	current_player = player_ref
	# 1. Очищаем старые кнопки
	for child in container.get_children():
		child.queue_free()

	# 2. Генерируем новые из глобального словаря
	for key in GlobalSettings.settings_data:
		var data = GlobalSettings.settings_data[key]
		var h_box = HBoxContainer.new()
		container.add_child(h_box)

		var label = Label.new()
		label.text = key
		h_box.add_child(label)

		if data["type"] == "slider":
			var slider = HSlider.new()
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.min_value = data["min"]
			slider.max_value = data["max"]
			slider.value = data["val"]
			slider.step = 0.001
			# Тот самый коннект с лямбдой
			slider.value_changed.connect(func(v): GlobalSettings.update_setting(key, v))
			h_box.add_child(slider)

		elif data["type"] == "checkbox":
			var cb = CheckButton.new()
			cb.button_pressed = data["val"]
			cb.anchor_right = 1.0
			cb.toggled.connect(func(v): GlobalSettings.update_setting(key, v))
			h_box.add_child(cb)
