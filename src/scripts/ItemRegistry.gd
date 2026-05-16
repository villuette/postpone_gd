extends Node

const VISUAL_DIR = "res://src/scenes/items/"
const DATA_DIR = "res://src/resources/items/"

var _visual_cache: Dictionary = {} # ID -> Полный путь к .tscn
var _data_cache: Dictionary = {}   # ID -> Загруженный ресурс .tres

func _ready() -> void:
	_refresh_registry()

func _refresh_registry() -> void:
	_visual_cache.clear()
	_data_cache.clear()
	
	# 1. Индексируем ВИЗУАЛЬНЫЕ СЦЕНЫ (.tscn)
	var v_dir = DirAccess.open(VISUAL_DIR)
	if v_dir:
		v_dir.list_dir_begin()
		var file_name = v_dir.get_next()
		while file_name != "":
			if not v_dir.current_is_dir() and file_name.ends_with(".tscn"):
				var id = file_name.get_basename()
				_visual_cache[id] = VISUAL_DIR + file_name
			file_name = v_dir.get_next()

	# 2. Индексируем РЕСУРСЫ ДАННЫХ (.tres)
	var d_dir = DirAccess.open(DATA_DIR)
	if d_dir:
		d_dir.list_dir_begin()
		var file_name = d_dir.get_next()
		while file_name != "":
			if not d_dir.current_is_dir() and file_name.ends_with(".tres"):
				var id = file_name.get_basename()
				var res = load(DATA_DIR + file_name)
				if res is ItemData:
					_data_cache[id] = res
			file_name = d_dir.get_next()
			
	print("ItemRegistry: Загружено визуалов: ", _visual_cache.size(), ", ресурсов данных: ", _data_cache.size())

# --- МЕТОДЫ ПОЛУЧЕНИЯ ---

# Получить сцену модели по ID
func get_visual_scene(id: String) -> PackedScene:
	if _visual_cache.has(id):
		return load(_visual_cache[id])
	push_error("ItemRegistry: Сцена не найдена: " + id)
	return null

# Получить ресурс данных по ID
func get_item_data(id: String) -> ItemData:
	if _data_cache.has(id):
		# Возвращаем дубликат, чтобы изменения стака в инвентаре 
		# не портили исходный файл ресурса
		return _data_cache[id].duplicate()
	push_error("ItemRegistry: Ресурс данных не найден: " + id)
	return null

# Вспомогательный метод: заспавнить предмет в мире по ID
func spawn_pickable_item(item_id: String, pos: Vector3, parent: Node = get_tree().root):
	var data = get_item_data(item_id)
	if not data: return
	
	var base_scene = preload("res://src/scripts/PhysicWrapper.gd").new()
	var visual = get_visual_scene(data.visual_id)
	
	if visual:
		base_scene.add_child(visual.instantiate())
	
	base_scene.item_data = data
	parent.add_child(base_scene)
	base_scene.global_position = pos
