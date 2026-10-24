extends CanvasLayer

## Draws a focus outline around the currently focused control.
## The outline appears while the player is using the keyboard or a gamepad, so
## mouse users keep the original look of the game.

const ACCENT := Color(0.26, 1.0, 0.42, 0.95)
const FILL := Color(0.26, 1.0, 0.42, 0.07)
const SHADOW := Color(0.0, 0.0, 0.0, 0.7)

var _target: Control
var _focus_visible := true
var _modal_root: Control
var _indicator: FocusIndicator
var _empty_focus_style := StyleBoxEmpty.new()


class FocusIndicator:
	extends Control

	var target: Control

	func _draw() -> void:
		if not is_instance_valid(target):
			return
		var rect := target.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			return

		draw_rect(rect.grow(3.0), SHADOW, false, 5.0)
		draw_rect(rect.grow(1.5), ACCENT, false, 2.5)
		draw_rect(rect, FILL, true)


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS

	_indicator = FocusIndicator.new()
	_indicator.name = "Indicator"
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicator.size = get_viewport().get_visible_rect().size
	add_child(_indicator)
	_indicator.visible = false

	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	get_viewport().size_changed.connect(_on_viewport_resized)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_set_focus_visible(true)
	elif event is InputEventJoypadButton and event.pressed:
		_set_focus_visible(true)
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > 0.5:
			_set_focus_visible(true)
	elif event is InputEventMouse:
		_set_focus_visible(false)


func _process(_delta: float) -> void:
	if _indicator.visible:
		if not _has_valid_target():
			_refresh()
			return
		_indicator.queue_redraw()


func _set_focus_visible(enabled: bool) -> void:
	if _focus_visible == enabled:
		return
	_focus_visible = enabled
	_refresh()


func _on_focus_changed(control: Control) -> void:
	_target = control
	# The custom outline replaces Godot's default focus rectangle, which looks
	# out of place on the game's flat/texture buttons.
	if is_instance_valid(control) and control.has_theme_stylebox("focus"):
		control.add_theme_stylebox_override("focus", _empty_focus_style)
	_refresh()


func _on_viewport_resized() -> void:
	if _indicator:
		_indicator.size = get_viewport().get_visible_rect().size


func set_modal_root(root: Control) -> void:
	## While a modal screen is open, only draw the outline around controls that
	## actually belong to it. This prevents the ring from staying on a gameplay
	## control (such as the dialogue box) behind the modal.
	_modal_root = root
	_refresh()


func _has_valid_target() -> bool:
	if not (
		is_instance_valid(_target)
		and _target.is_inside_tree()
		and _target.is_visible_in_tree()
		and _target.has_focus()
	):
		return false
	if is_instance_valid(_modal_root) and not _modal_root.is_ancestor_of(_target):
		return false
	return true


func _refresh() -> void:
	if _indicator == null:
		return
	var show_ring := _focus_visible and _has_valid_target()
	_indicator.visible = show_ring
	_indicator.target = _target if show_ring else null
	if show_ring:
		_indicator.queue_redraw()
