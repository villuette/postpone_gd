extends Control
class_name WeaponHUD

@onready var drum_container = $DrumContainer

# Цвета по умолчанию
const COLOR_EMPTY = Color(0.1, 0.1, 0.1) # Почти черный

var target_rotation_degrees: float = 0.0
var current_tween = null
var is_animating: bool = false
signal current_position_updated(index: int)
signal rotation_finished

func update_slots_visual(bullets: Array[BulletData]):
	var slots = drum_container.get_children()
	
	for i in range(slots.size()):
		var bullet_resource = bullets[i]
		var target_color = COLOR_EMPTY
		
		# Если в слоте есть ресурс пули — берем цвет из него
		if bullet_resource is BulletData:
			target_color = bullet_resource.tracer_color
		
		# Красим слот
		slots[i].modulate = target_color

var current_index: int = 0
var is_rotating: bool = false

func _unhandled_input(event: InputEvent):
	if is_rotating: return
	
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			rotate_drum(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			rotate_drum(-1)

func on_reload_started():
	rotate_drum(1)

func on_reload_finished():
	rotate_drum(-1)

func rotate_drum(direction: int):
	if is_animating: return
	
	current_index = (current_index - direction + 6) % 6
	target_rotation_degrees += direction * 60.0
	
	is_animating = true
	current_tween = create_tween()
	current_tween.tween_property(drum_container, "rotation_degrees", target_rotation_degrees, 0.1)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
		
	current_tween.finished.connect(func():
		current_position_updated.emit(current_index)
	)
	await current_tween.finished
	is_animating = false
	rotation_finished.emit()
	


# Вызывается при выстреле, чтобы "почернить" слот
