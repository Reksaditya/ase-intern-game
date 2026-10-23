class_name ControlHints
extends RefCounted

## Shared icon/label builders for the input tips and the pause-menu control
## guide. Keeping the styling here makes the transient tip and the full guide
## look like part of the same UI.

const ICON_PATHS := {
	"abutton": "res://assets/UI/tutor_ABUTTON.svg",
	"analog": "res://assets/UI/tutor_ARROW&ANALOG.svg",
	"arrow": "res://assets/UI/tutor_ARROW.svg",
	"backspace": "res://assets/UI/tutor_BACKSPACE.svg",
	"bbutton": "res://assets/UI/tutor_BBUTTON.svg",
	"enter": "res://assets/UI/tutor_ENTER.svg",
	"esc": "res://assets/UI/tutor_ESC.svg",
	"mouse": "res://assets/UI/tutor_MOUSE.svg",
	"pause": "res://assets/UI/tutor_STARTBUTTON.svg",
	"space": "res://assets/UI/tutor_SPACE.svg",
	"wasd": "res://assets/UI/tutor_WASD.svg",
}

# Keep the pause/start icon working if the final asset is renamed or swapped.
const ICON_FALLBACK_PATHS := {
	"pause": [
		"res://assets/UI/tutor_PAUSE.svg",
		"res://assets/UI/tutor_START.svg",
		"res://assets/UI/tutor_MENU.svg",
		"res://assets/UI/tutor_OPTIONS.svg",
	],
}

const TEXT_ICONS := {
	"pause": "START",
}

# Optional icons fall back to a text keycap without logging every rebuild.
const OPTIONAL_ICONS := {
	"pause": true,
}

# The controller exports carry a lot of transparent padding around their
# artwork. Crop the imported textures to the drawn area so the icons read at
# the same physical size as the keyboard keycaps.
const ICON_VIEWBOX_SIZE := 384.0
const ICON_REGIONS := {
	"abutton": Rect2(92.0, 92.0, 200.0, 200.0),
	"analog": Rect2(34.0, 133.0, 316.0, 134.0),
	"arrow": Rect2(34.0, 73.0, 316.0, 216.0),
	"backspace": Rect2(34.5, 144.5, 311.5, 95.0),
	"bbutton": Rect2(92.0, 92.0, 200.0, 200.0),
	"enter": Rect2(34.0, 135.0, 311.0, 114.0),
	"esc": Rect2(120.0, 118.5, 144.5, 147.0),
	"mouse": Rect2(36.0, 111.0, 313.5, 162.0),
	"pause": Rect2(35.0, 103.0, 314.0, 177.0),
	"space": Rect2(34.0, 159.5, 310.0, 64.0),
	"wasd": Rect2(34.0, 73.0, 316.0, 216.0),
}

const ICON_SHADER_CODE := """
shader_type canvas_item;

void fragment() {
	vec4 icon = texture(TEXTURE, UV);
	float brightness = max(icon.r, max(icon.g, icon.b));
	// The controller exports use a pure-black body. Lift it to the same grey
	// as the keyboard keycaps so the icon stays readable on the dark UI.
	if (icon.a > 0.01 && brightness < 0.08) {
		icon.rgb = vec3(0.18);
	}
	COLOR = icon;
}
"""

const FONT_REGULAR := "res://assets/fonts/CourierPrime-Regular.ttf"
const FONT_BOLD := "res://assets/fonts/CourierPrime-Bold.ttf"
const TEXT_COLOR := Color(0.86, 0.91, 0.89, 1.0)
const MUTED_COLOR := Color(0.62, 0.72, 0.69, 0.9)
const ACCENT_COLOR := Color(0.26, 1.0, 0.42, 1.0)

static var _texture_cache: Dictionary = {}
static var _font_cache: Dictionary = {}
static var _icon_material: ShaderMaterial


static func get_font(bold: bool = false) -> Font:
	var key := "bold" if bold else "regular"
	if not _font_cache.has(key):
		_font_cache[key] = load(FONT_BOLD if bold else FONT_REGULAR) as Font
	return _font_cache[key]


static func get_icon(icon_name: String) -> Texture2D:
	if _texture_cache.has(icon_name):
		return _texture_cache[icon_name] as Texture2D
	var path := str(ICON_PATHS.get(icon_name, ""))
	if not path.is_empty() and not ResourceLoader.exists(path):
		for fallback_path in ICON_FALLBACK_PATHS.get(icon_name, []):
			if ResourceLoader.exists(str(fallback_path)):
				path = str(fallback_path)
				break
	if path.is_empty() or not ResourceLoader.exists(path):
		# Do not cache the miss: the pause icon may be dropped into the project
		# later, and a fresh tip should pick it up on the next rebuild.
		if not OPTIONAL_ICONS.has(icon_name):
			push_warning("Could not load control icon: %s" % icon_name)
		return null
	var texture := load(path) as Texture2D
	if texture == null:
		push_warning("Could not load control icon: %s" % path)
		return null
	if ICON_REGIONS.has(icon_name):
		var region: Rect2 = ICON_REGIONS[icon_name]
		var texture_scale := Vector2(texture.get_size()) / ICON_VIEWBOX_SIZE
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(region.position * texture_scale, region.size * texture_scale)
		atlas.filter_clip = true
		texture = atlas
	_texture_cache[icon_name] = texture
	return texture


static func make_icon_rect(
	icon_name: String,
	icon_size: float,
	icon_width: float = 0.0
) -> Control:
	var texture := get_icon(icon_name)
	if texture == null:
		return _make_text_icon(icon_name, icon_size, icon_width)
	var icon_size_vector := Vector2(
		icon_width if icon_width > 0.0 else icon_size,
		icon_size
	)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = icon_size_vector
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.material = _get_icon_material()
	return icon


static func _make_text_icon(
	icon_name: String,
	icon_size: float,
	icon_width: float = 0.0
) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(
		icon_width if icon_width > 0.0 else icon_size,
		icon_size
	)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.18, 1.0)
	style.border_color = Color(0.34, 0.4, 0.38, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(maxi(4, int(icon_size * 0.2)))
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = str(TEXT_ICONS.get(icon_name, icon_name.to_upper()))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", get_font(true))
	label.add_theme_font_size_override("font_size", maxi(10, int(icon_size * 0.26)))
	label.add_theme_color_override("font_color", TEXT_COLOR)
	panel.add_child(label)
	return panel


static func _get_icon_material() -> ShaderMaterial:
	if _icon_material == null:
		var shader := Shader.new()
		shader.code = ICON_SHADER_CODE
		_icon_material = ShaderMaterial.new()
		_icon_material.shader = shader
	return _icon_material


static func make_icon_row(
	icon_names: Array,
	icon_size: float,
	icon_width: float = 0.0
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for icon_name in icon_names:
		row.add_child(make_icon_rect(str(icon_name), icon_size, icon_width))
	return row


static func make_tip_section(
	icon_names: Array,
	label_text: String,
	icon_size: float = 44.0,
	label_size: int = 13,
	icon_width: float = 0.0
) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.alignment = BoxContainer.ALIGNMENT_CENTER
	section.add_theme_constant_override("separation", 2)
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_child(make_icon_row(icon_names, icon_size, icon_width))

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
