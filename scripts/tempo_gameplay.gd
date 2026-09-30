extends Node2D

@onready var television: Sprite2D = $Television
@onready var bunker: Bunker = $Bunker


func _ready() -> void:
	# Kategori yang ditekan di TV -> tampilkan pertanyaan di bunker.
	television.category_selected.connect(_on_category_selected)


func _on_category_selected(category: String) -> void:
	bunker.show_question(category)
