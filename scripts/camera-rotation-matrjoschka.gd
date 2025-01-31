extends Marker3D

@onready var camera = $Camera3D
@onready var origin = $"."

var v_right = Vector3(1, 0, 0) # Or Vector3.RIGHT -> rotates up and down
var v_up = Vector3(0, 1, 0) # Or Vector3.UP -> rotates left and right
var rotation_amount := 0.01
var desired_zoom := 5.0
@onready var mesh_placeholder: MeshInstance3D = $"../mesh-placeholder"
@onready var scene_manager: Node3D = $"../scene-manager"

# @export var models = {}
@export var scenes = []
var scene_int := 0
@export var current_scene:Node

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
@export var zoom_max := 20.0

var current_model = 0

var usingTouch := false
var pinchStartDist := 0.0
var pinchDist := 0.0
var start_zoom := 0.0
var dragging := false
var pinching := false

var touch_down := false

func _input( event ):
	
	if event is InputEventScreenTouch:
		pinchStartDist = 0.0
		usingTouch = true
		print('touch')
		pass
	
	if event is InputEventScreenPinch:
		usingTouch = true
		pinching = true
		dragging = false
		if(pinchStartDist == 0.0):
			pinchStartDist = event.distance
			start_zoom = camera.position.z
		pinchDist = pinchStartDist - event.distance
		print('pinch: ' + str(pinchDist))
		desired_zoom = pinchDist/10 # clamp(pinchDist/10, zoom_min, zoom_max)
		pass
	if event is InputEventMultiScreenDrag	:
		usingTouch = true
		print('drag 2')
	
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
		print(scenes)
		var scene = PackedScene.new()
		# current_scene.replace_by(scenes[scene_int])
		scene_int+=1
		
		
		# current_model = (current_model + 1) % models.size()
		# var material = models.get(models.keys()[current_model])
		# var model = models.keys()[current_model]
		
		# mesh_placeholder.mesh = model
		# mesh_placeholder.material_override = material
		
		pass
	
	
	# Dragging - start
	if event is InputEventSingleScreenTouch:
		usingTouch = true
		mouse_start = event.position;
		lerped_change = Vector2(0,0)
		mouse_start = event.position;
		pinching = false
	# Dragging - mouse change per frame
	if event is InputEventScreenDrag:
		if not pinching:
			print("drag 1")
			usingTouch = true
			mouse_now = event.position
			mouse_change = mouse_start - mouse_now
			mouse_start = mouse_now;
			dragging = true
		pass

func _process( delta ):
	# movement
	if mouse_left_down and not usingTouch:
		mouse_now = get_viewport().get_mouse_position()
		mouse_change = mouse_start - mouse_now
		mouse_start = mouse_now
	
	# reset when let go
	if dragging:
		dragging = false
	else:
		mouse_change = Vector2(0,0)
	if pinching:
		mouse_change = Vector2(0,0)
	else:
		# lerped rotation
		lerped_change = lerped_change.lerp(mouse_change,0.1)
		# apply rotation (by 2 axes)
		rotate(v_up,clamp(rotation_amount * lerped_change[0],-.05,.05))
		rotate_object_local(v_right,clamp(rotation_amount * lerped_change[1],-.05,.05))
		
	# zoom
	# set camera pos to lerp from pos rn -> zoom dist
	camera.position.z = lerp(camera.position.z,
		clamp(start_zoom + desired_zoom, zoom_min, zoom_max), # zoom dist is clamped
		0.1)
	
	# zoom
