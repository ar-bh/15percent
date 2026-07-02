extends Control

@onready var rich_text_label: RichTextLabel = %RichTextLabel
@onready var next_button: Button = %NextButton
@onready var previous_button: Button = %PreviousButton

var dialogue_items : Array[String] = [
	"I want xbox from stardance challenge",
	"and apple devices",
	"and framework laptop so i can play my games",
	"and the socks!",
]
var current_item_index := 0


func _ready() -> void:
	show_text()
	next_button.pressed.connect(advance)
	previous_button.pressed.connect(previous)


func show_text() -> void:
	var current_item := dialogue_items[current_item_index]
	rich_text_label.text = current_item
	
	
func advance() -> void:
	move(1)
	
func previous() -> void:
	move(-1)
	
	
func move(amount) -> void:
	current_item_index += amount
	
	if current_item_index == dialogue_items.size():
		current_item_index = 0
	if current_item_index == -1:
		current_item_index = dialogue_items.size() - 1

	show_text()
