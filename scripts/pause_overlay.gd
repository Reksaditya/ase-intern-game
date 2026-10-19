extends ColorRect

signal resume_requested
signal main_menu_requested

@onready var _resume_button: Button = $Center/Content/ResumeButton
@onready var _main_menu_button: Button = $Center/Content/MainMenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resume_button.pressed.connect(func(): resume_requested.emit())
	_main_menu_button.pressed.connect(func(): main_menu_requested.emit())


func open_menu() -> void:
	show()
	_resume_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		resume_requested.emit()
		get_viewport().set_input_as_handled()
