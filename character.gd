extends CharacterBody3D

var settings = {
	"video":
	{
		"fullscreen": true,
		"fov": 75,
	},
	"audio":
	{
		"master_volume": 0.8,
		"sfx_volume": 1.0,
	},
	"controls":
	{
		"sensitivity": 0.003,
	},
}

const WALK_SPEED = 5.0
const RUN_SPEED = WALK_SPEED * 1.8
var current_speed = WALK_SPEED
const JUMP_VELOCITY = 4.5
var SENSITIVITY = 0.003  # Чувствительность мыши
@onready var camera = $Camera3D
@onready var ray_cast = $Camera3D/RayCast3D
@onready var menu = $player_ui/Menu
#stats bars
@onready var stats = $player_ui/HUD/stats

@onready var health_bar = $player_ui/HUD/stats/health
@onready var stamina_bar = $player_ui/HUD/stats/stamina
@onready var mind_bar = $player_ui/HUD/stats/mind
@onready var damage_overlay = $player_ui/HUD/DamageOverlay  # Путь к твоему красному прямоугольнику
var tick_timer = 0.0
var decay_per_tick = 5.0  # Сколько отнимаем за один раз

const MAX_HEALTH = 100
const MAX_MIND = 100
const MAX_STAMINA = 100

var mind = MAX_MIND
var health = MAX_HEALTH
var stamina = MAX_STAMINA

var stamina_drain_speed = 40.0  # Уходит за сек при беге
var stamina_regen_speed = 5.0  # Копится за сек при отдыхе
var is_running = false


func _do_logic_tick():
	if mind > 0:
		mind -= decay_per_tick
		if mind < 0:
			mind = 0
		_animate_bar(mind_bar, mind)
	elif health > 0:
		# Если начали терять здоровье — проявляем красный экран
		_show_damage_vignette()
		health -= decay_per_tick
		if health < 0:
			health = 0
		_animate_bar(health_bar, health)

		if health <= 0:
			pass  #TODO die


func _show_damage_vignette():
	var tween = create_tween()
	# Делаем экран чуть красным (альфа 0.3) и сразу уводим назад
	damage_overlay.modulate.a = 0.3
	tween.tween_property(damage_overlay, "modulate:a", 0.0, 0.8)


func _animate_bar(bar: ProgressBar, new_value: float):
	# Создаем временную анимацию для свойства "value"
	var tween = create_tween()
	# Анимируем за 0.5 сек, чтобы к следующему тику полоска уже пришла в норму
	tween.tween_property(bar, "value", new_value, 0.5).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_OUT
	)


func _process(delta):
	tick_timer += delta

	#stamina waste/regeneration
	if is_running and velocity.length() > 0.1:
		stamina -= stamina_drain_speed * delta
	else:
		stamina += stamina_regen_speed * delta

	stamina = clamp(stamina, 0, MAX_STAMINA)
	stamina_bar.value = stamina

	if tick_timer >= 1.0:
		_do_logic_tick()
		tick_timer = 0.0  # Сброс накопленного времени


func open_esc_menu():
	# Инвертируем видимость меню
	menu.visible = true
	stats.visible = false
	get_tree().paused = true
	# Прямой вызов функции из скрипта меню:
	menu.build_menu(self)
	# Показываем мышь и разрешаем ей двигаться свободно
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_esc_menu():
	menu.visible = false
	stats.visible = true
	get_tree().paused = false
	get_viewport().set_input_as_handled()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event):
	if event.is_action_pressed("ui_cancel"):
		open_esc_menu()
	# Проверь, что в Input Map настроено действие "shoot" (ЛКМ)
	if event.is_action_pressed("shoot"):
		shoot()
	if event.is_action_pressed("run"):
		is_running = true
	if event.is_action_released("run"):
		is_running = false


func shoot():
	# camera.rotation.x += deg_to_rad(2.0) # Подкидывает камеру вверх на 2 градуса
	# 1. Проверяем, есть ли коллизия. Если нет — ловить нечего, выходим.
	if not ray_cast.is_colliding():
		return

	var target = ray_cast.get_collider()
	var point = ray_cast.get_collision_point()

	# 2. Визуальный фидбек (искра)
	create_spark(point)

	print("Попал в: ", target.name)

	# 3. Физика
	if target is RigidBody3D:
		var direction = (point - camera.global_position).normalized()
		target.apply_impulse(direction * 10.0, point - target.global_position)


#
func create_spark(pos: Vector3):
	var spark = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	spark.mesh = sphere

	get_tree().root.add_child(spark)
	spark.global_position = pos

	# Таймер на удаление
	get_tree().create_timer(0.5).timeout.connect(spark.queue_free)


func _ready():
	# Инициализация значений полосы здоровья, ментального состояния и выносливости

	health_bar.max_value = MAX_HEALTH
	mind_bar.max_value = MAX_MIND
	stamina_bar.max_value = MAX_STAMINA

	health_bar.value = health
	mind_bar.value = mind
	stamina_bar.value = stamina

	# Захватываем мышь при старте игры
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	SENSITIVITY = GlobalSettings.settings_data["Sensitivity"]["val"]


func _unhandled_input(event):
	# Если мышка двигается
	if event is InputEventMouseMotion:
		# Крутим всего персонажа влево-вправо (вокруг оси Y)
		rotate_y(-event.relative.x * SENSITIVITY)
		# Крутим только камеру вверх-вниз (вокруг оси X)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		# Ограничиваем наклон камеры, чтобы не делать сальто
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))


func _physics_process(delta: float) -> void:
	# Если стамина кончилась, выключаем бег принудительно
	if stamina <= 0:
		is_running = false
	# Смена скорости
	if is_running:
		current_speed = RUN_SPEED
	else:
		current_speed = WALK_SPEED
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
