extends Sprite2D

@onready var intlog: TextureButton = $intlog
@onready var idcard: TextureButton = $idcard
@onready var log_title: Label = $LogTitle
@onready var log_scroll: ScrollContainer = $LogScroll
@onready var log_list: VBoxContainer = $LogScroll/LogButtonList
@onready var back_button: Button = $BackButton

@export var press_scale:Vector2 = Vector2(0.95, 0.95)

@export var visible_button_count: int = 3
@export var panel_appear_duration: float = 0.35
@export var button_appear_duration: float = 0.3
@export var stagger_delay: float = 0.08

var tween: Tween
var panel_tween: Tween
var log_open: bool = false

func _ready() -> void:
	intlog.mouse_entered.connect(_on_hover)
	intlog.mouse_exited.connect(_on_exit)

	back_button.pressed.connect(close_log_panel)

	back_button.visible = false
	back_button.modulate.a = 0.0

	log_scroll.modulate.a = 0.0
	log_scroll.scale = Vector2(0.9, 0.9)

	call_deferred("_update_scroll_height")


func _update_scroll_height() -> void:
	var count: int = log_list.get_child_count()
	if count == 0:
		return

	var visible_count: int = min(visible_button_count, count)
	var spacing: int = log_list.get_theme_constant("separation")
	var total_height: float = 0.0

	for i in range(visible_count):
		var child: Control = log_list.get_child(i)
		total_height += child.size.y

	total_height += spacing * max(visible_count - 1, 0)
	log_scroll.custom_minimum_size.y = total_height


func _on_intlog_pressed() -> void:
	if log_open:
		close_log_panel()
	else:
		open_log_panel()


func _on_intlog_button_down() -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(intlog, "scale", press_scale, 0.08)


func _on_intlog_button_up() -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(intlog, "scale", Vector2.ONE, 0.12)


func _on_intlog_focus_entered() -> void:
	_on_hover()


func open_log_panel() -> void:
	log_open = true
	_update_scroll_height()

	# Matikan interaksi tombol intlog selagi tersembunyi
	intlog.disabled = true
	idcard.disabled = true
	idcard.visible = false

	# Siapkan LogTitle buat fade-in
	log_title.visible = true
	log_title.modulate.a = 0.0

	# Siapkan back_button buat fade-in
	back_button.visible = true
	back_button.modulate.a = 0.0

	log_scroll.visible = true
	log_scroll.modulate.a = 0.0
	log_scroll.scale = Vector2(0.9, 0.9)

	if panel_tween:
		panel_tween.kill()

	panel_tween = create_tween()
	panel_tween.set_parallel(true)
	panel_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel_tween.tween_property(log_scroll, "modulate:a", 1.0, panel_appear_duration)
	panel_tween.tween_property(log_scroll, "scale", Vector2.ONE, panel_appear_duration)
	panel_tween.tween_property(intlog, "modulate:a", 0.0, panel_appear_duration * 0.6)
	panel_tween.tween_property(log_title, "modulate:a", 1.0, panel_appear_duration)
	panel_tween.tween_property(back_button, "modulate:a", 1.0, panel_appear_duration)
	panel_tween.chain().tween_callback(func(): intlog.visible = false)

	_animate_buttons_in()


func close_log_panel() -> void:
	log_open = false

	intlog.visible = true
	intlog.modulate.a = 0.0

	if panel_tween:
		panel_tween.kill()

	panel_tween = create_tween()
	panel_tween.set_parallel(true)
	panel_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	panel_tween.tween_property(log_scroll, "modulate:a", 0.0, 0.2)
	panel_tween.tween_property(log_scroll, "scale", Vector2(0.9, 0.9), 0.2)
	panel_tween.tween_property(log_title, "modulate:a", 0.0, 0.2)
	panel_tween.tween_property(back_button, "modulate:a", 0.0, 0.2)
	panel_tween.tween_property(intlog, "modulate:a", 1.0, panel_appear_duration)
	panel_tween.chain().tween_callback(func():
		log_scroll.visible = false
		log_title.visible = false
		back_button.visible = false
		intlog.disabled = false
		idcard.disabled = false
		idcard.visible = true
	)


func _animate_buttons_in() -> void:
	var children := log_list.get_children()

	for i in children.size():
		var btn: Control = children[i]
		var target_y: float = btn.position.y

		btn.modulate.a = 0.0
		btn.position.y = target_y + 20

		var t := create_tween()
		t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_interval(i * stagger_delay)
		t.set_parallel(true)
		t.tween_property(btn, "modulate:a", 1.0, button_appear_duration)
		t.tween_property(btn, "position:y", target_y, button_appear_duration)


func _on_hover():
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		intlog,
		"scale",
		Vector2(1.08, 1.08),
		0.15
	)

func _on_exit():
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		intlog,
		"scale",
		Vector2.ONE,
		0.15
	)
