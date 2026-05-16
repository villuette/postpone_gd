@tool
class_name Inventory
extends Control

@onready var grid = $GridContainer  # Убедись, что путь верный
var slot_scene = preload("res://src/scenes/InventorySlot.tscn")

@export var total_slots: int = 25:
	set(value):
		total_slots = value
		if Engine.is_editor_hint(): # Проверяем, что мы в редакторе
			_update_grid()

@onready var info_panel = $ItemInfo # Твоя панель с описанием
@onready var title_label = $ItemInfo/MarginContainer/VBoxContainer/TitleLabel
@onready var desc_label = $ItemInfo/MarginContainer/VBoxContainer/DescLabel
@onready var info_texture = $ItemInfo/MarginContainer/VBoxContainer/TextureRect
@onready var hand_slot: ItemSlot = $HandSlot

var current_context_menu = null
var items: Array[ItemData] = []
var slots: Array[ItemSlot] = []

signal item_drop_requested(item_node: RigidBody3D)
signal item_use_requested(data: ItemData)
signal item_equip_requested(data: ItemData)

func _ready():
	# Если мы в игре — строим сетку нормально
	if not Engine.is_editor_hint():
		info_panel.hide()
		_update_grid()
	#equped hand slot
	if (hand_slot.has_signal("hovered")):
		hand_slot.hovered.connect(_on_slot_hovered)
	hand_slot.unhovered.connect(_on_slot_unhovered)
	hand_slot.context_menu_requested.connect(_on_context_menu_requested.bind(hand_slot))
func _update_grid():
	# Важно: grid может быть еще не готов (null), если скрипт сработал слишком рано
	if not grid: return 
	
	# 1. Очищаем старые ячейки
	for child in grid.get_children():
		child.queue_free()
	slots.clear()
	
	# 2. Создаем новые
	for i in range(total_slots):
		var slot = slot_scene.instantiate()
		grid.add_child(slot)
		slots.append(slot)
		
		# Коннектим сигналы только если мы В ИГРЕ
		if not Engine.is_editor_hint():
			slot.hovered.connect(_on_slot_hovered)
			slot.unhovered.connect(_on_slot_unhovered)
			slot.context_menu_requested.connect(_on_context_menu_requested.bind(slot))

func _on_context_menu_requested(spawn_pos: Vector2, slot: ItemSlot):
	if current_context_menu:
		current_context_menu.queue_free()
	current_context_menu = preload("res://src/scenes/InventoryContextMenu.tscn").instantiate()
	
	# Добавляем меню прямо в инвентарь (или в сам CanvasLayer)
	# Так оно будет выше GridContainer по иерархии
	add_child(current_context_menu)
	
	# Устанавливаем позицию. 
	# Так как меню теперь ребенок Инвентаря, используем global_position
	current_context_menu.global_position = spawn_pos
	var data = slot.item_data
	current_context_menu.setup(data)
	
	# Подписываемся на результат выбора в меню
	current_context_menu.action_selected.connect(func(action): 
		_on_action_selected(action, slot)
	)

# наш распределитель (диспетчер)
func _on_action_selected(action: ItemData.Action, slot: ItemSlot):
	var data = slot.item_data
	match action:
		ItemData.Action.USE:
			item_use_requested.emit(data)
			if data.effect.consumable:
				pop_item(data, 1)
			
		ItemData.Action.PREVIEW:
			GameEvents.preview_requested.emit(ItemRegistry.get_visual_scene(data.visual_id))
			
		ItemData.Action.EQUIP:
			if data.is_equipped:
				data.is_equipped = false
				# Кладем старую пушку в освободившийся слот (или любой пустой)
				add_item(data)
				hand_slot.update_slot(null)
				item_equip_requested.emit(data) # Сигнал персонажу убрать визуальную модель
				return
			# Сначала запоминаем, что у нас было в руках
			var old_hand_item = hand_slot.item_data
			
			# Очищаем слот, из которого берем
			slot.update_slot(null)
			
			# Если в руках что-то было — возвращаем это в инвентарь
			if old_hand_item:
				old_hand_item.is_equipped = false
				# Кладем старую пушку в освободившийся слот (или любой пустой)
				add_item(old_hand_item) 
			
			# Экипируем новое
			data.is_equipped = true 
			hand_slot.update_slot(data)

			item_equip_requested.emit(data)

		ItemData.Action.DROP:
			# 1. Сначала сохраняем данные о стаке, пока слот не обнулился
			var stack_to_drop = slot.stack
			
			# 2. Очищаем слот
			slot.update_slot(null)
			
			# 3. Настраиваем данные для дропа
			if data.is_equipped:
				data.is_equipped = false
				hand_slot.update_slot(null)
				item_equip_requested.emit(data) # Сигнал персонажу убрать визуальную модель

			# ВАЖНО: Присваиваем актуальный стак ПЕРЕД созданием физического объекта
			data.pickup_stack = stack_to_drop
			
			# 4. Вызываем создание объекта в мире
			_on_slot_drop_requested(data)


	

func _on_slot_hovered(data: ItemData):
	title_label.text = data.title
	desc_label.text = data.description # Убедись, что это поле есть в ItemData
	info_texture.texture = data.icon
	info_panel.show()

func _on_slot_unhovered():
	info_panel.hide()

func _on_slot_drop_requested(data: ItemData):
	# 1. Создаем физический объект
	var wrapper_scene: PhysicWrapper = preload("res://src/scripts/PhysicWrapper.gd").new()
	var visual_scene = ItemRegistry.get_visual_scene(data.visual_id).instantiate()
	for child in visual_scene.get_children():
		if child is PickableComponent:
			child.item_data = data.duplicate()
	wrapper_scene.add_child(visual_scene)
	item_drop_requested.emit(wrapper_scene)
	

func add_item(new_item: ItemData):
	print("try add_item: %s, id: %s" % [new_item, new_item.id])
	new_item = new_item.duplicate()
	var incoming_stack = new_item.pickup_stack

	# 1. стакаем
	for slot in slots:
		var data := slot.item_data
		if data == null:
			continue

		if data.id != new_item.id:
			continue

		if !data.stackable:
			continue

		if slot.stack >= data.max_stack:
			continue

		var space = data.max_stack - slot.stack
		var to_add = min(space, incoming_stack)

		slot.stack += to_add
		incoming_stack -= to_add

		slot.update_slot(data, slot.stack)

		if incoming_stack <= 0:
			return slot

	# 2. пустые слоты
	for slot in slots:
		if slot.item_data == null:
			var to_place = min(new_item.max_stack, incoming_stack)

			slot.update_slot(new_item, to_place)
			incoming_stack -= to_place

			if incoming_stack <= 0:
				return slot

	print("Инвентарь полон!")
	return null
	
	
func pop_item(item_to_find: ItemData, amount: int = 1) -> ItemData:
	if not item_to_find: return null
	
	var remaining_to_pop = amount
	var result_item: ItemData = null

	for slot in slots:
		var data = slot.item_data
		if data and data.id == item_to_find.id:
			# Сколько мы можем забрать из этого слота?
			var can_take = min(slot.stack, remaining_to_pop)
			
			# Если это первая находка, создаем объект возврата
			if result_item == null:
				result_item = data.duplicate()
				result_item.pickup_stack = 0 
			
			# Вычитаем из слота
			slot.stack -= can_take
			remaining_to_pop -= can_take
			result_item.pickup_stack += can_take
			
			# Обновляем визуальную часть слота
			if slot.stack <= 0:
				slot.update_slot(null)
			else:
				slot.update_slot(data, slot.stack)
			
			# Если забрали всё, что нужно — выходим
			if remaining_to_pop <= 0:
				return result_item
				
	return result_item # Вернет либо набранное количество, либо null


func _on_weapon_manager_bullet_unloaded(bullet_data: Variant) -> void:
	if bullet_data:
		add_item(bullet_data)


func _on_interaction_component_item_picked_up(data: ItemData) -> void:
	if data:
		add_item(data)
