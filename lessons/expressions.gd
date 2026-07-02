extends Control

var bodies := {
	"sophia": preload("res://assets/sophia.png"),
	"pink": preload("res://assets/pink.png")
}

var expressions := {
	"happy": preload("res://assets/emotion_happy.png"),
	"regular": preload("res://assets/emotion_regular.png"),
	"sad": preload("res://assets/emotion_sad.png"),
}

@onready var body: TextureRect = %Body
@onready var expression: TextureRect = %Expression
@onready var row_bodies: HBoxContainer = %RowBodies
@onready var row_expressions: HBoxContainer = %RowExpressions

func _ready() -> void:
	create_buttons()
	
func create_buttons() -> void:
	for current_body: String in bodies:
		var button := Button.new()
		row_bodies.add_child(button)
		button.text = current_body.capitalize()
		button.pressed.connect(func() -> void:
			body.texture = bodies[current_body]	
		)
	for current_expression: String in expressions:
		var button := Button.new()
		row_expressions.add_child(button)
		button.text = current_expression.capitalize()
		button.pressed.connect(func() -> void:
			expression.texture = expressions[current_expression]	
		)
