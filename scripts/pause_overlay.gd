extends ColorRect

signal resume_requested
signal main_menu_requested

@onready var _resume_button: Button = $Center/Content/ResumeButton
@onready var _how_to_play_button: Button = $Center/Content/HowToPlayButton
@onready var _main_menu_button: Button = $Center/Content/MainMenuButton
@onready var _how_to_play: ColorRect = $HowToPlayOverlay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resume_button.pressed.connect(func(): resume_requested.emit())
	_how_to_play_button.pressed.connect(_open_how_to_play)
	_main_menu_button.pressed.connect(func(): main_menu_requested.emit())
	_how_to_play.connect("close_requested", _close_how_to_play)


func open_menu() -> void:
	if _how_to_play.visible:
		_close_how_to_play()
	show()
	_resume_button.grab_focus()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _how_to_play.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_how_to_play()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		resume_requested.emit()
		get_viewport().set_input_as_handled()


func _open_how_to_play() -> void:
	_resume_button.focus_mode = Control.FOCUS_NONE
	_how_to_play_button.focus_mode = Control.FOCUS_NONE
	_main_menu_button.focus_mode = Control.FOCUS_NONE
	_how_to_play.call("open")


func _close_how_to_play() -> void:
	_how_to_play.call("close")
	_resume_button.focus_mode = Control.FOCUS_ALL
	_how_to_play_button.focus_mode = Control.FOCUS_ALL
	_main_menu_button.focus_mode = Control.FOCUS_ALL
	_how_to_play_button.grab_focus()
