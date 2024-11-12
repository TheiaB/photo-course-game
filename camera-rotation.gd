extends Position3D

onready var camera = $Camera
onready var origin = $"."

var v_right = Vector3(1, 0, 0) # Or Vector3.RIGHT -> rotates up and down
var v_up = Vector3(0, 1, 0) # Or Vector3.UP -> rotates left and right
var rotation_amount = 0.01

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

var mouse_left_down: bool = false
var mouse_start := Vector2(0,0)
var mouse_change := Vector2(0,0)
var mouse_now := Vector2(0,0)

func _input( event ):
	# click
	if event is InputEventMouseButton:
		if event.button_index == 1 and event.is_pressed():
			mouse_left_down = true
			mouse_start = event.position;
		elif event.button_index == 1 and not event.is_pressed():
			mouse_left_down = false
			

func _process( delta ):
	# movement
	if mouse_left_down:
		mouse_now = get_viewport().get_mouse_position()
		mouse_change = mouse_start - mouse_now
		mouse_start = mouse_now
		rotate(v_up,rotation_amount * mouse_change[0])
		rotate_object_local(v_right,rotation_amount * mouse_change[1])

