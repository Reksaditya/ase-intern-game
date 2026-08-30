extends Node2D
class_name Bunker

@onready var dialog_label: Label = $Dialog

## Semua array di bawah ini bisa diubah langsung lewat Inspector (klik node bunker),
## atau lewat kode di sini. Tambah/kurangi baris sesuka hati.

@export var emotional_questions: Array[String] = [
	"Apakah kamu mengenal Wowok the MBG?",
	"Bagaimana pendapatmu soal negara ini?"
]

@export var factual_questions: Array[String] = [
	"Apakah MBG berguna?",
	"Siapa yang membuat kamu memilih nomor ganda itu?",
	"Ceritakan alasanmu tidak memilih 03!",
]

@export var trap_questions: Array[String] = [
	"Tadi kamu bilang karena kemauan kamu sendiri, kenapa tiba-tiba gara-gara ada serangan fajar? Coba jelaskan!",
	"Kalo kamu golput, kenapa jarimu ada bekas tinta pemilu",
	"Coba ulangi ceritamu tadi — kok beda dari yang pertama?",
]

@export var clarification_questions: Array[String] = [
	"Maksudmu apa dengan 'terlambat'? Berapa lama?",
	"Bisa dijelaskan lagi bagian itu?",
	"Kamu tadi bilang 'mereka' — siapa saja yang kamu maksud?",
]

var current_tween: Tween


func _ready() -> void:
	dialog_label.modulate.a = 1.0


func _get_pool(category: String) -> Array:
	match category:
		"emotional":
			return emotional_questions
		"factual":
			return factual_questions
		"trap":
			return trap_questions
		"clarification":
			return clarification_questions
		_:
			return []


## Panggil fungsi ini dari luar (misal lewat signal television.category_selected)
func show_question(category: String) -> void:
	var pool := _get_pool(category)
	var question: String = pool.pick_random() if not pool.is_empty() else "..."

	if current_tween:
		current_tween.kill()

	current_tween = create_tween()
	current_tween.tween_property(dialog_label, "modulate:a", 0.0, 0.12)
	current_tween.tween_callback(func(): dialog_label.text = question)
	current_tween.tween_property(dialog_label, "modulate:a", 1.0, 0.18)
