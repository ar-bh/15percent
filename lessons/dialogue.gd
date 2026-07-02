extends Control

@onready var rich_text_label: RichTextLabel = %RichTextLabel
@onready var next_button: Button = %NextButton
@onready var previous_button: Button = %PreviousButton

@onready var audio_stream_player: AudioStreamPlayer = %AudioStreamPlayer


@onready var body: TextureRect = %Body
@onready var expression: TextureRect = %Expression

var expressions := {
	"happy": preload("res://assets/emotion_happy.png"),
	"regular": preload ("res://assets/emotion_regular.png"),
	"sad": preload ("res://assets/emotion_sad.png"),
}


var dialogue_items : Array[Dictionary] = [
	{
		"expression": expressions["regular"],
		"text": "I finally joined stardance challenge hackathon",
	},
	{
		"expression": expressions["sad"],
		"text": "I joined a little late though",
	},
	{
		"expression": expressions["happy"],
		"text": "But I will clutch"
	},
	{
		"expression": expressions["happy"],
		"text": "And win all the prizes"
	},

]
var current_item_index := 0




func _ready() -> void:
	show_text()
	next_button.pressed.connect(advance)
	previous_button.pressed.connect(previous)


func show_text() -> void:
	var current_item := dialogue_items[current_item_index]
	rich_text_label.text = current_item["text"]
	expression.texture = current_item["expression"]
	
	rich_text_label.visible_ratio = 0.0
	var tween = create_tween()
	var text_appearing_duration: float = current_item["text"].length() / 20.0
	tween.tween_property(rich_text_label,'visible_ratio', 1.0, text_appearing_duration)
	var sound_max_offset := audio_stream_player.stream.get_length() - text_appearing_duration
	var sound_start_position := randf() * sound_max_offset
	audio_stream_player.play(sound_start_position)
	tween.finished.connect(audio_stream_player.stop)
	
	
	
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
