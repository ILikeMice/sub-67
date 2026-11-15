extends Sprite2D

@export var hover_texture: Texture2D

var normal_texture: Texture2D
@onready var area: Area2D = $Area2D


func _ready() -> void:
	normal_texture = texture
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	texture = hover_texture


func _on_mouse_exited() -> void:
	texture = normal_texture
