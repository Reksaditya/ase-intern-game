extends Sprite2D

signal question_asked(question_key: String)
signal id_card_requested
signal log_panel_opened
signal log_panel_closed

const LOG_SCROLL_WHEEL_STEP := 36.0
const LOG_SCROLL_TWEEN_DURATION := 0.18
const BUTTON_SFX: AudioStream = preload("res://assets/bgm/button.mp3")

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

var button_tweens: Dictionary = {}
var question_button_tweens: Array[Tween] = []
var panel_tween: Tween
var log_scroll_tween: Tween
var log_scroll_target: float = 0.0
var log_open: bool = false
var interaction_locked: bool = false
var _button_sfx_player: AudioStreamPlayer

func _ready() -> void:
	for button in [intlog, idcard]:
		button.mouse_entered.connect(_on_hover.bind(button))
		button.mouse_exited.connect(_on_exit.bind(button))
		button.button_down.connect(_on_button_down.bind(button))
		button.button_up.connect(_on_button_up.bind(button))
		button.focus_entered.connect(_on_hover.bind(button))
		button.focus_exited.connect(_on_exit.bind(button))
	intlog.pressed.connect(_on_intlog_pressed)
	idcard.pressed.connect(_on_idcard_pressed)

	back_button.pressed.connect(func():
		if interaction_locked:
			return
		_play_button_sfx()
		close_log_panel()
	)
	for question_key in ["emotional", "factual", "trap", "clarification"]:
		var question_button := log_list.get_node_or_null(question_key) as BaseButton
		if question_button:
			question_button.pressed.connect(_on_question_button_pressed.bind(question_key))
			question_button.focus_entered.connect(
				_on_question_button_focused.bind(question_button)
			)

	log_title.hide()
	log_scroll.hide()
	back_button.hide()
	back_button.modulate.a = 0.0

	log_scroll.modulate.a = 0.0
	log_scroll.scale = Vector2(0.9, 0.9)

	_button_sfx_player = AudioStreamPlayer.new()
	_button_sfx_player.stream = BUTTON_SFX
	_button_sfx_player.volume_db = -3.0
	add_child(_button_sfx_player)

	call_deferred("_update_scroll_height")


func _play_button_sfx() -> void:
	if is_instance_valid(_button_sfx_player):
		_button_sfx_player.play()


# Replace ScrollContainer's page-sized wheel jumps with a small smooth step.
func _input(event: InputEvent) -> void:
	if not log_open or not log_scroll.visible:
		return
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or not log_scroll.get_global_rect().has_point(mouse_event.position):
		return

	var direction := 0.0
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		direction = -1.0
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		direction = 1.0
	else:
		return

	var wheel_factor := mouse_event.factor if mouse_event.factor > 0.0 else 1.0
	_scroll_log_smoothly(direction * LOG_SCROLL_WHEEL_STEP * wheel_factor)
	get_viewport().set_input_as_handled()


func _on_question_button_pressed(question_key: String) -> void:
	if not log_open or interaction_locked:
		return
	_play_button_sfx()
	question_asked.emit(question_key)


func _on_question_button_focused(button: Control) -> void:
	if not log_open:
		return
	_scroll_question_button_into_view.call_deferred(button)


func _scroll_question_button_into_view(button: Control) -> void:
	if not log_open or not log_scroll.visible or not is_instance_valid(button):
		return
	_stop_log_scroll_tween()
	log_scroll.ensure_control_visible(button)

	# ensure_control_visible works with integer scroll steps; nudge by the
	# fractional remainder so the focused button is not clipped at the edge.
	var viewport_rect := log_scroll.get_global_rect()
	var button_rect := button.get_global_rect()
	if button_rect.end.y > viewport_rect.end.y:
		log_scroll.scroll_vertical += int(ceil(button_rect.end.y - viewport_rect.end.y))
	elif button_rect.position.y < viewport_rect.position.y:
		log_scroll.scroll_vertical -= int(ceil(viewport_rect.position.y - button_rect.position.y))
	log_scroll_target = float(log_scroll.scroll_vertical)


func get_log_focus_controls() -> Array[Control]:
	var controls: Array[Control] = []
	for child in log_list.get_children():
		if child is BaseButton:
			controls.append(child as Control)
	controls.append(back_button)
	return controls


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


func set_interaction_locked(locked: bool) -> void:
	interaction_locked = locked
	if log_open:
		_set_question_buttons_disabled(locked)
		back_button.disabled = locked
	else:
		intlog.disabled = locked
		idcard.disabled = locked
		if locked:
			_animate_button(intlog, Vector2.ONE, 0.1, Tween.TRANS_SINE)
			_animate_button(idcard, Vector2.ONE, 0.1, Tween.TRANS_SINE)


func _on_intlog_pressed() -> void:
	if interaction_locked:
		return
	_play_button_sfx()
	if log_open:
		close_log_panel()
	else:
		open_log_panel()


func _on_idcard_pressed() -> void:
	if interaction_locked:
		return
	_play_button_sfx()
	id_card_requested.emit()


func open_log_panel() -> void:
	if log_open or interaction_locked:
		return

	_stop_log_scroll_tween()
	log_scroll.scroll_vertical = 0
	log_scroll_target = 0.0
	log_open = true
	_update_scroll_height()

	# Matikan interaksi tombol intlog selagi tersembunyi
	intlog.disabled = true
	intlog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	idcard.disabled = true
	idcard.visible = false

	# Siapkan LogTitle buat fade-in
	log_title.visible = true
	log_title.modulate.a = 0.0

	# Siapkan back_button buat fade-in
	back_button.visible = true
	back_button.modulate.a = 0.0
	back_button.disabled = true

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
	panel_tween.chain().tween_callback(func():
		if not log_open:
			return
		intlog.visible = false
		back_button.disabled = interaction_locked
	)

	_animate_buttons_in()
	log_panel_opened.emit()


func close_log_panel() -> void:
	if not log_open or interaction_locked:
		return

	log_open = false
	_stop_log_scroll_tween()
	back_button.disabled = true
	_stop_question_button_animations()
	_set_question_buttons_disabled(true)

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
		back_button.disabled = interaction_locked
		intlog.disabled = interaction_locked
		intlog.mouse_filter = Control.MOUSE_FILTER_STOP
		idcard.disabled = interaction_locked
		idcard.visible = true
		_set_question_buttons_disabled(interaction_locked)
		log_panel_closed.emit()
		if not interaction_locked:
			intlog.grab_focus()
	)


func _animate_buttons_in() -> void:
	_stop_question_button_animations()
	var children := log_list.get_children()
	var first_button: BaseButton = null
	for child in children:
		if child is BaseButton:
			first_button = child as BaseButton
			break

	for i in children.size():
		var btn := children[i] as BaseButton
		if btn == null:
			continue
		btn.disabled = true
		btn.modulate.a = 0.0

		var t := create_tween()
		t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_interval(i * stagger_delay)
		t.tween_property(btn, "modulate:a", 1.0, button_appear_duration)
		t.chain().tween_callback(func():
			if log_open and is_instance_valid(btn):
				btn.disabled = interaction_locked
				if not interaction_locked and btn == first_button:
					btn.grab_focus()
		)
		question_button_tweens.append(t)


func _stop_question_button_animations() -> void:
	for tween in question_button_tweens:
		if is_instance_valid(tween):
			tween.kill()
	question_button_tweens.clear()


func _set_question_buttons_disabled(disabled: bool) -> void:
	for child in log_list.get_children():
		var button := child as BaseButton
		if button:
			button.disabled = disabled


func _scroll_log_smoothly(delta: float) -> void:
	var vertical_scrollbar := log_scroll.get_v_scroll_bar()
	var maximum_scroll := floorf(maxf(0.0, vertical_scrollbar.max_value - vertical_scrollbar.page))
	var current_target := float(log_scroll.scroll_vertical)
	if log_scroll_tween and log_scroll_tween.is_running():
		current_target = log_scroll_target

	log_scroll_target = roundf(clampf(current_target + delta, 0.0, maximum_scroll))
	if is_equal_approx(log_scroll.scroll_vertical, log_scroll_target):
		return

	if log_scroll_tween and log_scroll_tween.is_running():
		log_scroll_tween.kill()
	log_scroll_tween = create_tween()
	log_scroll_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	log_scroll_tween.tween_property(log_scroll, "scroll_vertical", int(log_scroll_target), LOG_SCROLL_TWEEN_DURATION)


func _stop_log_scroll_tween() -> void:
	if log_scroll_tween and log_scroll_tween.is_running():
		log_scroll_tween.kill()
	log_scroll_tween = null
	log_scroll_target = float(log_scroll.scroll_vertical)


func _on_button_down(button: TextureButton) -> void:
	_animate_button(button, press_scale, 0.08, Tween.TRANS_SINE)


func _on_button_up(button: TextureButton) -> void:
	_animate_button(button, Vector2.ONE, 0.12, Tween.TRANS_BACK)


func _on_hover(button: TextureButton) -> void:
	_animate_button(button, Vector2(1.08, 1.08), 0.15, Tween.TRANS_BACK)


func _on_exit(button: TextureButton) -> void:
	_animate_button(button, Vector2.ONE, 0.15, Tween.TRANS_SINE)


func _animate_button(
	button: TextureButton,
	target_scale: Vector2,
	duration: float,
	transition: Tween.TransitionType
) -> void:
	var button_id := button.get_instance_id()
	var button_tween := button_tweens.get(button_id) as Tween
	if button_tween:
		button_tween.kill()

	button_tween = create_tween()
	button_tweens[button_id] = button_tween
	button_tween.set_trans(transition)
	button_tween.set_ease(Tween.EASE_OUT)
	button_tween.tween_property(button, "scale", target_scale, duration)
