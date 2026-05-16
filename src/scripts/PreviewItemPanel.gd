extends SubViewportContainer

@onready var anchor = $SubViewport/PreviewAnchor
@onready var camera = $SubViewport/Camera3D

var current_item: Node3D = null
var rotation_speed: float = 0.005
var is_dragging: bool = false

func _ready():
	# Слушаем сигнал (пример: из глобального синглтона или напрямую)
	GameEvents.preview_requested.connect(_on_item_received)
	

func _on_item_received(item_scene: PackedScene):
	if current_item:
		current_item.queue_free()
	
	current_item = item_scene.instantiate()
	anchor.add_child(current_item)
	
	# Сбрасываем поворот анкора при загрузке нового предмета
	anchor.rotation = Vector3.ZERO
	
	# Ждем один кадр, чтобы меши успели инициализироваться (важно для корректного AABB)
	await get_tree().process_frame
	_fit_camera_to_object()

func _fit_camera_to_object():
	if not current_item: return
	
	# 1. Вычисляем общий объем объекта
	var full_aabb = _get_full_aabb(current_item)
	
	# 2. Центрируем объект относительно анкора
	# Перемещаем модель так, чтобы её геометрический центр был в (0,0,0) анкора
	current_item.position = -full_aabb.get_center()
	
	# 3. Настраиваем камеру, чтобы объект влез в кадр
	var size = full_aabb.size.length()
	# Рассчитываем дистанцию на основе размера и FOV камеры
	var dist = size / (2.0 * tan(deg_to_rad(camera.fov) / 2.0))
	camera.position.z = dist * 1.2 # Добавляем 20% отступа, чтобы не было впритык

# Рекурсивная функция для поиска всех мешей и объединения их боксов
func _get_full_aabb(node: Node) -> AABB:
	var total_aabb = AABB()
	var first_found = false
	
	# Ищем все узлы, которые имеют визуальную геометрию (MeshInstance3D, CSG и т.д.)
	# GeometryInstance3D — это базовый класс для всего видимого в 3D
	var visual_nodes = node.find_children("*", "GeometryInstance3D", true)
	
	for visual in visual_nodes:
		var aabb = visual.get_aabb()
		# Нужно перевести локальный AABB в мировое пространство относительно корня модели
		var global_aabb = visual.get_global_transform() * aabb
		# Но нам нужно пространство относительно нашего current_item
		var local_aabb = current_item.get_global_transform().affine_inverse() * global_aabb
		
		if not first_found:
			total_aabb = local_aabb
			first_found = true
		else:
			total_aabb = total_aabb.merge(local_aabb)
	
	# Если ничего не нашли (например, в сцене только пустышки), возвращаем дефолт
	if not first_found:
		return AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 1, 1))
		
	return total_aabb
		
# Обработка вращения мышкой
func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
			
	if event is InputEventMouseMotion and is_dragging:
		# Вращаем не сам предмет, а Anchor (так проще и надежнее)
		anchor.rotate_y(event.relative.x * rotation_speed)
		anchor.rotate_x(event.relative.y * rotation_speed)

# Можно добавить зум колесиком
func _input(event):
	if not is_visible_in_tree(): return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.position.z = clamp(camera.position.z - 0.1, 0.5, 5.0)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.position.z = clamp(camera.position.z + 0.1, 0.5, 5.0)
