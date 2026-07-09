@tool
extends Control

@onready var _blur_color_rect: ColorRect = %BlurColorRect
@onready var _ui_panel_container: PanelContainer = %UIPanelContainer
@onready var _resume_button: Button = %ResumeButton
@onready var _quit_button: Button = %QuitButton


@export_range(0, 1.0) var menu_opened_amount := 0.0:
	set = set_menu_opened_amount
	
@export_range(0.1, 10.0, 0.01, "or_greater") var animation_duration := 2.3
var _tween: Tween
var _is_currently_opening := false	

func set_menu_opened_amount(amount: float) -> void:
	menu_opened_amount = amount
	visible = amount > 0.0
	
	if _ui_panel_container == null or _blur_color_rect == null:
		return

	_blur_color_rect.material.set_shader_parameter("blur_amount", lerp(0.0, 1.5, amount))
	_blur_color_rect.material.set_shader_parameter("saturation", lerp(1.0, 0.3, amount))
	_blur_color_rect.material.set_shader_parameter("tint_strength", lerp(0.0, 0.2, amount))
	_ui_panel_container.modulate.a = amount
	
	if not Engine.is_editor_hint():
		get_tree().paused = amount > 0.3

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
		
	if Engine.is_editor_hint():
		return
	
	menu_opened_amount = 0.0
	_resume_button.pressed.connect(toggle)
	_quit_button.pressed.connect(get_tree().quit)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func toggle() -> void:
	# Switch the variable to the opposite value: true becomes false, and false becomes true
	_is_currently_opening = not _is_currently_opening
	
	var target_amount := 1.0 if _is_currently_opening else 0.0
	
	var duration := absf(target_amount - menu_opened_amount) * animation_duration
	if _tween != null:
		_tween.kill()
		
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_QUART)
	_tween.tween_property(self, "menu_opened_amount", target_amount, duration)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()
