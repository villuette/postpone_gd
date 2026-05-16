extends ItemUsable
class_name HealEffect

@export var heal_amount: int = 25

func use(user: Node) -> bool:
	var stats = user.stats_manager # Предположим, у игрока есть этот узел
	if stats.health < 100:
		stats.health = clamp(stats.health + heal_amount, 0, 100)
		print("Полечились на ", heal_amount)
		return true
	return false
