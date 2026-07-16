extends Control

#region background
@onready var background_texture1: TextureRect = $Background/Parallax2D/TextureRect
@onready var background_texture2: TextureRect = $Background/Parallax2D/TextureRect2
@onready var background_parallax: Parallax2D = $Background/Parallax2D
#endregion

#region buttons
@onready var start_button: Button = $Menu/ButtonContainer/Start
@onready var options_button: Button = $Menu/ButtonContainer/Help
@onready var quit_button: Button = $Menu/ButtonContainer/Quit
#endregion

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_tree().root.size_changed.connect(_on_window_resized)
	start_button.pressed.connect(_on_start_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file('res://game/main_gameplay.tscn')
	
func _on_options_pressed() -> void:
	pass
	
func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_window_resized() -> void:
	background_texture1.size = get_viewport_rect().size
	background_texture2.size = get_viewport_rect().size
	background_parallax.repeat_size = get_viewport_rect().size
