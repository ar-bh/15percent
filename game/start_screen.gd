extends Control

#region background
@onready var background: Control = $Background
@onready var background_texture: TextureRect = $Background/Parallax2D/TextureRect
@onready var background_parallax: Parallax2D = $Background/Parallax2D

const BACKGROUND_TEXTURE_SIZE := Vector2(2165, 1080)
#endregion

#region buttons
@onready var start_button: Button = $Menu/ButtonContainer/Start
@onready var instructions_button: Button = $Menu/ButtonContainer/Help
@onready var quit_button: Button = $Menu/ButtonContainer/Quit
@onready var instructions_panel: Panel = $Menu/InstructionsPanel
@onready var close_instructions_button: Button = $Menu/InstructionsPanel/VBoxContainer/CloseButton
@onready var instructions_label: Label = $Menu/InstructionsPanel/VBoxContainer/InstructionsLabel
#endregion

const INSTRUCTIONS_TEXT := (
	"Hold the mouse button or press E to enter cutting mode. "
	+ "Your cursor becomes a chainsaw — the blade tip is where you click.\n\n"
	+ "Slide fast across the shape so your cut crosses exactly two edges. "
	+ "Start inside the shape and exit outside, or cut straight across while holding cut mode. "
	+ "You need enough speed, and you have a short time window once you enter the shape.\n\n"
	+ "Keep all orange pointers on the same piece. "
	+ "If a cut separates them onto different pieces, you lose.\n\n"
	+ "Cut the remaining area down to 15% or less to beat the level, "
	+ "then press Next for a new random shape and one extra pointer."
)

func _ready() -> void:
	get_tree().root.size_changed.connect(_on_window_resized)
	start_button.pressed.connect(_on_start_pressed)
	instructions_button.pressed.connect(_on_instructions_pressed)
	close_instructions_button.pressed.connect(_on_close_instructions_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	instructions_label.text = INSTRUCTIONS_TEXT
	MouseCursor.apply_default()
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

	background.size = viewport_size

	var scale_factor := maxf(
		viewport_size.x / BACKGROUND_TEXTURE_SIZE.x,
		viewport_size.y / BACKGROUND_TEXTURE_SIZE.y
	)

	background_parallax.scale = Vector2(scale_factor, scale_factor)
	background_texture.size = BACKGROUND_TEXTURE_SIZE
	background_parallax.repeat_size = BACKGROUND_TEXTURE_SIZE
