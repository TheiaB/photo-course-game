extends Marker3D

@onready var camera = $Camera3D
@onready var origin = $"."

var v_right = Vector3(1, 0, 0) # Or Vector3.RIGHT -> rotates up and down
var v_up = Vector3(0, 1, 0) # Or Vector3.UP -> rotates left and right
var rotation_amount := 0.01
var desired_zoom := 5.0
var camera_interpolation = true
@onready var mesh_placeholder: MeshInstance3D = $"../mesh-placeholder"
@onready var scene_manager: Node3D = $"../scene-manager"

# @export var models = {}
@export var scenes : Array[PackedScene] = []
var scene_int := 0
@export var current_scene:Node

@export var default_env:Environment = preload("res://config/default_env.tres")
@export var reset_env:Environment = preload("res://config/reset_env.tres")

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
	
	# --------------- TEMPROARY: reset black bg
	if(camera.environment == reset_env):
		camera.environment = default_env
		
	if event is InputEventScreenTouch:
		pinchStartDist = 0.0
		usingTouch = true
		print('touch')
		pass
	
	if event is InputEventScreenPinch and usingTouch:
		# usingTouch = true
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
		# click
		if event.button_index == 1 and event.is_pressed():
			mouse_left_down = true
			mouse_start = event.position;
			lerped_change = Vector2(0,0)
		
		# let go
		elif event.button_index == 1 and not event.is_pressed():
			mouse_left_down = false
			mouse_change = Vector2(0,0)
			user_clicked(event.position)
		
		# zoom
		if event.is_action('zoom_in'):
			#zoom_level -= 1
			desired_zoom = clamp(desired_zoom - 0.2, zoom_min, zoom_max)
		elif event.is_action('zoom_out'):
			#zoom_level += 1
			desired_zoom = clamp(desired_zoom + 0.2, zoom_min, zoom_max)
	
	# --------------- TEMPORARY: switch scene on click space
	if event.is_action_pressed('shuffle'):
		print('space')
		scene_int+=1
		next_scene(scene_int)
	
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
	
	# reset when let go
	if dragging:
		dragging = false
	else:
		mouse_change = Vector2(0,0)
	
	if pinching:
		mouse_change = Vector2(0,0)
	else: # Move and Rotate
		pass
		# move_and_rotate()
	
	if mouse_left_down and not usingTouch:
		mouse_now = get_viewport().get_mouse_position()
		mouse_change = mouse_start - mouse_now
		mouse_start = mouse_now
		# print('mouse drag')
	
	if(camera_interpolation):
		move_and_rotate()
		

func user_clicked( here ):
	print("click (start: "+str(mouse_start)+") end("+str(here)+")")
	if(mouse_start == here): # consider a click, rather than drag
		var space_state = get_world_3d().direct_space_state
		var origin = camera.project_ray_origin(here)
		var end = camera.project_position(here, 1000)
		var query = PhysicsRayQueryParameters3D.create(origin, end)
		var result = space_state.intersect_ray(query)
		if(result.get("collider") != null):
			# load next scene
			scene_int+=1
			next_scene(scene_int)
		pass
	pass

func next_scene(i):
	camera.environment = reset_env
	# Load new scene
	var new_scene = scenes[i % scenes.size()].instantiate()
	get_parent_node_3d().add_child(new_scene)
	
	# remove old scene
	current_scene.free()
	current_scene = new_scene
	
	# apply camera transforms
	for child in current_scene.get_children():
		if child is Camera3D:
			print(">>> apply camera")
			self.rotation = child.rotation
			camera.global_transform = child.transform
			desired_zoom = camera.position.z # auto prevent zooming back
			camera.fov = child.fov
		
	# dynamically apply texture to orb
	# load next scene
	var next_scene = scenes[(i+1) % scenes.size()].instantiate()
	var next_scene_mdl = next_scene.get_node_or_null("scene_model")
	if(next_scene_mdl != null):
		print(">>> apply material")
		# texture of following scene's model material
		var next_scene_mat: StandardMaterial3D = next_scene_mdl.get_surface_override_material(0)
		var next_image = next_scene_mat.emission_texture
		# applied to current sphere
		var current_sphere: MeshInstance3D = current_scene.get_node_or_null("scene_sphere")
		var current_sphere_mat: Material = current_sphere.get_surface_override_material(0)
		var current_sphere_scale: float = current_sphere.scale.x
		current_sphere_mat.set_shader_parameter("image",next_image);
		# default scale is optimized for 0.4, if sphere smaller, needs to apply smaller shader scale
		current_sphere_mat.set_shader_parameter("scale",current_sphere_scale/0.4);

func move_and_rotate():
	# zoom
	# set camera pos to lerp from pos rn -> zoom dist
	camera.position.z = lerp(camera.position.z,
		clamp(start_zoom + desired_zoom, zoom_min, zoom_max), # zoom dist is clamped
		0.1)
	
	# lerped rotation
	if (mouse_left_down and not usingTouch) or (not pinching):
		lerped_change = lerped_change.lerp(mouse_change,0.1)
		# apply rotation (by 2 axes)
		rotate(v_up,clamp(rotation_amount * lerped_change[0],-.05,.05))
		rotate_object_local(v_right,clamp(rotation_amount * lerped_change[1],-.05,.05))
