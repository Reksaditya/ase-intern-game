extends CanvasLayer

## Displays the small control popup in the gameplay and printer scenes and
## tracks which input device the player is currently using.

signal modality_changed(modality: int)

enum Modality { KEYBOARD, MOUSE }

const GAMEPLAY_CONTEXT := "gameplay"
const PRINTER_CONTEXT := "printer"
const GAMEPLAY_TIP_DURATION := 6.0
const PRINTER_TIP_DURATION := 3.0
const FADE_IN_DURATION := 0.2
const FADE_OUT_DURATION := 0.35

var modality: int = Modality.KEYBOARD

var _active_context := ""
var _active_duration := 0.0
var _last_shown_modality: Dictionary = {}
var _tip_tween: Tween
var _tip_root: Control
var _tip_center: CenterContainer
var _tip_panel: PanelContainer
var _tip_row: HBoxContainer


func _ready() -> void:
	layer = 64
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_tip_ui()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			_set_modality(Modality.KEYBOARD)
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			_set_modality(Modality.MOUSE)
	elif event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).relative.length_squared() > 1.0:
			_set_modality(Modality.MOUSE)


func enter_gameplay() -> void:
	enter_context(GAMEPLAY_CONTEXT)


func enter_printer() -> void:
	enter_context(PRINTER_CONTEXT)


func enter_context(context: String) -> void:
	_active_context = context
	_active_duration = _duration_for(context)
	if get_tree().paused:
		return
	if int(_last_shown_modality.get(context, -1)) == modality:
		# This context has already introduced the current input. Leave any tip
		# that is still on screen alone; scene transitions hide it explicitly.
		return
	_present_tip()


func refresh_active_tip() -> void:
	if _active_context.is_empty() or get_tree().paused:
		return
	if int(_last_shown_modality.get(_active_context, -1)) == modality:
		return
	_present_tip()


func leave_context() -> void:
	_active_context = ""
	hide_tip()


func reset_run() -> void:
	_last_shown_modality.clear()
	_active_context = ""
	hide_tip()


func hide_tip() -> void:
	_restart_tween()
	if is_instance_valid(_tip_center):
		_tip_center.visible = false


func is_tip_visible() -> bool:
	return is_instance_valid(_tip_center) and _tip_center.visible


func _set_modality(new_modality: int) -> void:
	if new_modality == modality:
		return
	modality = new_modality
	modality_changed.emit(modality)
	if _active_context.is_empty() or get_tree().paused:
		return
	# Switching devices re-introduces the controls for the current scene, even
	# if the other input was already shown once.
	_present_tip()


func _duration_for(context: String) -> float:
	return GAMEPLAY_TIP_DURATION if context == GAMEPLAY_CONTEXT else PRINTER_TIP_DURATION


func _present_tip() -> void:
	if _active_context.is_empty():
		return
	_last_shown_modality[_active_context] = modality
	_rebuild_tip()
	_position_tip()
	_tip_center.visible = true
	_tip_center.modulate.a = 0.0

	_restart_tween()
	_tip_tween = create_tween()
	_tip_tween.tween_property(_tip_center, "modulate:a", 1.0, FADE_IN_DURATION)
	_tip_tween.tween_interval(_active_duration)
	_tip_tween.tween_property(_tip_center, "modulate:a", 0.0, FADE_OUT_DURATION)
	_tip_tween.tween_callback(func(): _tip_center.visible = false)


func _restart_tween() -> void:
	if _tip_tween:
		_tip_tween.kill()
	_tip_tween = null


func _build_tip_ui() -> void:
	_tip_root = Control.new()
	_tip_root.name = "TipRoot"
	_tip_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tip_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tip_root)

	_tip_center = CenterContainer.new()
	_tip_center.name = "TipCenter"
	_tip_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_tip_center.offset_left = 0.0
	_tip_center.offset_top = 82.0
	_tip_center.offset_right = 0.0
	_tip_center.offset_bottom = 222.0
	_tip_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_root.add_child(_tip_center)

	_tip_panel = PanelContainer.new()
	_tip_panel.name = "TipPanel"
	_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.add_theme_stylebox_override(
		"panel",
		ControlHints.make_panel_style(
			Color(0.012, 0.03, 0.034, 0.94),
			Color(0.08, 0.36, 0.34, 0.9),
			10,
			18,
			10
		)
	)
	_tip_center.add_child(_tip_panel)

	_tip_row = HBoxContainer.new()
	_tip_row.name = "HintRow"
	_tip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tip_row.add_theme_constant_override("separation", 16)
	_tip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.add_child(_tip_row)

	_tip_center.visible = false


func _position_tip() -> void:
	var top := 12.0
	_tip_center.offset_top = top
	_tip_center.offset_bottom = top + 140.0


func _rebuild_tip() -> void:
	for child in _tip_row.get_children():
		_tip_row.remove_child(child)
		child.queue_free()

	var sections := _sections_for(_active_context, modality)
	for section_index in sections.size():
		if section_index > 0:
			var divider := ColorRect.new()
			divider.color = Color(0.16, 0.38, 0.35, 0.7)
			divider.custom_minimum_size = Vector2(1.0, 46.0)
			divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_tip_row.add_child(divider)
		var section: Dictionary = sections[section_index]
		_tip_row.add_child(
			ControlHints.make_tip_section(
				section.get("icons", []),
				str(section.get("label", "")),
				46.0,
				13
			)
		)


func _sections_for(context: String, input_modality: int) -> Array[Dictionary]:
	var sections: Array[Dictionary] = []
	if input_modality == Modality.MOUSE:
		if context == PRINTER_CONTEXT:
			sections.append({"icons": ["mouse"], "label": "CLICK TO PAGE / CONTINUE"})
		else:
			sections.append({"icons": ["mouse"], "label": "CLICK TO NAVIGATE / SELECT"})
		return sections

	if context == PRINTER_CONTEXT:
		sections.append({"icons": ["arrow"], "label": "PAGE"})
		sections.append({"icons": ["enter", "space"], "label": "CONTINUE"})
		sections.append({"icons": ["backspace"], "label": "PREVIOUS PAGE"})
		return sections

	sections.append({"icons": ["wasd", "arrow"], "label": "NAVIGATE"})
	sections.append({"icons": ["enter", "space"], "label": "SELECT"})
	sections.append({"icons": ["backspace"], "label": "BACK"})
	sections.append({"icons": ["esc"], "label": "PAUSE"})
	return sections
