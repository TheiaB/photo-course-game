extends Marker3D

@onready var camera = $Camera3D
@onready var origin = $"."
@onready var mesh_placeholder: MeshInstance3D = $"../mesh-placeholder"
@onready var scene_manager: Node3D = $"../scene-manager"
@onready var transition_timer: Timer = $TransitionTimer
@onready var transition_anim_player: AnimationPlayer = $TransitionAnimPlayer
@onready var interaction_timer: Timer = $InteractionTimer
@onready var finger: TextureRect = $Camera3D/CanvasLayer/Finger
@onready var finger_anim: AnimationPlayer = $Camera3D/CanvasLayer/FingerAnim
@onready var hint_timer: Timer = $HintTimer
@onready var debugonscreen: Label = $Camera3D/CanvasLayer/ButtonDebug/LabelDebug

var v_right = Vector3(1, 0, 0) # Or Vector3.RIGHT -> rotates up and down
var v_up = Vector3(0, 1, 0) # Or Vector3.UP -> rotates left and right
var rotation_amount := 0.01
var desired_zoom := 5.0

# @export var models = {}
@export var scenes : Array[PackedScene] = []
var scene_int := 0

## How long the camera should take to lerp back to the original position.
@export_range(0.1,5.0) var transition_duration := 2.0
## How long after the last interaction until the scene should reset?
@export_range(2.0,60.0) var wait_until_reset_duration := 20.0
## How much time between the animated hand hints?
@export_range(3.0,12.0) var hint_frequency := 5.0

@export var zoom_min := 0.5
@export var zoom_max := 20.0

@export_group("Defaults")
@export var default_env:Environment = preload("res://config/default_env.tres")
@export var reset_env:Environment = preload("res://config/reset_env.tres")
@export var current_scene:Node

var current_sphere: MeshInstance3D
var transition_end_pos: Vector3
var transition_start_pos: Vector3
var transition_default_pos: Vector3
var transition_end_rot:Quaternion
var transition_start_rot:Quaternion
var transition_default_rot:Quaternion
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
var single_tap_works := false
var doubledragging := false

@export_group("Technically necessary")
@export var camera_animation_position: = 0.0
@export var camera_interpolation = true

# Called when the node enters the scene tree for the first time.
func _ready():
	#debugonscreen.hide()
	camera_interpolation = true
	randomize()
	camera.position.z = desired_zoom
	
	# get sphere reference
	current_sphere = current_scene.get_node_or_null("scene_sphere")
	
	# set animation speed
	transition_anim_player.speed_scale = 1.0/transition_duration
	transition_timer.wait_time = transition_duration
	interaction_timer.wait_time = wait_until_reset_duration
	hint_timer.wait_time = hint_frequency + finger_anim.get_animation('finger_swipe').length
	
	Global.yell()
	interaction_timer.start()
	
	# reszie
	get_tree().get_root().size_changed.connect(resize)
	resize()

func resize():
	pass

func _input( event ):
	
	if event is InputEventSingleScreenTap:
		print('tap 1')
		single_tap_works = true
		user_clicked(event.position)
		pass
	
	# --------------- TEMPROARY: reset black bg
	if(camera.environment == reset_env):
		camera.environment = default_env
		
	if event is InputEventScreenTouch:
		print('touch')
		interaction_timer.start()
		hint_timer.stop()
		if(not pinching):
			pinchStartDist = 0.0
		usingTouch = true
		pass
	
	if event is InputEventScreenPinch and usingTouch:
		interaction_timer.start()
		hint_timer.stop()
		#usingTouch = true
		pinching = true
		dragging = false
		doubledragging = false
		if(pinchStartDist == 0.0):
			pinchStartDist = event.distance
			start_zoom = camera.position.z
		pinchDist = pinchStartDist - event.distance
		print('pinch: ' + str(pinchDist))
		desired_zoom = pinchDist/10 # clamp(pinchDist/10, zoom_min, zoom_max)
		pass
	if event is InputEventMultiScreenDrag:
		interaction_timer.start()
		usingTouch = true
		doubledragging = true
		print('drag 2')
	
	# click -------------- MOUSE
	if event is InputEventMouseMotion and mouse_left_down:
		interaction_timer.start()
	if event is InputEventMouseButton and not usingTouch:
		interaction_timer.start()
		hint_timer.stop()
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
		load_scene(scene_int)
	
	# Dragging - start
	if event is InputEventSingleScreenTouch:
		print('touch 1')
		doubledragging = false
		dragging = false
		usingTouch = true
		mouse_start = event.position
		lerped_change = Vector2(0,0)
		pinching = false
		if(not single_tap_works) and (not dragging):
			user_clicked(event.position)
	# Dragging - mouse change per frame
	if event is InputEventSingleScreenDrag:
		if (not pinching) and (not doubledragging):
			print("drag 1")
			interaction_timer.start()
			usingTouch = true
			mouse_now = event.position
			mouse_change = mouse_start - mouse_now
			mouse_start = mouse_now
			dragging = true
		pass


func _process( delta ):
	debugonscreen.text = 'rest in: '+str(int(interaction_timer.time_left))+'\nhint in: '+str(int(hint_timer.time_left))
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
		transition_camera()
		pass

func user_clicked( here ):
	print("click (start: "+str(mouse_start)+") end("+str(here)+")")
	if(mouse_start == here and not (doubledragging)): # consider a click, rather than drag
		# default ray hit
		var space_state = get_world_3d().direct_space_state
		var origin = camera.project_ray_origin(here)
		var end = camera.project_position(here, 1000)
		var query = PhysicsRayQueryParameters3D.create(origin, end)
		var result = space_state.intersect_ray(query)
		# if orb is hit, start scene transition
		if(result.get("collider") != null) and transition_timer.is_stopped():
			scene_int+=1
			start_scene_transition()
		pass
	pass

func _on_transition_timer_timeout() -> void:
	load_scene(scene_int)
	pass # Replace with function body.

func start_scene_transition():
	# load next scene
	# automatically sets 
	camera_interpolation = false
	
	transition_start_pos = camera.global_position
	transition_end_pos = current_sphere.global_position
	
	print('start: ---- ',transition_start_pos, ' --- end --- ',transition_end_pos)
	# interpolates camera_animation_position from 0.0 to 1.0
	# at the end:
	#_on_transition_timer_timeout()
	#load_scene(scene_int)
	
	# OH MY GOD QUARTERNIONS ARE A MESS
	transition_start_rot = camera.global_transform.basis.get_rotation_quaternion().normalized()

	transition_end_rot = camera.global_transform.looking_at(current_sphere.global_position).basis.get_rotation_quaternion().normalized()
	
	# quick preview: set basis
	#camera.global_transform.basis = Basis(camera.global_transform.looking_at(current_sphere.global_position).basis.get_rotation_quaternion().normalized())
	
	# START TRANSITION
	transition_timer.start()
	interaction_timer.stop()
	transition_anim_player.stop()
	transition_anim_player.play('zoom_to_orb')

func transition_camera():
	#camera.look_at(transition_end_pos)
	camera.global_transform.basis = Basis(transition_start_rot.slerp(transition_end_rot, camera_animation_position))
	
	camera.global_position = lerp(transition_start_pos, transition_end_pos, camera_animation_position)
	#camera.global_position = transition_end_pos
	pass

func load_scene(i):
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
			start_zoom = 0.0
			camera.fov = child.fov # fit height on wider
		
	# dynamically apply texture to orb
	# load next scene
	var load_scene = scenes[(i+1) % scenes.size()].instantiate()
	var load_scene_mdl = load_scene.get_node_or_null("scene_model")
	if(load_scene_mdl != null):
		print(">>> apply material")
		# texture of following scene's model material
		var load_scene_mat: StandardMaterial3D = load_scene_mdl.get_surface_override_material(load_scene_mdl.get_surface_override_material_count()-1)
		var next_image = load_scene_mat.emission_texture
		# applied to current sphere
		current_sphere = current_scene.get_node_or_null("scene_sphere")
		# get the LAST material
		var current_sphere_mat: Material = current_sphere.get_surface_override_material(0)
		var current_sphere_scale: float = current_sphere.scale.x
		current_sphere_mat.set_shader_parameter("image",next_image)
		# default scale is optimized for 0.4, if sphere smaller, needs to apply smaller shader scale
		current_sphere_mat.set_shader_parameter("scale",current_sphere_scale/0.4)
		
		var image_aspect_ratio:float 	= float(next_image.get_width()) / float(next_image.get_height())
		var viewport_aspect_ratio:float = float(get_viewport().size.x) / float(get_viewport().size.y)
		#print('image: ',image_aspect_ratio)
		#print('viewp: ',viewport_aspect_ratio)
		# Calculate new FOV based on width fitting
		if(image_aspect_ratio > viewport_aspect_ratio):
			var original_half_fov = deg_to_rad(camera.fov) / 2.0
			var adjusted_half_fov = atan(tan(original_half_fov) * image_aspect_ratio / viewport_aspect_ratio)
			camera.fov = rad_to_deg(adjusted_half_fov * 2.0)
			
			# TEMPORARY: manual correction
	
	# set defaults
	transition_default_pos = camera.global_position
	transition_default_rot = camera.global_transform.basis.get_rotation_quaternion().normalized()

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
		
## INTERACTION TIMER:
## After inaction, it resets view
func _on_interaction_timer_timeout() -> void:
	reset_view()
	hint_timer.start()
	pass

## Plays animation to reset camera view
func reset_view():
	# ROTATION
	# current
	transition_start_pos = camera.global_position
	transition_start_rot = camera.global_transform.basis.get_rotation_quaternion().normalized()
	
	# default (peak in scene)
	transition_end_rot = transition_default_rot
	transition_end_pos = transition_default_pos
	
	transition_timer.start()
	interaction_timer.stop()
	transition_anim_player.play('zoom_to_start')

## HINT TIMER:
## play the finger animation
func _on_hint_timer_timeout() -> void:
	finger_anim.stop()
	finger_anim.play('finger_swipe')
	pass # Replace with function body.

# ON DOUBLE CLICK, HIDE DEBUG
@onready var debug_button_timer: Timer = $Camera3D/CanvasLayer/ButtonDebug/Timer
var debug_button_amount := 0
func _on_button_pressed() -> void:
	if(debug_button_timer.is_stopped()):
		debug_button_amount = 0
		debug_button_timer.start()
	if debugonscreen.visible:
		debugonscreen.hide()
	else:
		debug_button_amount+=1
	# only show if double clicked
	if(debug_button_amount == 2):
		debug_button_timer.stop()
		debugonscreen.show()
	#debugonscreen.get_child(0).queue_free()
	#reset_view()
	#hint_timer.start()
	pass # Replace with function body.
