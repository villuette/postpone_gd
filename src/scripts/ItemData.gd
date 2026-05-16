@tool
class_name ItemData extends Resource

# --- АВТОМАТИЧЕСКИЙ ID ---
# Он не экспортируется, а вычисляется из имени файла
@export var id: String = ""

# --- ВИЗУАЛЬНЫЙ ID (ДЛЯ ВЫПАДАЮЩЕГО СПИСКА) ---
var visual_id: String = "none"

@export_group("Визуал и текст")
@export var title: String = "Новый предмет"
@export var icon: Texture2D
@export_multiline var description: String = ""

@export_group("Логика сетки")
@export var grid_size: Vector2i = Vector2i(1, 1)

@export_group("Стаки")
@export var stackable: bool = false
@export var max_stack: int = 1
@export var pickup_stack: int = 1 

@export_group("Состояние")
@export var is_equipped: bool = false

enum Action { USE, EQUIP, DROP, PREVIEW }

@export_group("Контекстное меню")
@export var actions: Array[Action] = [Action.DROP, Action.PREVIEW]

@export_group("Эффект использования")
@export var effect: Resource # Используй Resource или ItemUsable, если класс готов



func _get_property_list() -> Array:
	var properties: Array = []
	# Группа выбора сцены
	properties.append({
		"name": "Сцена предмета",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP
	})

	var item_list = _get_item_files()
	properties.append({
		"name": "visual_id",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(item_list),
		# ВАЖНО: PROPERTY_USAGE_STORAGE позволяет сохранять значение в .tres файл!
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_STORAGE 
	})
	
	return properties

# Хелпер для получения списка файлов
func _get_item_files() -> Array:
	var list = ["none"]
	var path = "res://src/scenes/items/"
	
	if not DirAccess.dir_exists_absolute(path):
		return list

	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tscn"):
				list.append(file_name.get_basename())
			file_name = dir.get_next()
	return list

# --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ---

func get_action_name(action: Action) -> String:
	match action:
		Action.EQUIP:
			return "СНЯТЬ" if is_equipped else "ЭКИПИРОВАТЬ"
		Action.USE:
			return "ИСПОЛЬЗОВАТЬ"
		Action.DROP:
			return "ВЫБРОСИТЬ"
		Action.PREVIEW:
			return "ОСМОТРЕТЬ"
	return ""
