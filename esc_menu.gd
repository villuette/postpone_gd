extends Control

@onready var container = $VBoxContainer
var current_player: CharacterBody3D


func _input(event):
    if event.is_action_pressed("ui_cancel"):  # Esc
        current_player.close_esc_menu()


func build_menu(player_ref: CharacterBody3D):
    current_player = player_ref

    # 1. Очистка
    for child in container.get_children():
        child.queue_free()

    # 2. Создаем элементы настроек
    for key in GlobalSettings.settings_data:
        _create_setting_row(key, GlobalSettings.settings_data[key])

    # 3. Кнопка Accept в самом конце
    var accept_btn = Button.new()
    accept_btn.text = "APPLY, SAVE, CLOSE MENU"
    accept_btn.pressed.connect(_on_accept_pressed)
    container.add_child(accept_btn)

    var quit_btn = Button.new()
    quit_btn.text = "QUIT"
    quit_btn.pressed.connect(_on_leave_pressed)
    container.add_child(quit_btn)


func _on_leave_pressed():
    get_tree().quit()


func _create_setting_row(key: String, data: Dictionary):
    var h_box = HBoxContainer.new()
    container.add_child(h_box)

    var label = Label.new()
    label.text = key
    label.custom_minimum_size.x = 120
    h_box.add_child(label)

    if data["type"] == "slider":
        #Текстбокс для ввода числа (LineEdit)
        var input = LineEdit.new()
        input.text = str(data["val"])
        input.custom_minimum_size.x = 80  # Ширина бокса
        h_box.add_child(input)
        #слайдер
        var slider = HSlider.new()
        slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        slider.min_value = data["min"]
        slider.max_value = data["max"]
        slider.step = 0.0001
        slider.value = data["val"]
        #связка слайдера и текст поля
        slider.value_changed.connect(
            func(v):
                input.text = str(v)
                _preview_setting(key, v)
        )
        #связка текст поля и слайдера
        input.text_submitted.connect(
            func(new_text):
                if new_text.is_valid_float():
                    var val = float(new_text)
                    slider.value = val
        )
        # МЕНЯЕМ ТОЛЬКО ПАМЯТЬ И У ПЛЕЕРА
        slider.value_changed.connect(func(v): _preview_setting(key, v))
        h_box.add_child(slider)

    elif data["type"] == "checkbox":
        var cb = CheckButton.new()
        cb.button_pressed = data["val"]
        cb.toggled.connect(func(v): _preview_setting(key, v))
        h_box.add_child(cb)


func _preview_setting(key: String, value):
    # Обновляем данные в GlobalSettings (в оперативной памяти)
    GlobalSettings.settings_data[key]["val"] = value

    # Мгновенно применяем к плееру, чтобы он видел изменения (FOV, Sensitivity)
    if key == "Sensitivity":
        current_player.SENSITIVITY = value
    elif key == "FOV":
        current_player.camera.fov = value
    # Для полноэкранного режима можно применять сразу через GlobalSettings
    elif key == "Fullscreen":
        GlobalSettings.apply_setting(key, value)


func _on_accept_pressed():
    GlobalSettings.save_settings()
    current_player.close_esc_menu()
    print("Disk write successful.")
