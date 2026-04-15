extends Resource
class_name ItemData

@export_group("Визуал и текст")
@export var title: String = "Новый предмет"
@export var icon: Texture2D
@export_multiline var description: String = ""

@export_group("Логика сетки")
# Если планируешь инвентарь как в Resident Evil/Tarkov (2x2, 1x3),
# то используй Vector2i. Если просто ячейка — оставь 1.
@export var grid_size: Vector2i = Vector2i(1, 1)

@export_group("Стаки")
@export var stackable: bool = false
@export var max_stack: int = 1
@export var current_stack: int = 1  # Сколько штук в конкретной пачке
