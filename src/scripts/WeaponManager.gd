extends Node
class_name WeaponManager

signal weapon_changed(new_weapon)
signal bullet_unloaded(bullet_data)
signal new_weaponhud_applied(hud_scene)
var current_weapon: Revolver = null
@export var ui_handler: UIHandler # Чтобы менеджер сам связывал пушку с HUD
@export var weapon_slot: Node3D
@export var hud_placeholder: Control
var _player_target_func: Callable

func initialize_providers(target_func: Callable):
	_player_target_func = target_func
	
func equip_weapon(item_data: ItemData):
	_remove_current_weapon()

	if item_data == null or not item_data.is_equipped:
		return
	
	var item_scene = ItemRegistry.get_visual_scene(item_data.visual_id).instantiate()
	#var item_scene = item_data.visual_scene.instantiate()
	weapon_slot.add_child(item_scene)
	item_scene.transform = Transform3D.IDENTITY
	
	current_weapon = item_scene
	# Автоматически связываем пушку с интерфейсом
	_setup_weapon_connections(current_weapon)
	current_weapon.setup_weapon_inventory(ui_handler.inventory)
	if current_weapon.has_method("on_equip"):
		current_weapon.on_equip()
	current_weapon.set_process_unhandled_input(true)
	weapon_changed.emit(current_weapon)

func enable_current_weapon_hud():
	for child in hud_placeholder.get_children():
		child.queue_free()
	var hud_scene = current_weapon.weapon_hud_scene.instantiate()
	hud_placeholder.add_child(hud_scene)
	current_weapon.connect_hud_scene(hud_scene)
	new_weaponhud_applied.emit(hud_scene)
	

func _setup_weapon_connections(weapon):
	var hud = ui_handler.hud
	enable_current_weapon_hud()
	if weapon.has_signal("calculated_predictive_shoot_point"):
		weapon.calculated_predictive_shoot_point.connect(hud.update_predictive_crosshair_position)
	if current_weapon.has_signal("unload_bullet"):
		current_weapon.unload_bullet.connect(func(data): bullet_unloaded.emit(data))
	if "target_data_provider" in weapon:
		weapon.target_data_provider = _player_target_func

	
		
func update_aim_point(target_point: Vector3, exclude_rids: Array):
	if current_weapon:	
		current_weapon.calculate_hit_point(target_point, exclude_rids)

func _remove_current_weapon():
	if current_weapon:
		current_weapon.queue_free()
		current_weapon = null
	weapon_changed.emit(null)


#func set_reload_mode(mode: bool):
	#if current_weapon and current_weapon.has_method("toggle_reload_mode"):
		#current_weapon.toggle_reload_mode(mode)
