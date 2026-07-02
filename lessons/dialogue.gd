extends Control

@onready var rich_text_label: RichTextLabel = %RichTextLabel
@onready var next_button: Button = %NextButton
@onready var previous_button: Button = %PreviousButton

@onready var audio_stream_player: AudioStreamPlayer = %AudioStreamPlayer


@onready var body: TextureRect = %Body
@onready var expression: TextureRect = %Expression

var bodies := {
	"sophia": preload("res://assets/sophia.png"),
	"pink": preload("res://assets/pink.png"),
}

var expressions := {
	"happy": preload("res://assets/emotion_happy.png"),
	"regular": preload ("res://assets/emotion_regular.png"),
	"sad": preload ("res://assets/emotion_sad.png"),
}

var audios := {
	"sophia": preload("res://assets/talking_synth.ogg"),
	"pink": preload("res://assets/talking_synth_alternate.ogg"),
}

var dialogue_items: Array[Dictionary] = [
	{
		"expression": expressions["regular"],
		"text": "I've been studying arrays and dictionaries lately.",
		"character": bodies["sophia"],
		"voice": audios["sophia"],
	},
	{
		"expression": expressions["regular"],
		"text": "Oh, nice. How has it been going?",
		"character": bodies["pink"],
		"voice": audios["pink"],
	},
	{
		"expression": expressions["sad"],
		"text": "Well... it's a little complicated!",
		"character": bodies["sophia"],
		"voice": audios["sophia"],
	},
	{
		"expression": expressions["sad"],
		"text": "Oh!",
		"character": bodies["pink"],
		"voice": audios["pink"],
	},
	{
		"expression": expressions["regular"],
		"text": "It sure takes time to click at first.",
		"character": bodies["pink"],
		"voice": audios["pink"],
	},
	{
		"expression": expressions["happy"],
		"text": "If you keep at it, eventually, you'll get the hang of it!",
		"character": bodies["pink"],
		"voice": audios["pink"],
	},
	{
		"expression": expressions["regular"],
		"text": "Mhhh... I see. I'll keep at it, then.",
		"character": bodies["sophia"],
		"voice": audios["sophia"],
	},
	{
		"expression": expressions["happy"],
		"text": "Thanks for the encouragement. Time to LEARN!!!",
		"character": bodies["sophia"],
		"voice": audios["sophia"]
	},
]
var current_item_index := 0




func _ready() -> void:
	show_text()
	next_button.pressed.connect(advance)
	previous_button.pressed.connect(previous)


func slide_in() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	
	body.position.x = 200.0
	tween.tween_property(body, "position:x", 0.0, 0.3)
	body.modulate.a = 0.0
	tween.parallel().tween_property(body, "modulate:a", 1.0, 0.2)



func show_text() -> void:
	var current_item := dialogue_items[current_item_index]
	rich_text_label.text = current_item["text"]
	expression.texture = current_item["expression"]
	body.texture = current_item["character"]
	audio_stream_player.stream = current_item["voice"]
	
	rich_text_label.visible_ratio = 0.0
	var tween = create_tween()
	var text_appearing_duration: float = current_item["text"].length() / 30.0
	tween.tween_property(rich_text_label,'visible_ratio', 1.0, text_appearing_duration)
	var sound_max_offset := audio_stream_player.stream.get_length() - text_appearing_duration
	var sound_start_position := randf() * sound_max_offset
	audio_stream_player.play(sound_start_position)
	tween.finished.connect(audio_stream_player.stop)
	
	slide_in()
	
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
