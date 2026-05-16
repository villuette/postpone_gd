@tool
extends Control

@export var radius: float = 80.0 # Расстояние от центра до квадратика

func _ready():
	var slots = get_children()
	for i in range(slots.size()):
		# Считаем угол для каждого слота (в радианах)
		# Вычитаем PI/2, чтобы первый слот (i=0) был ровно сверху
		var angle = i * (PI * 2 / 6) - (PI / 2)
		
		# Вычисляем позицию X и Y
		var x = cos(angle) * radius
		var y = sin(angle) * radius
		
		slots[i].position = Vector2(x, y) - (slots[i].size / 2.0)
