extends Node

# Добавляем список действий, которые мы хотим настраивать
var configurable_actions = [
	"move_forward", "move_back", "move_left", "move_right", "jump", "interact"
]

var settings_data = {
	"Sensitivity": {"type": "slider", "val": 0.003, "min": 0.001, "max": 0.01},
	"Fullscreen": {"type": "checkbox", "val": true},
	"FOV": {"type": "slider", "val": 75.0, "min": 60.0, "max": 110.0},
}

# Отдельный словарь для хранения клавиш (чтобы не мешать его в общий цикл слайдеров)
var controls_data = {}

const SAVE_PATH = "user://settings.cfg"


func _ready():
	# Сначала инициализируем дефолтные клавиши из настроек проекта
	for action in configurable_actions:
		var events = InputMap.action_get_events(action)
		if events.size() > 0:
			controls_data[action] = events[0]  # Берем первую назначенную клавишу

	load_settings()


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
			# Камера обновится сама через обращение к GlobalSettings или через preview_setting в UI
			pass


# Метод для применения клавиши в InputMap
func apply_control(action: String, event: InputEvent):
	if event:
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, event)


func save_settings():
	var config = ConfigFile.new()

	# Сохраняем обычные настройки
	for key in settings_data:
		config.set_value("Settings", key, settings_data[key]["val"])

	# Сохраняем клавиши
	for action in controls_data:
		config.set_value("Controls", action, controls_data[action])

	config.save(SAVE_PATH)


func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		# Загружаем обычные настройки
		for key in settings_data:
			if config.has_section_key("Settings", key):
				settings_data[key]["val"] = config.get_value("Settings", key)
				apply_setting(key, settings_data[key]["val"])

		# Загружаем клавиши
		if config.has_section("Controls"):
			for action in config.get_section_keys("Controls"):
				var event = config.get_value("Controls", action)
				controls_data[action] = event
				apply_control(action, event)
