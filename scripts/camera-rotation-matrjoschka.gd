extends Marker3D

@onready var camera = $Camera3D
@onready var origin = $"."
@onready var mesh_placeholder: MeshInstance3D = $"../mesh-placeholder"
@onready var scene_manager: Node3D = $"../scene-manager"
@onready var transition_timer: Timer = $TransitionTimer
@onready var transition_anim_player: AnimationPlayer = $TransitionAnimPlayer

var v_right = Vector3(1, 0, 0) # Or Vector3.RIGHT -> rotates up and down
var v_up = Vector3(0, 1, 0) # Or Vector3.UP -> rotates left and right
var rotation_amount := 0.01
var desired_zoom := 5.0

# @export var models = {}
@export var scenes : Array[PackedScene] = []
var scene_int := 0

@export_range(0.1,5.0) var transition_duration := 1.0
@export var zoom_min := 0.5
@export var zoom_max := 20.0

@export_group("Defaults")
@export var default_env:Environment = preload("res://config/default_env.tres")
@export var reset_env:Environment = preload("res://config/reset_env.tres")
@export var current_scene:Node

var current_sphere: MeshInstance3D
var sphere_pos: Vector3
var transition_start_pos: Vector3
var transition_start_rot:Quaternion
var transition_end_rot:Quaternion
var mouse_left_down: bool = false
var lerped_change := Vector2(0,0)

# mouse vars
var mouse_start := Vector2(0,0)
var mouse_change := Vector2(0,0)
var mouse_now := Vector2(0,0)

var current_model = 0
# touch / interaction vars
var usingTouch := false
var pinchStartDist := 0.0
var pinchDist := 0.0
var start_zoom := 0.0
var dragging := false
var pinching := false
var touch_down := false

@export_group("Technically necessary")
@export var camera_animation_position: = 0.0
@export var camera_interpolation = true

# Called when the node enters the scene tree for the first time.
func _ready():
	camera_interpolation = true
	randomize()
	camera.position.z = desired_zoom
	# get sphere reference
	current_sphere = current_scene.get_node_or_null("scene_sphere")
	# set animation speed
	transition_anim_player.speed_scale = 1.0/transition_duration
	transition_timer.wait_time = transition_duration
	Global.yell()
	pass # Replace with function body.

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
		#usingTouch = true
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
			mouse_start = event.position
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
		mouse_start = event.position
		lerped_change = Vector2(0,0)
		mouse_start = event.position
		pinching = false
	# Dragging - mouse change per frame
	if event is InputEventScreenDrag:
		if not pinching:
			print("drag 1")
			usingTouch = true
			mouse_now = event.position
			mouse_change = mouse_start - mouse_now
			mouse_start = mouse_now
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
		#move_and_rotate()
	
	if mouse_left_down and not usingTouch:
		mouse_now = get_viewport().get_mouse_position()
		mouse_change = mouse_start - mouse_now
		mouse_start = mouse_now
		#print('mouse drag')
	
	if(camera_interpolation):
		move_and_rotate()
	else:
		zoom_into_orb()
		pass
	print(camera.global_transform)

func user_clicked( here ):
	print("click (start: "+str(mouse_start)+") end("+str(here)+")")
	if(mouse_start == here): # consider a click, rather than drag
		var space_state = get_world_3d().direct_space_state
		var origin = camera.project_ray_origin(here)
		var end = camera.project_position(here, 1000)
		var query = PhysicsRayQueryParameters3D.create(origin, end)
		var result = space_state.intersect_ray(query)
		if(result.get("collider") != null) and transition_timer.is_stopped():
			# load next scene
			scene_int+=1
			transition_timer.start()
			transition_anim_player.play('zoom_to_orb')
			# automatically sets 
			camera_interpolation = false
			
			transition_start_pos = camera.global_position
			sphere_pos = current_sphere.global_position
			
			print('start: ---- ',transition_start_pos, ' --- end --- ',sphere_pos)
			# interpolates camera_animation_position from 0.0 to 1.0
			# at the end:
			#_on_transition_timer_timeout()
			#next_scene(scene_int)
			
			transition_start_rot = Quaternion(camera.global_transform.basis)
			# look *away* from camera
			#transition_end_rot = Quaternion(camera.global_transform.looking_at(
			#	(transition_start_pos - sphere_pos) * -2.0
			#))
			transition_end_rot = Quaternion().normalized()
			
			transition_start_rot = camera.quaternion
			
			#current_sphere.look_at(-camera.global_position)
			#transition_end_rot = current_sphere.quaternion
			
			camera.global_transform = camera.global_transform.looking_at(current_sphere.global_position)
			
			camera.global_transform.basis = Basis(camera.global_transform.looking_at(current_sphere.global_position).basis.get_rotation_quaternion().normalized())
			#camera.transform.basis = Basis(transition_end_rot)
		pass
	pass

func _on_transition_timer_timeout() -> void:
	next_scene(scene_int)
	pass # Replace with function body.

func zoom_into_orb():
	#camera.look_at(sphere_pos)
	#camera.quaternion = transition_start_rot.slerp(transition_end_rot, camera_animation_position)
	#camera.transform.basis = Basis(transition_start_rot.slerp(transition_end_rot, camera_animation_position))
	
	camera.global_position = lerp(transition_start_pos, sphere_pos, camera_animation_position)
	#camera.global_position = sphere_pos
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
			camera.transform = Transform3D()# child.global_transform
			camera.global_position = child.global_position
			camera_interpolation = true
			desired_zoom = camera.position.z # auto prevent zooming back
			camera.fov = child.fov * 0.75
		
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
		current_sphere = current_scene.get_node_or_null("scene_sphere")
		var current_sphere_mat: Material = current_sphere.get_surface_override_material(0)
		var current_sphere_scale: float = current_sphere.scale.x
		current_sphere_mat.set_shader_parameter("image",next_image)
		# default scale is optimized for 0.4, if sphere smaller, needs to apply smaller shader scale
		current_sphere_mat.set_shader_parameter("scale",current_sphere_scale/0.4)

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
