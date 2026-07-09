class_name Runner extends CharacterBody2D


signal walked_to

@export var max_speed := 600.0
## How much speed is added per second when the player presses a movement key.
@export var acceleration := 1200.0
## How much speed is lost per second when the player releases all movement keys.
@export var deceleration := 1080.0

@onready var _runner_visual: RunnerVisual = %RunnerVisualRed

@onready var _dust: GPUParticles2D = %Dust



func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var has_input_direction := direction.length() > 0.0
	if has_input_direction:
		var desired_velocity := direction * max_speed
		velocity = velocity.move_toward(desired_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
		
	move_and_slide()

	if direction.length() > 0.0:
		_runner_visual.angle = rotate_toward(_runner_visual.angle, direction.orthogonal().angle(), 8.0 * delta)
		var current_speed_percent := velocity.length() / max_speed
		_runner_visual.animation_name = (
			RunnerVisual.Animations.WALK
			if current_speed_percent < 0.8
			else RunnerVisual.Animations.RUN
		)
		
	else:
		_runner_visual.animation_name = RunnerVisual.Animations.IDLE
	
	_dust.emitting = velocity.length() > 200


func walk_to(destination_global_position: Vector2) -> void:
	var direction := global_position.direction_to(destination_global_position)
	_runner_visual.angle = direction.orthogonal().angle()
	_runner_visual.animation_name = RunnerVisual.Animations.WALK
	_dust.emitting = true
	
	var distance := global_position.distance_to(destination_global_position)
	var duration := distance / (max_speed * 0.2)
	
	var tween := create_tween()
	tween.tween_property(self, "global_position", destination_global_position, duration)
	tween.finished.connect(func():
		_runner_visual.animation_name = RunnerVisual.Animations.IDLE
		_dust.emitting = false
		walked_to.emit()
		)
		
