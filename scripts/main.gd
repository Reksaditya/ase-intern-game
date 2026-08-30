extends Node2D

@onready var television = $Television
@onready var bunker: Bunker = $Bunker

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	television.category_selected.connect(bunker.show_question)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
