@tool
extends PickableItem

var actor = null # Тот, кто держит (Игрок или NPC)
signal set_gun_scene_in_hands(scene: PackedScene)

func init_owner(entity: CharacterBody3D):
	actor = entity
	# Тут можно сразу отключить коллизии, если они есть, 
	# чтобы пушка не выталкивала игрока из мира
	
func _ready() -> void:
	super() # ВЫЗЫВАЕТ _ready() из PickableItem

func equip():
	var gun_data = self.item_data as GunData
	var gun_scene = gun_data.weapon_scene.instantiate()
	set_gun_scene_in_hands.emit(gun_scene)
