extends Marker3D

@onready var camera = $Camera3D
@onready var origin = $"."

var v_right = Vector3(1, 0, 0) # Or Vector3.RIGHT -> rotates up and down
var v_up = Vector3(0, 1, 0) # Or Vector3.UP -> rotates left and right
var rotation_amount := 0.01
var desired_zoom := 5.0
@onready var mesh_placeholder: MeshInstance3D = $"../mesh-placeholder"

@export var models = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
	camera.position.z = desired_zoom
	#desired_rot = origin.rotation
	Global.yell()
	pass # Replace with function body.

var mouse_left_down: bool = false
var lerped_change := Vector2(0,0)

var mouse_start := Vector2(0,0)
var mouse_change := Vector2(0,0)
var mouse_now := Vector2(0,0)
# var zoom_level := 10

@export var zoom_min := 0.5
@export var zoom_max := 20

var current_model = 0

var usingTouch := false
var pinchStartDist := 0.0
var pinchDist := 0.0

func _input( event ):
	
	if event is InputEventScreenTouch:
		pinchStartDist = 0.0
		#usingTouch = true
		print('touch')
		pass
	
	if event is InputEventScreenPinch:
		#usingTouch = true
		if(pinchStartDist == 0.0):
			pinchStartDist = event.distance
		pinchDist = pinchStartDist - event.distance
		# desired_zoom = 0.5 (close) - 20 (far), 5 by default
		print('pinch: ' + str(pinchDist))
		
		desired_zoom = clamp(pinchDist/10, zoom_min, zoom_max)
		pass
	if event is InputEventMultiScreenDrag	:
		#usingTouch = true
		print('drag 2')
	
	if event is InputEventScreenDrag:
		#usingTouch = true
		print('drag 1')
		pass
	# click
	if event is InputEventMouseButton and not usingTouch:
		if event.button_index == 1 and event.is_pressed():
			mouse_left_down = true
			mouse_start = event.position;
			lerped_change = Vector2(0,0)
			
		elif event.button_index == 1 and not event.is_pressed():
			mouse_left_down = false
			mouse_change = Vector2(0,0)
		
		# zoom
		if event.is_action('zoom_in'):
			#zoom_level -= 1
			desired_zoom = clamp(desired_zoom + 0.1, zoom_min, zoom_max)
		elif event.is_action('zoom_out'):
			#zoom_level += 1
			desired_zoom = clamp(desired_zoom - 0.1, zoom_min, zoom_max)
			
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
	if mouse_left_down and not usingTouch:
		mouse_now = get_viewport().get_mouse_position()
		mouse_change = mouse_start - mouse_now
		mouse_start = mouse_now
		
	# lerped rotation
	lerped_change = lerped_change.lerp(mouse_change,0.1)
	# print(lerped_change)
	# apply rotation (by 2 axes)
	rotate(v_up,rotation_amount * lerped_change[0])
	rotate_object_local(v_right,rotation_amount * lerped_change[1])
		
	# zoom
	camera.position.z = lerp(camera.position.z, desired_zoom,0.1)
	print(desired_zoom)
	
	# zoom
