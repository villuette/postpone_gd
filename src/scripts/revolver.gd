extends WeaponBase
class_name Revolver
enum BulletType { MAGICAL, PHYSICAL, EMPTY }
var ammo_slots: Array[BulletData] = [null, null, null, null, null, null]
@export var muzzle: Marker3D

@export var anim_tree: AnimationTree
var current_index = 0
var can_shoot: bool = true
@export var shoot_delay: float = 0.2  # Задержка между выстрелами
signal just_shooted
signal just_loaded
signal drum_bullets_updated(current_bullets: Array[BulletData])
signal unload_bullet(bullet: BulletData)
signal calculated_predictive_shoot_point(point: Vector3)
signal shoot_clicked
@export var weapon_hud_scene: PackedScene
var is_rotating: bool = false
var reloading_state = false
var target_data_provider: Callable
var is_transitioning: bool = false
var inventory = null

func _ready() -> void:
	set_process_unhandled_input(false)

func _toggle_reload_mode(active: bool):
	reloading_state = active

func connect_hud_scene(hud_scene: WeaponHUD):
	drum_bullets_updated.connect(hud_scene.update_slots_visual)
	just_loaded.connect(hud_scene.rotate_drum.bind(1))
	just_shooted.connect(hud_scene.rotate_drum.bind(-1))
	hud_scene.current_position_updated.connect(_on_drum_position_updated)


func _on_drum_position_updated(index):
	current_index = index


func _draw_tracer(from: Vector3, to: Vector3, color: Color = Color.WHITE):
	var mesh_instance = MeshInstance3D.new()
	var immediate_mesh = ImmediateMesh.new()
	var material = StandardMaterial3D.new()

	mesh_instance.mesh = immediate_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	immediate_mesh.surface_add_vertex(from)
	immediate_mesh.surface_add_vertex(to)
	immediate_mesh.surface_end()

	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color  # Или CYAN для магии

	get_tree().root.add_child(mesh_instance)

	# Исчезает через 0.1 сек
	var tween = create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.1)
	tween.finished.connect(mesh_instance.queue_free)


func setup_weapon_inventory(player_inventory: Inventory):
	if player_inventory:
		inventory = player_inventory
		
		
## --- ФУНКЦИИ КОНКРЕТНЫХ ВЫСТРЕЛОВ ---
func on_shoot_called(target_point: Vector3, excluded):
	if not can_shoot or is_rotating:
		return
	# play_shoot_animation
	var idle_playback: AnimationNodeStateMachinePlayback = anim_tree.get(
        "parameters/StartWithIdle/playback"
	)
	idle_playback.travel("Idle")
	anim_tree.set("parameters/TimeScale/scale", 0.5)
	anim_tree.set("parameters/RollHammerMix/add_amount", 1)
	anim_tree.set(
		"parameters/ShootRollHammerMix/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
	)

	var bullet: BulletData = ammo_slots[current_index]

	if bullet == null:
		print("Клик! Пусто.")
		just_shooted.emit()
		return

	var hit_data = calculate_hit_point(target_point, excluded)

	_process_hit(bullet, hit_data.point, hit_data.direction, hit_data.collider)

	ammo_slots[current_index] = null

	just_shooted.emit()
	drum_bullets_updated.emit(ammo_slots)

	can_shoot = false
	get_tree().create_timer(shoot_delay).timeout.connect(func(): can_shoot = true)


func calculate_hit_point(target_point: Vector3, excluded) -> Dictionary:
	var cam = get_viewport().get_camera_3d()
	var ray_origin = (
		cam.global_position
		if (
			cam.global_position.distance_to(target_point)
			< cam.global_position.distance_to(muzzle.global_position)
		)
		else muzzle.global_position
	)

	var dir_to_target = (target_point - ray_origin).normalized()
	var ray_end = target_point + dir_to_target * 0.5

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = excluded

	var result = space_state.intersect_ray(query)
	if result:
		calculated_predictive_shoot_point.emit(result.position)
	return {
		"point": result.position if result else target_point,
		"collider": result.collider if result else null,
		"direction": ((result.position if result else target_point) - ray_origin).normalized()
	}


func on_equip():
	drum_bullets_updated.emit(ammo_slots)


func _process_hit(bullet: BulletData, hit_point: Vector3, shoot_dir: Vector3, collider: Node):
	# Визуал берем из ресурса пули
	create_spark(hit_point, bullet.tracer_color)
	_draw_tracer(muzzle.global_position, hit_point, bullet.tracer_color)

	if collider:
		if collider.has_method("handle_hit"):
			# Прокидываем весь ресурс в NPC
			collider.handle_hit(bullet, shoot_dir, hit_point)

		# Сохраняем физику для обычных RigidBody (ящиков и т.д.)
		elif collider is RigidBody3D:
			collider.apply_impulse(shoot_dir * bullet.force, hit_point - collider.global_position)
	else:
		print("Бабах! Мимо.")


func create_spark(pos: Vector3, color: Color):
	var spark = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.04
	sphere.height = 0.08
	spark.mesh = sphere
	spark.set_disable_scale(true)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	spark.material_override = mat

	get_tree().root.add_child(spark)
	spark.global_position = pos

	get_tree().create_timer(0.4).timeout.connect(spark.queue_free)


func load_one_bullet_at_top(bullet: BulletData):
	# если вообще ничего не дали — просто ничего не делаем
	if bullet == null or is_rotating:
		return

	# если в слоте уже есть пуля — отдаём наружу
	if ammo_slots[current_index] != null:
		var prev_loaded = ammo_slots[current_index]
		prev_loaded.pickup_stack = 1
		unload_bullet.emit(prev_loaded)

	# кладём новую
	ammo_slots[current_index] = bullet

	just_loaded.emit()
	drum_bullets_updated.emit(ammo_slots)


func click_per_loading(requesting_bullet: BulletData):
	var bullet = inventory.pop_item(requesting_bullet, 1)
	if bullet:
		bullet.pickup_stack = 1
		load_one_bullet_at_top(bullet)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot"):
		if reloading_state:
			click_per_loading(ItemRegistry.get_item_data("bullet_lead01"))
		else:
			shoot_clicked.emit()
			var data = target_data_provider.call()
			var target_point = data.get("point", Vector3.ZERO)
			var excluded = data.get("excluded", [])
			on_shoot_called(target_point, excluded)
			
			#_on_shoot_clicked()
	if event.is_action_pressed("reload"):
		_toggle_reload_mode(true)
	if event.is_action_released("reload"):
		_toggle_reload_mode(false)
	if event.is_action_pressed("muzzle_zoom"):  # Допустим, это вторая кнопка зарядки
		if reloading_state:
			click_per_loading(ItemRegistry.get_item_data("bullet_crystal01"))
