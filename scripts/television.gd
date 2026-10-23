extends Sprite2D

signal category_selected(category: String)
signal id_card_requested

const BUTTON_SFX: AudioStream = preload("res://assets/bgm/button.mp3")

@onready var intlog: TextureButton = $intlog
@onready var idcard: TextureButton = $idcard
@onready var log_title: Label = $LogTitle
@onready var log_scroll: ScrollContainer = $LogScroll
@onready var log_list: VBoxContainer = $LogScroll/LogButtonList
@onready var back_button: Button = $BackButton

@onready var emotional_btn: TextureButton = $LogScroll/LogButtonList/emotional
@onready var factual_btn: TextureButton = $LogScroll/LogButtonList/factual
@onready var trap_btn: TextureButton = $LogScroll/LogButtonList/trap
@onready var clarification_btn: TextureButton = $LogScroll/LogButtonList/clarification

@export var press_scale: Vector2 = Vector2(0.95, 0.95)

@export var visible_button_count: int = 3
@export var panel_appear_duration: float = 0.35
@export var button_appear_duration: float = 0.3
@export var stagger_delay: float = 0.08

var button_tweens: Dictionary = {}
var panel_tween: Tween
var log_open: bool = false
var _button_sfx_player: AudioStreamPlayer


func _ready() -> void:
	# Semua koneksi sinyal dibuat di sini (bukan di panel Node > Signals),
	# jadi tidak ada koneksi ganda. _connect_once() menjaga agar aman
	# walaupun scene masih menyimpan koneksi lama.
	for button in [intlog, idcard]:
		_connect_once(button.mouse_entered, _on_hover.bind(button))
		_connect_once(button.mouse_exited, _on_exit.bind(button))
		_connect_once(button.button_down, _on_button_down.bind(button))
		_connect_once(button.button_up, _on_button_up.bind(button))
		_connect_once(button.focus_entered, _on_hover.bind(button))
	_connect_once(intlog.pressed, _on_intlog_pressed)
	_connect_once(idcard.pressed, _on_idcard_pressed)

	_connect_once(back_button.pressed, func():
		_play_button_sfx()
		close_log_panel()
	)

	back_button.visible = false
	back_button.modulate.a = 0.0

	# Setiap tombol kategori memancarkan category_selected dengan nama kategorinya
	emotional_btn.pressed.connect(_on_category_pressed.bind("emotional"))
	factual_btn.pressed.connect(_on_category_pressed.bind("factual"))
	trap_btn.pressed.connect(_on_category_pressed.bind("trap"))
	clarification_btn.pressed.connect(_on_category_pressed.bind("clarification"))

	log_scroll.modulate.a = 0.0
	log_scroll.scale = Vector2(0.9, 0.9)

	_button_sfx_player = AudioStreamPlayer.new()
	_button_sfx_player.stream = BUTTON_SFX
	_button_sfx_player.volume_db = -3.0
	add_child(_button_sfx_player)

	call_deferred("_update_scroll_height")


func _connect_once(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)


func _play_button_sfx() -> void:
	if is_instance_valid(_button_sfx_player):
		_button_sfx_player.play()


func _on_category_pressed(category: String) -> void:
	_play_button_sfx()
	category_selected.emit(category)


func _on_idcard_pressed() -> void:
	_play_button_sfx()
	id_card_requested.emit()


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
	_play_button_sfx()
	if log_open:
		close_log_panel()
	else:
		open_log_panel()


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


# --- Animasi tombol intlog & idcard (hover / tekan) -------------------------

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
