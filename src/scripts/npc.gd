extends CharacterBody3D
class_name NPCBody

@onready var stats: StatsManager = $StatsManager

enum EntityType { HUMAN, SPIRIT }
enum BehaviourType {FRIENDLY, NEUTRAL, ENEMY}
@export var entity_type: EntityType = EntityType.HUMAN
@export var behavior: BehaviourType = BehaviourType.NEUTRAL 
@export var anim_tree: AnimationTree

@export_group("Patrol Settings")
@export var patrol_wait_time: float = 2.0 # Сколько секунд стоять на точке
var _wait_timer: float = 0.0              # Текущий счетчик времени
var _is_waiting: bool = false             # Флаг, что мы сейчас стоим
@export var patrol_radius: float = 15.0      # Радиус поиска случайных точек
var generated_waypoints: Array[Vector3] = [] # Массив для хранения координат
var spawn_position: Vector3
@export var speed: float = 1
@export var patrol_path: Node3D
@export var rotation_speed: float = 10.0
@onready var state_playback = anim_tree.get("parameters/StatedAnimations/playback")
@onready var skeleton: Skeleton3D = %GeneralSkeleton

@export_group("Weapon")
@export var weapon_scene: PackedScene
@export var shoot_damage: float = 10.0
@export var shoot_deviation: float = 1.0
@export var weapon_slot: Node3D
@export var shooting_cooldown: float = 1.0   # Пауза между выстрелами
# --- НАСТРОЙКИ СЕНСОРОВ ---
@export_group("Sensors")
@export var sight_range: float = 25.0        # Дальность зрения
@export var sight_fov: float = 90.0          # Угол обзора в градусах
@export var eye_height: float = 1.5          # Высота "глаз" от земли (чтобы луч не шел от ног)
@export var hearing_range: float = 10.0      # Дальность слуха
@export var los_collision_mask: int = 1      # Слой коллизий, на котором находятся стены/препятствия (по умолчанию 1)

@export_group("Combat Settings")
@export var chase_speed: float = 3.5          # Скорость при погоне
@export var attack_range: float = 15.0       # Дистанция, с которой открывает огонь

@export var bullet_scene: PackedScene        # Ссылка на сцену пули (если есть)

var last_shot_time: float = 0.0

enum State { PATROL, CHASE }
var current_state: State = State.PATROL


var player: Player = null                    # Ссылка на игрока
var is_player_detected: bool = false         # Флаг, что игрок уже обнаружен (чтобы не спамить в консоль)
# --------------------------

func on_death():
	anim_tree.active = false
	$CollisionShape3D.set_deferred("disabled", true)
	nav_agent.process_mode = Node.PROCESS_MODE_DISABLED
	skeleton.physical_bones_start_simulation()
	var death_kick = -velocity.normalized() * 2.0
	set_physics_process(false)
	set_process(false)
	get_tree().create_timer(10.0).timeout.connect(queue_free)

func _ready() -> void:
	stats.died.connect(on_death)
	state_playback.travel("PatrolState")
	_find_player()
	
	# 1. Ждем появления в мире (не в нуле)
	while global_position.length() < 0.01:
		await get_tree().physics_frame
	spawn_position = global_position

	# 2. Ждем готовности навигационной карты
	var map_rid = get_world_3d().navigation_map
	
	# Цикл ожидания: пока ID итерации 0, сервер еще не обработал карту
	var timeout = 0
	while NavigationServer3D.map_get_iteration_id(map_rid) == 0 and timeout < 100:
		await get_tree().physics_frame
		timeout += 1
		
	# На всякий случай ждем еще пару кадров для синхронизации регионов
	await get_tree().physics_frame

	# 3. Настройка точек
	if patrol_path:
		for child in patrol_path.get_children():
			if child is Marker3D: waypoints.append(child)
	
	if waypoints.is_empty():
		_generate_random_waypoints()
	
	if not waypoints.is_empty() or not generated_waypoints.is_empty():
		_set_waypoint(current_waypoint_index)

func _generate_random_waypoints():
	if patrol_path: return
	generated_waypoints.clear()
	var map = get_world_3d().navigation_map
	
	var attempts = 0
	while generated_waypoints.size() < 3 and attempts < 30:
		attempts += 1
		var random_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		var random_dist = randf_range(5.0, patrol_radius) 
		var target_pos = spawn_position + random_dir * random_dist
		
		var nav_point = NavigationServer3D.map_get_closest_point(map, target_pos)
		
		# ПРОВЕРКА: Если точка нулевая, значит сервер её не нашел. Пропускаем.
		if nav_point.length() < 0.1:
			continue
			
		generated_waypoints.append(nav_point)
	
	# Если совсем не нашли точек (NavMesh не запечен), стоим на месте
	if generated_waypoints.is_empty():
		generated_waypoints.append(spawn_position)
		print("NPC: Ожидание nav_mesh, attempt=", attempts)
	else:
		print("NPC: generated_waypoints: ", generated_waypoints)

func _rotate_npc(target_direction: Vector3, delta: float):
	if target_direction.length() > 0.01:
		# atan2(x, z) дает угол. 
		# Если модель смотрит в -Z, нам нужно, чтобы при направлении (0,0,-1) 
		# угол был 0. Но atan2(0, -1) дает PI (180°).
		# Поэтому мы вычитаем PI или прибавляем его.
		var target_angle = atan2(target_direction.x, target_direction.z) + PI
		rotation.y = lerp_angle(rotation.y, target_angle, delta * rotation_speed)
		
func _set_chase_state():
	state_playback.travel("ChaseStateTree")
	weapon_slot.add_child(weapon_scene.instantiate())
	
func _set_patrol_state():
	state_playback.travel("PatrolState")
	for child in weapon_slot.get_children():
		child.queue_free()

func _physics_process(delta: float):
	if not player: return

	# 1. Постоянно обновляем сенсоры
	var can_see = _check_sight()
	var can_hear = _check_hearing()
	
	# Логика переключения состояний
	# NPC реагирует (переходит в CHASE) только если он ENEMY
	if behavior == BehaviourType.ENEMY:
		if can_see or can_hear:
			if current_state != State.CHASE:
				current_state = State.CHASE
				_set_chase_state()
		else:
			if current_state == State.CHASE:
				current_state = State.PATROL
				_set_patrol_state()
	else:
		# Если NPC Friendly или Neutral, он всегда в режиме патруля (или покоя)
		if current_state != State.PATROL:
			current_state = State.PATROL
			# Если потеряли игрока, можно либо сразу вернуться к патрулю, 
		# либо добавить таймер "поиска" (для простоты пока сразу патруль)
			print("Возврат к ПАТРУЛИРОВАНИЮ")
			_set_patrol_state()

		


	# 2. Выполнение логики в зависимости от состояния
	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
			
func _process_chase(delta: float):
	var dist_to_player = global_position.distance_to(player.global_position)
	var can_see = _check_sight()
	
	var chase_legs_playback = anim_tree.get("parameters/StatedAnimations/ChaseStateTree/Legs/playback")
	
	# Обновляем навигацию
	nav_agent.target_position = player.global_position
	var next_path_pos = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_path_pos)
	
	# --- ЛОГИКА ДВИЖЕНИЯ С УЧЕТОМ ВИДИМОСТИ ---
	# Мы продолжаем идти, если:
	# 1. Мы далеко (дистанция > 5)
	# 2. ИЛИ мы близко, но НЕ ВИДИМ игрока (он за углом)
	if dist_to_player > attack_range or not can_see: 
		velocity = direction * chase_speed
		chase_legs_playback.travel("Sprint")
		_rotate_npc(direction, delta) # Смотрим туда, куда идем
	else:
		# Мы близко И видим игрока — вот теперь можно остановиться
		velocity = velocity.move_toward(Vector3.ZERO, delta * 10)
		chase_legs_playback.travel("Idle")
		
		# Поворачиваемся лицом к игроку, так как мы стоим и целимся
		var dir_to_player = global_position.direction_to(player.global_position)
		_rotate_npc(dir_to_player, delta)

	move_and_slide()
	
	# Обновляем наклон рук (наш Blend со звездочкой)
	_update_aiming_blend(delta)
	
	# --- СТРЕЛЬБА ---
	if dist_to_player <= attack_range and can_see:
		_attempt_shot()

func _update_aiming_blend(delta: float):
	# 1. РАСЧЕТ ИСТИННОГО НАПРАВЛЕНИЯ НА ИГРОКА (Pitch)
	var aim_target = player.global_position
	var local_target_pos = to_local(aim_target)
	var local_dir = local_target_pos.normalized()
	
	# Получаем "чистый" угол вверх/вниз
	var pitch_angle = asin(local_dir.y) 
	var max_pitch_angle = PI / 2.0 
	
	# Это базовый наклон без учета кривизны анимации
	var pure_blend_v = pitch_angle / max_pitch_angle
	
	# 2. РАСЧЕТ СМЕЩЕНИЯ ДЛЯ ВЕРТИКАЛИ (Фикс анимации бега)
	# Вычисляем, насколько быстро мы бежим (от 0.0 до 1.0)
	var speed_factor = velocity.length() / chase_speed
	speed_factor = clamp(speed_factor, 0.0, 1.0)
	
	# Если стоим (speed_factor = 0) -> прибавляем 0.0
	# Если бежим (speed_factor = 1) -> прибавляем 0.2
	var vertical_offset = lerp(0.0, 0.2, speed_factor)
	
	# 3. ФИНАЛЬНЫЙ РАСЧЕТ
	# Складываем честный угол до игрока и смещение от анимации
	var target_blend_v = pure_blend_v + vertical_offset
	
	# Обязательно ограничиваем, чтобы при беге и прицеливании вверх не пробило > 1.0
	target_blend_v = clamp(target_blend_v, -1.0, 1.0)
	
	# 4. ПРИМЕНЕНИЕ К ANIMATION TREE
	var path_v = "parameters/StatedAnimations/ChaseStateTree/AimVertical/blend_position"
	var current_blend_v = anim_tree.get(path_v)
	
	if current_blend_v == null: current_blend_v = 0.0
	
	var aim_speed = 12.0 
	anim_tree.set(path_v, lerp(current_blend_v, target_blend_v, delta * aim_speed))

func _attempt_shot():
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_shot_time >= shooting_cooldown:
		# Дополнительная проверка: не стрелять сквозь стены, даже если в режиме Chase
		if _check_sight(): 
			_shoot()
			last_shot_time = current_time

func _shoot():
	if not is_instance_valid(player) or not weapon_slot: return
	print("Выстрел в игрока")
	# Проигрываем анимацию выстрела
	anim_tree.set("parameters/StatedAnimations/ChaseStateTree/shoot_while_chase/request", 
	AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
	var start_pos = weapon_slot.global_position
	# Стреляем в грудь игрока (примерно +1.2 метра от его ног)
	var target_pos = player.global_position + Vector3(0, 1.2, 0)
	var distance = start_pos.distance_to(target_pos)
	# --- КИНЕМАТОГРАФИЧНЫЙ РАЗБРОС ---
	# Вычисляем максимальный радиус промаха. 
	# Например, на дистанции 10 метров при deviation 1.0 промах будет до 2 метров.
	var spread_radius = distance * 0.2 * shoot_deviation 
	# Генерируем случайное смещение в круге, перпендикулярном направлению выстрела
	var random_offset = Vector3(
		randf_range(-1, 1),
		randf_range(-1, 1),
		randf_range(-1, 1)
	).normalized() * randf_range(0, spread_radius)
	# Итоговая точка, куда полетит пуля
	var final_target = target_pos + random_offset
	# 3. Физическая проверка (Raycast), чтобы пуля не пролетала сквозь стены
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(start_pos, final_target)
	query.exclude = [self.get_rid()] # Исключаем NPC
	var result = space_state.intersect_ray(query)
	var impact_point = final_target # По умолчанию луч идет до игрока
	if result:
		impact_point = result.position
		if result.collider == player:
			if player is Player:
				print("Попал в игрока!")
				player.take_damage(shoot_damage)
		else:
			print("Попал в препятствие:", result.collider.name)
	_draw_debug_line(start_pos, impact_point)

func _draw_debug_line(from: Vector3, to: Vector3):
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
	material.albedo_color = Color.RED # Цвет линии выстрела
	
	get_tree().get_root().add_child(mesh_instance)
	
	# Удаляем линию через 0.1 секунды (эффект вспышки)
	await get_tree().create_timer(0.5).timeout
	mesh_instance.queue_free()

func _process_patrol(delta: float):
	if waypoints.is_empty() and generated_waypoints.is_empty(): 
		return

	# --- ЛОГИКА ОЖИДАНИЯ ---
	if _is_waiting:
		_wait_timer -= delta
		velocity = velocity.move_toward(Vector3.ZERO, delta * 10) # Плавно тормозим
		move_and_slide()
		
		if _wait_timer <= 0:
			_is_waiting = false
			_move_to_next_waypoint() # Переключаем точку только после паузы
		return # Выходим, чтобы не выполнять код движения ниже
	# -----------------------

	if nav_agent.is_target_reached():
		_on_waypoint_reached()
		return

	var next_path_pos = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_path_pos)
	
	velocity = direction * speed
	move_and_slide()
	
	var patrol_playback = anim_tree.get("parameters/StatedAnimations/PatrolState/playback")
	if velocity.length() > 0.1:
		patrol_playback.travel("Walk")
		_rotate_npc(velocity.normalized(), delta)
	

func _check_sight() -> bool:
	if not is_instance_valid(player): return false
	
	var distance = global_position.distance_to(player.global_position)
	if distance > sight_range: return false
	
	# Проверка FOV
	var forward_direction = -global_transform.basis.z 
	var direction_to_player = (player.global_position - global_position).normalized()
	var angle = rad_to_deg(forward_direction.angle_to(direction_to_player))
	if angle > sight_fov / 2.0: return false
		
	# RayCast (Проверка препятствий)
	var space_state = get_world_3d().direct_space_state
	var from_pos = global_position + Vector3.UP * eye_height
	
	# Целимся чуть выше центра игрока
	var to_pos = player.global_position + Vector3.UP * 1.2 
	
	var query = PhysicsRayQueryParameters3D.create(from_pos, to_pos, los_collision_mask)
	query.exclude = [self.get_rid()] 
	
	var result = space_state.intersect_ray(query)
	
	if result:
		# Если попали в игрока или то, что ему принадлежит
		return result.collider == player or player.is_ancestor_of(result.collider)
			
	return false

func _check_hearing() -> bool:
	if not is_instance_valid(player): return false
	
	var distance = global_position.distance_to(player.global_position)
	if distance <= hearing_range:
		return true
		
	return false

func _find_player():
	# Ищем игрока по группе. Не забудь добавить игрока в группу "player" в инспекторе!
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		# Делаем луч от глаз до тела игрока (если у него есть коллизия, это точнее)
	else:
		push_warning("NPCBody: Игрок не найден! Добавьте узел игрока в группу 'player'.")


func handle_hit(bullet: BulletData, direction: Vector3, _hit_point: Vector3):
	var final_damage = bullet.base_damage
	if behavior == BehaviourType.FRIENDLY:
		print("NPC: дружелюбен, не стреляй")
		return
	if behavior == BehaviourType.NEUTRAL:
		print("NPC: Ах так?! Теперь мы враги!")
		behavior = BehaviourType.ENEMY
	match entity_type:
		EntityType.HUMAN:
			match bullet.damage_type:
				BulletData.DamageType.CRYSTAL:
					final_damage *= 0.0 
				BulletData.DamageType.LEAD:
					final_damage *= 1.0 
				BulletData.DamageType.PURE:
					final_damage *= 1.0 
		
		EntityType.SPIRIT:
			match bullet.damage_type:
				BulletData.DamageType.LEAD:
					final_damage *= 0.05 
				BulletData.DamageType.CRYSTAL:
					final_damage *= 1.0 
				BulletData.DamageType.PURE:
					final_damage *= 1.0

	if final_damage > 0:
		stats.damage_by_type("health", final_damage)
		anim_tree.set("parameters/get_hit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

	

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var waypoints: Array[Marker3D] = []
var current_waypoint_index: int = 0 
	
func _set_waypoint(index: int):
	var target_pos: Vector3
	
	if patrol_path and waypoints.size() > 0:
		# Берем позицию из Marker3D
		target_pos = waypoints[index].global_position
	elif generated_waypoints.size() > 0:
		# Берем позицию из сгенерированного массива
		target_pos = generated_waypoints[index]
	else:
		return

	nav_agent.target_position = target_pos

func _on_waypoint_reached():
	if _is_waiting: return # Чтобы не срабатывало дважды
	
	_is_waiting = true
	_wait_timer = patrol_wait_time
	# Анимация Idle на время ожидания
	var patrol_playback = anim_tree.get("parameters/StatedAnimations/PatrolState/playback")
	patrol_playback.travel("Idle")

func _move_to_next_waypoint():
	var max_points = waypoints.size() if patrol_path else generated_waypoints.size()
	if max_points == 0: return

	current_waypoint_index = (current_waypoint_index + 1) % max_points
	
	# Если круг пройден и точки случайные — генерируем новые вокруг спавна
	if current_waypoint_index == 0 and not patrol_path:
		_generate_random_waypoints()
			
	_set_waypoint(current_waypoint_index)
	
	
