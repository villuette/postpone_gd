extends CharacterBody3D
class_name Player


@export var WALK_SPEED: float = 5.0
@export var RUN_SPEED: float = 8.0
@export var JUMP_VELOCITY: float = 4.5
@export var MAX_HEALTH: int = 100
@export var MAX_MIND: int = 100
@export var MAX_STAMINA: int = 100

var can_move = true
var can_look = true
var current_speed: float = WALK_SPEED
var is_running = false
var sensitivity: float = 0.003

#var weapon: Revolver = null
var reloading_state: bool = false

signal set_running(is_running: bool)
signal shoot_pressed(pointing_to: Vector3, excluded)


@export var camera: Camera3D
@export var pickup_raycast: RayCast3D
@export var dot_controller: DoTController
@export var ui_handler: UIHandler
@export var stats_manager: StatsManager
@export var weapon_slot: Marker3D
@export var anim_tree_hands: AnimationTree

@export_group("controllers")
@export var animation_ctrl: AnimationController
@export var weapon_ctrl: WeaponManager
@export var interaction_ctrl: InteractionComponent

var esc_menu_ui: EscMenu
var stats_ui: StatsBars
var weapon_ui: WeaponHUD
var screen_overlay_ui: Hud




func _update_running_state(state: bool):
	is_running = state
	set_running.emit(state)
	
func _register_commands():
	Console.register_command("tp", _teleport, "Телепорт (usage: tp x y z)")

func _teleport(args):
	if args.size() >= 3:
		global_position = Vector3(float(args[0]), float(args[1]), float(args[2]))
		Console.log_message("Телепортирован в " + str(args))




func _ready():
	_register_commands()
	if is_multiplayer_authority():
		Game.register_local_player(self)
	pickup_raycast.add_exception(self)
	var provider = self.get_target_data_complex
	weapon_ctrl.initialize_providers(provider)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	sensitivity = GlobalSettings.settings_data["Sensitivity"]["val"]
	stats_manager.health = MAX_HEALTH
	stats_manager.mind = MAX_MIND
	stats_manager.stamina = MAX_STAMINA
	
	#weapon_ctrl.bullet_unloaded.connect(inventory_ui.add_item)


func _input(event):
	if event.is_action_pressed("run") and is_on_floor():
		_update_running_state(true)
	if event.is_action_released("run"):
		_update_running_state(false)

func take_damage(amount: float):
	if stats_manager:
		stats_manager.damage_by_type("health", amount)
		print("player получил урон: ", amount, ". Осталось: ", stats_manager.health)


func _on_shoot_clicked():
	animation_ctrl.play_shoot()


func calculate_target_point(excluded):
	# 1. Получаем параметры мира и камеры
	var space_state = get_world_3d().direct_space_state
	var center_pos = get_viewport().size / 2
	# 2. Формируем луч из центра камеры
	var ray_origin = camera.project_ray_origin(center_pos)
	var ray_end = ray_origin + camera.project_ray_normal(center_pos) * 1000.0

	# 3. Настраиваем запрос луча
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	# Можно добавить исключения, чтобы не попасть в самого себя
	query.exclude = excluded

	# 4. Пускаем луч
	var result = space_state.intersect_ray(query)

	var target_point: Vector3
	if result:
		target_point = result.position
	else:
		# Если ни во что не попали, просто точка в 100 метрах впереди
		target_point = ray_end
	return target_point



#var base_pitch = 0 МАНЕКЕН
func _lookup(event):
	if not can_look: return
		# Крутим всего персонажа влево-вправо (вокруг оси Y)
	rotate_y(-event.relative.x * sensitivity)
	# Крутим камеру вверх-вниз (вокруг оси X) и грудь (для рук)
	camera.rotate_x(-event.relative.y * sensitivity)
	#base_pitch -= event.relative.y * sensitivity
	# Ограничиваем наклон камеры, чтобы не делать сальто
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))



func _unhandled_input(event):
	if event.is_action_pressed("pick"):
		interaction_ctrl.process_interaction()
	if event is InputEventMouseMotion:
		_lookup(event)


func get_target_data_complex() -> Dictionary:
	return {
		"point": calculate_target_point([self.get_rid()]),
		"excluded": [self.get_rid()]
	}

func _process_movement(delta: float) -> void:
	if not can_move: return
	# Если стамина кончилась, выключаем бег принудительно
	if stats_manager.stamina <= 0:
		_update_running_state(false)
	# Смена скорости
	if is_running:
		current_speed = RUN_SPEED
	else:
		current_speed = WALK_SPEED
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	move_and_slide()
	

func _process_hit_calc():
	var aim_point = calculate_target_point([self.get_rid()])
	weapon_ctrl.update_aim_point(aim_point, [self.get_rid()])

func _physics_process(delta: float) -> void:
	_process_movement(delta)
	_process_hit_calc()
	animation_ctrl.update_animations(velocity, is_running, (weapon_ctrl.current_weapon!=null))
	if dialogue_mode:
		_process_dialogue_rotation(delta)


func _process_dialogue_rotation(delta):
	var target_transform = camera.global_transform.looking_at(
		look_target.global_transform.origin,
		Vector3.UP
	)

	camera.global_transform.basis = camera.global_transform.basis.slerp(
		target_transform.basis,
		delta * 5.0
	)

func _on_inventory_item_equip_requested(data: ItemData) -> void:
	weapon_ctrl.equip_weapon(data)
	if data.is_equipped: # дада, на false пушка типа снимается и поэтому сцена умирает
		weapon_ctrl.current_weapon.just_shooted.connect(_on_shoot_clicked)
	animation_ctrl.update_animations(velocity, is_running, (weapon_ctrl.current_weapon!=null))
	

func _on_inventory_item_drop_requested(item_node: RigidBody3D) -> void:
	get_parent().add_child(item_node)
	var spawn_pos = global_position + (-global_transform.basis.z * 1.5) + Vector3.UP
	item_node.global_position = spawn_pos
	var throw_dir = -global_transform.basis.z + Vector3.UP * 0.5
	item_node.apply_central_impulse(throw_dir.normalized() * 5.0)


func _on_stats_manager_died() -> void:
	#set_physics_process(false)
	print("you're dead!")

var dialogue_mode = false
var look_target = null

func _on_interaction_component_dialogue_started(dialogue_data: Variant) -> void:
	print("some player dialog stuff..")
	if not dialogue_data: return
	can_look = false
	can_move = false
	dialogue_mode = true
	look_target = dialogue_data.target_face_point
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
