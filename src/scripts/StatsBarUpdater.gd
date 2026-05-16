extends VBoxContainer
class_name StatsBars
# Словарь-карта: ключ из сигнала -> ссылка на узел
@onready var bars_map: Dictionary = {
	"health": $health,
	"mind": $mind,
	"stamina": $stamina
}

func on_stat_updated(type: String, current: float) -> void:
	# Проверяем, есть ли такой ключ в словаре, чтобы не вылететь с ошибкой
	if bars_map.has(type):
		var bar: ProgressBar = bars_map[type]
		_animate_bar(bar, current)

func _animate_bar(bar: ProgressBar, new_value: float) -> void:
	# Если это стамина, её лучше менять мгновенно для отзывчивости
	# Но если хочешь твинить всё — оставляй так
	var tween: Tween = create_tween()
	tween.tween_property(bar, "value", new_value, 0.4)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
