extends ColorRect

## Full control reference shown from the pause menu. Both input devices are
## always listed so the player can check the other scheme at any time.

signal close_requested

const KEYBOARD_ROWS := [
	{"icons": ["wasd", "arrow"], "text": "Navigate menus, choices, and the eye light"},
	{"icons": ["enter", "space"], "text": "Select / continue"},
	{"icons": ["backspace"], "text": "Back / previous page"},
	{"icons": ["esc"], "text": "Pause / close"},
]

const MOUSE_ROWS := [
	{"icons": ["mouse"], "text": "Click buttons to navigate and select"},
	{"icons": ["mouse"], "text": "Move over the eye to aim the light"},
]

var _close_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0.0, 0.0, 0.0, 0.86)
	_build_ui()
	hide()


func open() -> void:
	show()
	if is_instance_valid(_close_button):
		_close_button.grab_focus()


func close() -> void:
	hide()


func _build_ui() -> void:
	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(1180.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override(
		"panel",
		ControlHints.make_panel_style(
			Color(0.018, 0.033, 0.038, 0.98),
			Color(0.16, 0.38, 0.35, 1.0),
			14,
			36,
			28,
			2
		)
	)
	center.add_child(panel)

	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 22)
	panel.add_child(layout)

	var title := Label.new()
	title.text = "HOW TO PLAY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", ControlHints.get_font(true))
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Keyboard and mouse controls"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", ControlHints.get_font())
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", ControlHints.MUTED_COLOR)
	layout.add_child(subtitle)

	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 40)
	layout.add_child(columns)

	columns.add_child(_make_section("KEYBOARD", KEYBOARD_ROWS))

	var divider := ColorRect.new()
	divider.name = "Divider"
	divider.color = Color(0.15, 0.34, 0.31, 0.8)
	divider.custom_minimum_size = Vector2(1.0, 0.0)
	divider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(divider)

	columns.add_child(_make_section("MOUSE", MOUSE_ROWS))

	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_END
	layout.add_child(footer)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "CLOSE"
	_close_button.custom_minimum_size = Vector2(220.0, 64.0)
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_button.flat = true
	_close_button.add_theme_font_override("font", ControlHints.get_font(true))
	_close_button.add_theme_font_size_override("font_size", 24)
	_close_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_close_button.add_theme_color_override(
		"font_hover_color",
		ControlHints.ACCENT_COLOR
	)
	_close_button.add_theme_color_override(
		"font_pressed_color",
		Color(0.35, 0.65, 0.42, 1.0)
	)
	_close_button.pressed.connect(func(): close_requested.emit())
	footer.add_child(_close_button)


func _make_section(section_title: String, rows: Array) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.name = section_title.capitalize()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 14)

	var header := Label.new()
	header.text = section_title
	header.add_theme_font_override("font", ControlHints.get_font(true))
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", ControlHints.ACCENT_COLOR)
	section.add_child(header)

	for row_data in rows:
		section.add_child(_make_row(row_data))
	return section


func _make_row(row_data: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 58.0)
	row.add_theme_constant_override("separation", 16)

	var icon_box := HBoxContainer.new()
	icon_box.custom_minimum_size = Vector2(170.0, 0.0)
	icon_box.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_box.add_theme_constant_override("separation", 2)
	for icon_name in row_data.get("icons", []):
		icon_box.add_child(ControlHints.make_icon_rect(str(icon_name), 52.0))
	row.add_child(icon_box)

	var label := Label.new()
	label.text = str(row_data.get("text", ""))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", ControlHints.get_font())
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", ControlHints.TEXT_COLOR)
	row.add_child(label)
	return row
