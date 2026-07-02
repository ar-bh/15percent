class_name SlideShowEntry extends Resource

@export_group("Images")
@export var expression: Texture = preload("res://assets/emotion_regular.png")
@export var character: Texture = preload("res://assets/sophia.png")

@export_group("Text")
@export_multiline var text := ""

@export_group("Voice")
@export var voice = preload("res://assets/talking_synth.ogg")
