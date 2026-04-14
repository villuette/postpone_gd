extends CharacterBody3D

var settings = {
	"video": {
		"fullscreen": true,
		"fov": 75,
	},
	"audio": {
		"master_volume": 0.8,
		"sfx_volume": 1.0,
	},
	"controls": {
		"sensitivity": 0.003,
	},
}

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var SENSITIVITY = 0.003 # Чувствительность мыши
@onready var camera = $Camera3D
@onready var ray_cast = $Camera3D/RayCast3D
@onready var menu = $player_ui/Control/Menu


func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"): # По умолчанию это клавиша Esc
		toggle_menu()


func toggle_menu():
	# Инвертируем видимость меню
	menu.visible = !menu.visible
	if menu.visible:
		# Прямой вызов функции из скрипта меню:
		menu.build_menu(self)
		# Показываем мышь и разрешаем ей двигаться свободно
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	else:
		# Возвращаем мышь в игру
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event):
	# Проверь, что в Input Map настроено действие "shoot" (ЛКМ)
	if event.is_action_pressed("shoot"):
		shoot()


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


# Вынесем создание искры в отдельный метод, чтобы не засорять shoot()
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
	# Захватываем мышь при старте игры
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	SENSITIVITY = GlobalSettings.settings_data["Sensitivity"]["val"]


func _update_setting(key, value):
	# Обновляем в глобале
	GlobalSettings.update_setting(key, value)
	# И если это чуйка, обновляем локально у персонажа
	if key == "Sensitivity":
		SENSITIVITY = value


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
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
