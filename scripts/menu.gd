extends Control

@onready var texture_camera: TextureRect = $"texture-camera"
@onready var animation_player: AnimationPlayer = $AnimationPlayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

var menu_open := true
func _input( event ):
	if event.is_action_pressed('quit'):
		print('esc')
		if(menu_open and !animation_player.is_playing()):
			animation_player.play('fullscreen')
			#menu_open = false
		elif(!animation_player.is_playing()):
			animation_player.play_backwards('fullscreen')
			#menu_open = true



func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	menu_open = !menu_open
	pass # Replace with function body.
