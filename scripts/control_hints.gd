class_name ControlHints
extends RefCounted

## Shared icon/label builders for the input tips and the pause-menu control
## guide. Keeping the styling here makes the transient tip and the full guide
## look like part of the same UI.

const ICON_PATHS := {
	"arrow": "res://assets/UI/tutor_ARROW.svg",
	"backspace": "res://assets/UI/tutor_BACKSPACE.svg",
	"enter": "res://assets/UI/tutor_ENTER.svg",
	"esc": "res://assets/UI/tutor_ESC.svg",
	"mouse": "res://assets/UI/tutor_MOUSE.svg",
	"space": "res://assets/UI/tutor_SPACE.svg",
	"wasd": "res://assets/UI/tutor_WASD.svg",
}

const FONT_REGULAR := "res://assets/fonts/RobotoMono-Regular.ttf"
const FONT_BOLD := "res://assets/fonts/RobotoMono-Bold.ttf"
const TEXT_COLOR := Color(0.86, 0.91, 0.89, 1.0)
const MUTED_COLOR := Color(0.62, 0.72, 0.69, 0.9)
const ACCENT_COLOR := Color(0.26, 1.0, 0.42, 1.0)

static var _texture_cache: Dictionary = {}
static var _font_cache: Dictionary = {}


static func get_font(bold: bool = false) -> Font:
	var key := "bold" if bold else "regular"
	if not _font_cache.has(key):
		_font_cache[key] = load(FONT_BOLD if bold else FONT_REGULAR) as Font
	return _font_cache[key]


static func get_icon(icon_name: String) -> Texture2D:
	if _texture_cache.has(icon_name):
		return _texture_cache[icon_name] as Texture2D
	var path := str(ICON_PATHS.get(icon_name, ""))
	if path.is_empty():
		return null
	var texture := load(path) as Texture2D
	if texture == null:
		push_warning("Could not load control icon: %s" % path)
	_texture_cache[icon_name] = texture
	return texture


static func make_icon_rect(icon_name: String, icon_size: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = get_icon(icon_name)
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


static func make_icon_row(icon_names: Array, icon_size: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for icon_name in icon_names:
		row.add_child(make_icon_rect(str(icon_name), icon_size))
	return row


static func make_tip_section(
	icon_names: Array,
	label_text: String,
	icon_size: float = 44.0,
	label_size: int = 13
) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.alignment = BoxContainer.ALIGNMENT_CENTER
	section.add_theme_constant_override("separation", 2)
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_child(make_icon_row(icon_names, icon_size))

	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", get_font(true))
	label.add_theme_font_size_override("font_size", label_size)
	label.add_theme_color_override("font_color", ACCENT_COLOR)
	section.add_child(label)
	return section


static func make_panel_style(
	background: Color,
	border: Color,
	corner_radius: int,
	margin_horizontal: int,
	margin_vertical: int,
	border_width: int = 1
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = margin_horizontal
	style.content_margin_right = margin_horizontal
	style.content_margin_top = margin_vertical
	style.content_margin_bottom = margin_vertical
	return style
