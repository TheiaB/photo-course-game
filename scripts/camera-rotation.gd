extends Marker3D

@onready var camera = $Camera3D
@onready var origin = $"."

var v_right = Vector3(1, 0, 0) # Or Vector3.RIGHT -> rotates up and down
var v_up = Vector3(0, 1, 0) # Or Vector3.UP -> rotates left and right
var rotation_amount := 0.01
@onready var mesh_placeholder: MeshInstance3D = $"../mesh-placeholder"

@export var models = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
	camera.position.z = 5
	Global.yell()
	pass # Replace with function body.

var mouse_left_down: bool = false
var mouse_start := Vector2(0,0)
var mouse_change := Vector2(0,0)
var mouse_now := Vector2(0,0)
# var zoom_level := 10

@export var zoom_min := 0.5
@export var zoom_max := 10

var current_model = 0


func _input( event ):
	# click
	if event is InputEventMouseButton:
		if event.button_index == 1 and event.is_pressed():
			mouse_left_down = true
			mouse_start = event.position;
			
		elif event.button_index == 1 and not event.is_pressed():
			mouse_left_down = false
		
		# zoom
		if event.is_action('zoom_in'):
			#zoom_level -= 1
			camera.position.z = clamp(camera.position.z + 0.1, zoom_min, zoom_max)
			print(camera.position.z)
		elif event.is_action('zoom_out'):
			#zoom_level += 1
			camera.position.z = clamp(camera.position.z - 0.1, zoom_min, zoom_max)
			print(camera.position.z)
			
	if event.is_action_pressed('shuffle'):
		print('space')
		current_model = (current_model + 1) % models.size()
		var material = models.get(models.keys()[current_model])
		var model = models.keys()[current_model]
		
		mesh_placeholder.mesh = model
		mesh_placeholder.material_override = material
		
		pass
			

func _process( delta ):
	# movement
	if mouse_left_down:
		mouse_now = get_viewport().get_mouse_position()
		mouse_change = mouse_start - mouse_now
		mouse_start = mouse_now
		rotate(v_up,rotation_amount * mouse_change[0])
		rotate_object_local(v_right,rotation_amount * mouse_change[1])
	
	# zoom
