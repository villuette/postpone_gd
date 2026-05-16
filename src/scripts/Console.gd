extends CanvasLayer

@export var input_field: LineEdit
@export var log_label: RichTextLabel
@export var panel: Control

var commands = {} # "имя" -> { "callback": Callable, "desc": String }

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS # Консоль работает на паузе
	panel.hide()
	
	# Дефолтные команды
	register_command("help", _cmd_help, "Список всех команд")
	register_command("clear", func(_a): log_label.clear(), "Очистить лог")
	register_command("quit", func(_a): get_tree().quit(), "Выход")

func _input(event):
	# Настрой действие "toggle_console" в Input Map на клавишу ` (Тильда)
	if event.is_action_pressed("toggle_console"):
		get_viewport().set_input_as_handled()
		_toggle()

func _toggle():
	panel.visible = !panel.visible
	get_tree().paused = panel.visible # Пауза игры при открытой консоли
	if panel.visible:
		input_field.grab_focus()
	else:
		input_field.clear()

func register_command(command_name: String, callback: Callable, description: String = ""):
	commands[command_name.to_lower()] = {"callback": callback, "desc": description}

func log_message(text: String):
	log_label.append_text(text + "\n")
	print("[Console]: ", text)

func _on_line_edit_text_submitted(new_text: String):
	input_field.clear()
	if new_text.strip_edges() == "": return
	
	log_message("[color=gray]> " + new_text + "[/color]")
	_parse_command(new_text)
	input_field.grab_focus()
	input_field.release_focus()
	
	input_field.grab_focus.call_deferred()

func _parse_command(text: String):
	var parts = text.split(" ", false)
	var cmd_name = parts[0].to_lower()
	var args = parts.slice(1)
	
	if commands.has(cmd_name):
		commands[cmd_name]["callback"].call(args)
	else:
		log_message("[color=red]Ошибка:[/color] Команда '" + cmd_name + "' не найдена.")

func _cmd_help(_args):
	log_message("--- Доступные команды ---")
	for cmd in commands:
		log_message("[color=yellow]"+cmd+"[/color]" + " - " + commands[cmd]["desc"])
