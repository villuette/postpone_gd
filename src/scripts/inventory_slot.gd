class_name ItemSlot
extends PanelContainer

@onready var icon_rect = $Icon  # Твой TextureRect
@onready var count_label = $CountLabel  # Твой Label
var stack: int = 1
enum SlotType { GENERAL, HAND } # Добавляем типы
@export var slot_type: SlotType = SlotType.GENERAL

var item_data: ItemData = null

signal hovered(data: ItemData)
signal unhovered
signal context_menu_requested(pos)

func _ready():
	# Соединяем встроенные сигналы мыши с функциями ниже
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	if item_data:
		hovered.emit(item_data)

func _on_mouse_exited():
	unhovered.emit()
	
func update_slot(data: ItemData, new_stack: int = 1):
	item_data = data
	if item_data == null:
		icon_rect.texture = null
		count_label.text = ""
		stack = 0
		unhovered.emit() # Если предмет исчез под мышкой (выкинули), гасим описание
		return
	stack = new_stack
	icon_rect.texture = item_data.icon

	if item_data.stackable:
		count_label.text = str(stack)
	else:
		count_label.text = ""
	#else:
		#icon_rect.texture = item_data.icon
		#count_label.text = str(item_data.current_stack)


func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if not item_data: return
			context_menu_requested.emit(event.global_position)
			
