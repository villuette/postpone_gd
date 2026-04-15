extends Node

# Описываем структуру: тип контроля, дефолтное значение и диапазон (для слайдеров)
var settings_data = {
    "Sensitivity": {"type": "slider", "val": 0.003, "min": 0.001, "max": 0.01},
    "Fullscreen": {"type": "checkbox", "val": true},
    "FOV": {"type": "slider", "val": 75.0, "min": 60.0, "max": 110.0},
}

const SAVE_PATH = "user://settings.cfg"


func _ready():
    load_settings()


func update_setting(key: String, value):
    if settings_data.has(key):
        settings_data[key]["val"] = value
        apply_setting(key, value)
        save_settings()


func apply_setting(key: String, value):
    match key:
        "Fullscreen":
            var mode = (
                DisplayServer.WINDOW_MODE_FULLSCREEN
                if value
                else DisplayServer.WINDOW_MODE_WINDOWED
            )
            DisplayServer.window_set_mode(mode)
        "FOV":
            # Находим камеру через группу или прямое обращение, если нужно
            # Но лучше пусть персонаж сам забирает это значение
            pass


func save_settings():
    var config = ConfigFile.new()
    for key in settings_data:
        config.set_value("Settings", key, settings_data[key]["val"])
    config.save(SAVE_PATH)


func load_settings():
    var config = ConfigFile.new()
    var err = config.load(SAVE_PATH)
    if err == OK:
        for key in settings_data:
            if config.has_section_key("Settings", key):
                settings_data[key]["val"] = config.get_value("Settings", key)
                apply_setting(key, settings_data[key]["val"])
