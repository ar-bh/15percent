extends Control

var expressions := {
	"happy": preload ("res://assets/emotion_happy.png"),
	"regular": preload ("res://assets/emotion_regular.png"),
	"sad": preload ("res://assets/emotion_sad.png"),
}

var bodies := {
	"sophia": preload ("res://assets/sophia.png"),
	"pink": preload ("res://assets/pink.png")
}

## An array of dictionaries. Each dictionary has four properties:
## - expression: a [code]Texture[/code] containing an expression
## - text: a [code]String[/code] containing the text the character says
## - character: a [code]Texture[/code] representing the character, that we extract from the [code]bodies[/code] dictionary
## - choices: a [code]dictionary[/code] with [code]String[/code] keys and [code]int[/code] values
var dialogue_items: Array[Dictionary] = [
	{
		"expression": expressions["regular"],
		"text": "[wave]Hey, wake up![/wave]\nIt's time to make video games.",
		"character": bodies["sophia"],
		"choices": {
			"Let me sleep a little longer": 2,
			"Let's do it!": 1,
		},
	},
	{
		"expression": expressions["happy"],
		"text": "Great! Your first task will be to write a [b]dialogue tree[/b].",
		"character": bodies["sophia"],
		"choices": {
			"I will do my best": 3,
			"No, let me go back to sleep": 2,
		},
	},
	{
		"expression": expressions["sad"],
		"text": "Oh, come on! It'll be fun.",
		"character": bodies["pink"],
		"choices": {
			"No, really, let me go back to sleep": 0,
			"Alright, I'll try": 1,
		},
	},
	{
		"expression": expressions["happy"],
		"text": "That's the spirit! [wave]You can do it![/wave]",
		"character": bodies["pink"],
		"choices": {"Okay! (Quit)": - 1},
	},
]

## UI element that shows the texts
@onready var rich_text_label: RichTextLabel = %RichTextLabel
## Audio player that plays voice sounds while text is being written
@onready var audio_stream_player: AudioStreamPlayer = %AudioStreamPlayer
## The character
@onready var body: TextureRect = %Body
## The Expression
@onready var expression: TextureRect = %Expression
## The container for buttons
@onready var action_buttons_v_box_container: VBoxContainer = %ActionButtonsVBoxContainer


func _ready() -> void:
	show_text(0)

## Draws the selected text
## [param current_item_index] Displays the currently selected index from the dialogue array
func show_text(current_item_index: int) -> void:
	# We retrieve the current item from the array
	var current_item := dialogue_items[current_item_index]
	# from the item, we extract the properties.
	# We set the text to the rich text control
	# And we set the appropriate expression texture
	rich_text_label.text = current_item["text"]
	expression.texture = current_item["expression"]
	body.texture = current_item["character"]
	create_buttons(current_item["choices"])
	# We set the initial visible ratio to the text to 0, so we can change it in the tween
	rich_text_label.visible_ratio = 0.0
	# We create a tween that will draw the text
	var tween := create_tween()
	# A variable that holds the amount of time for the text to show, in seconds
	# We could write this directly in the tween call, but this is clearer.
	# We will also use this for deciding on the sound length
	var text_appearing_duration: float = current_item["text"].length() / 30.0
	# We show the text slowly
	tween.tween_property(rich_text_label, "visible_ratio", 1.0, text_appearing_duration)
	# We randomize the audio playback's start time to make it sound different
	# every time.
	# We obtain the last possible offset in the sound that we can start from
	var sound_max_offset := audio_stream_player.stream.get_length() - text_appearing_duration
	# We pick a random position on that length
	var sound_start_position := randf() * sound_max_offset
	# We start playing the sound
	audio_stream_player.play(sound_start_position)
	# We make sure the sound stops when the text finishes displaying
	tween.finished.connect(audio_stream_player.stop)

	# We animate the character sliding in.
	slide_in()

	# We disable the buttons, and re-enable them after the text is shown
	for button: Button in action_buttons_v_box_container.get_children():
		button.disabled = true
	tween.finished.connect(func() -> void:
		for button: Button in action_buttons_v_box_container.get_children():
			button.disabled = false
	)

## Adds buttons to the buttons container
## [param choices_data] A dictionary of [String] keys where each key represents
##                      a sentence that the player can select, and each [int] value
##                      represents a key for the next text item.
func create_buttons(choices_data: Dictionary) -> void:
	# We remove all previous buttons
	for button in action_buttons_v_box_container.get_children():
		button.queue_free()
	# We loop over all the dictionary keys
	for choice_text in choices_data:
		var button := Button.new()
		action_buttons_v_box_container.add_child(button)
		button.text = choice_text
		# We extract the target line index from the dictionary value
		var target_line_idx: int = choices_data[choice_text]
		if target_line_idx == - 1:
			# If the target line index is -1, we want to quit
			button.pressed.connect(get_tree().quit)
		else:
			# Otherwise we bind the target line index to the show_text function
			# and use that in the pressed signal's connection
			button.pressed.connect(show_text.bind(target_line_idx))

## Animates the character when they start talking
func slide_in() -> void:
	var slide_tween := create_tween()
	slide_tween.set_ease(Tween.EASE_OUT)
	body.position.x = get_viewport_rect().size.x / 7
	slide_tween.tween_property(body, "position:x", 0, 0.3)
	body.modulate.a = 0
	slide_tween.parallel().tween_property(body, "modulate:a", 1, 0.2)
