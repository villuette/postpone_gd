# ItemEffect.gd
extends Resource
class_name ItemUsable

# Главный метод, который переопределяют все эффекты.

@export var consumable = true
func use(user: Node) -> bool:
	return false
