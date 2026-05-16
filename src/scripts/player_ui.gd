extends CanvasLayer
class_name UIHandler
enum GameState { PLAYING, INVENTORY, MENU }
var current_state = GameState.PLAYING

@export var esc_menu: EscMenu
@export var inventory: Inventory
@export var hud: Hud
@export var stats: StatsBars
@export var weapon: WeaponHUD

signal state_changed(is_playing: bool)


func _ready():
	# Чтобы UI работал даже когда мир на паузе
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_state(GameState.PLAYING)


func _on_menu_close_requested():
	set_state(GameState.PLAYING)


func _input(event):
	if event.is_action_pressed("ui_cancel"):
		# Если мы НЕ в игре (в инвентаре или меню) — закрываем всё и возвращаемся в игру
		if current_state != GameState.PLAYING:
			set_state(GameState.PLAYING)
		else:
			# Если мы в игре — открываем меню паузы
			set_state(GameState.MENU)

	if event.is_action_pressed("inventory"):
		# Инвентарь открываем только из игры, либо закрываем, если он уже открыт
		if current_state == GameState.INVENTORY:
			set_state(GameState.PLAYING)
		elif current_state == GameState.PLAYING:
			set_state(GameState.INVENTORY)


func set_state(new_state: GameState):
	current_state = new_state

	# Управляем видимостью (лаконично)
	esc_menu.visible = (new_state == GameState.MENU)
	inventory.visible = (new_state == GameState.INVENTORY)
	stats.visible = (new_state == GameState.PLAYING)
	if weapon:
		weapon.visible = (new_state == GameState.PLAYING)
	match new_state:
		GameState.PLAYING:
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			state_changed.emit(true)

		GameState.INVENTORY:
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			state_changed.emit(false)

		GameState.MENU:
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			esc_menu.build_menu()
			state_changed.emit(false)


func _on_weapon_manager_new_weaponhud_applied(hud_scene: Variant) -> void:
	if hud_scene:
		weapon = hud_scene
