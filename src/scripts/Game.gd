extends Node

# --- ПЕРЕМЕННЫЕ-ХРАНИЛИЩА ---
# Сюда мы записываем ссылки на объекты, когда они появляются в мире
var local_player: Node = null
var current_ui_handler: Node = null

# --- СИГНАЛЫ РЕГИСТРАЦИИ ---
# Нужны, чтобы другие узнали, что объект появился (если они загрузились раньше него)
signal local_player_registered(player_node: Node)
signal ui_handler_registered(ui_node: Node)

# --- МЕТОДЫ РЕГИСТРАЦИИ ---
# Вызываются из самих объектов в их _ready()

func register_local_player(node: Node):
	local_player = node
	local_player_registered.emit(node)
	print("Game: Локальный игрок зарегистрирован (", node.name, ")")

func register_ui_handler(node: Node):
	current_ui_handler = node
	ui_handler_registered.emit(node)
	print("Game: UI Handler зарегистрирован")

# --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ---

# Проверка: "Это тот самый парень, за которым мы следим?"
func is_local_player(node: Node) -> bool:
	return node == local_player
