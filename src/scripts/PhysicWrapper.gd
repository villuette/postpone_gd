# PickableItem.gd (Корень - RigidBody3D)
@tool
extends RigidBody3D
class_name PhysicWrapper

func _init() -> void:
	# Если мы находимся в редакторе, создаем "пустышку"
	if Engine.is_editor_hint():
		_create_editor_dummy_shape()

func _create_editor_dummy_shape():
	# Проверяем, нет ли уже коллизии (чтобы не дублировать при сохранении)
	for child in get_children(true): # true позволяет видеть внутренние узлы
		if child is CollisionShape3D:
			return
			
	var dummy = CollisionShape3D.new()
	dummy.name = "EditorVisualFix"
	
	# Добавляем как ВНУТРЕННИЙ узел. 
	# INTERNAL_MODE_FRONT означает, что он будет скрыт в дереве сцены 
	# и не будет мешать твоему циклу по детям (get_children его не увидит).
	add_child(dummy, false, Node.INTERNAL_MODE_FRONT)

func _ready():
	setup_physics()
	
	print("physics all set up for ", self)

func _find_visual_node():
	var visual_node = null
	for child in get_children():
		if not child is InteractableComponent:
			visual_node = child
			break
	
	return visual_node
	
func setup_physics():
	# 1. Ищем визуал (первый ребенок, не являющийся компонентом)
	var visual_node = _find_visual_node()

	# 2. Вытягиваем всё на свой уровень мгновенно
	# Используем false в reparent, чтобы сохранить локальные координаты
	for grandchild in visual_node.get_children():
		if grandchild is InteractableComponent:
			grandchild.reparent(self, false) 
		
		elif grandchild.name == "PhysicsCollision":
			grandchild.reparent(self, false)
			grandchild.disabled = false
