extends Control

#region background
@onready var background_texture1: TextureRect = $Background/Parallax2D/TextureRect
@onready var background_texture2: TextureRect = $Background/Parallax2D/TextureRect2
@onready var background_parallax: Parallax2D = $Background/Parallax2D

const BACKGROUND_TEXTURE_SIZE := Vector2(1920, 1080)
#endregion

#region buttons
@onready var start_button: Button = $Menu/ButtonContainer/Start
@onready var instructions_button: Button = $Menu/ButtonContainer/Help
@onready var quit_button: Button = $Menu/ButtonContainer/Quit
@onready var instructions_panel: Panel = $Menu/InstructionsPanel
@onready var close_instructions_button: Button = $Menu/InstructionsPanel/VBoxContainer/CloseButton
#endregion

func _ready() -> void:
	get_tree().root.size_changed.connect(_on_window_resized)
	start_button.pressed.connect(_on_start_pressed)
	instructions_button.pressed.connect(_on_instructions_pressed)
	close_instructions_button.pressed.connect(_on_close_instructions_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	_on_window_resized()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://game/main_gameplay.tscn")

func _on_instructions_pressed() -> void:
	instructions_panel.visible = true

func _on_close_instructions_pressed() -> void:
	instructions_panel.visible = false

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_window_resized() -> void:
	var viewport_size := get_viewport_rect().size

	var scale_factor := maxf(
		viewport_size.x / BACKGROUND_TEXTURE_SIZE.x,
		viewport_size.y / BACKGROUND_TEXTURE_SIZE.y
	)

	background_parallax.scale = Vector2(scale_factor, scale_factor)
	background_texture1.size = BACKGROUND_TEXTURE_SIZE
	background_texture2.size = BACKGROUND_TEXTURE_SIZE
	background_parallax.repeat_size = Vector2(BACKGROUND_TEXTURE_SIZE.x, 0.0)
