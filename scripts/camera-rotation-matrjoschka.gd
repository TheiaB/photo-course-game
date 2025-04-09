extends Marker3D

@onready var camera = $Camera3D
@onready var origin = $"."
#@onready var mesh_placeholder: MeshInstance3D = $"../mesh-placeholder"
#@onready var scene_manager: Node3D = $"../scene-manager"
@onready var transition_timer: Timer = $TransitionTimer
@onready var transition_anim_player: AnimationPlayer = $TransitionAnimPlayer
@onready var interaction_timer: Timer = $InteractionTimer
@onready var finger: TextureRect = $Camera3D/CanvasLayer/Finger
@onready var finger_anim: AnimationPlayer = $Camera3D/CanvasLayer/FingerAnim
@onready var hint_timer: Timer = $HintTimer
@onready var debugonscreen: Label = $Camera3D/CanvasDebug/ButtonDebug/LabelDebug
@onready var canvas_postprocess: CanvasLayer = $Camera3D/CanvasPost
@onready var postprocess_pixelate: ColorRect = $Camera3D/CanvasPost/Pixelate
@onready var postprocess_smear: ColorRect = $Camera3D/CanvasPost/Smear
@onready var label_title: Label = $Camera3D/CanvasLayer/LabelTitle
@onready var title_anim: AnimationPlayer = $Camera3D/CanvasLayer/TitleAnim

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

@export var zoom_min := 1.25
@export var zoom_max := 20.0

@export_group("Defaults")
@export var default_env:Environment = preload("res://config/default_env.tres")
@export var reset_env:Environment = preload("res://config/reset_env.tres")
@export var current_scene:Node

@export var current_sphere: MeshInstance3D
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

var random := RandomNumberGenerator.new()

@export_group("Technically necessary")
@export var camera_animation_position: = 0.0
@export var camera_interpolation = true

# Called when the node enters the scene tree for the first time.
func _ready():
	#label_title.hide()
	#debugonscreen.hide()
	canvas_postprocess.show()
	camera_interpolation = true
	randomize()
	camera.position.z = desired_zoom
	
	# get sphere reference
	#current_sphere = current_scene.get_node_or_null("scene_sphere")
	
	# set animation speed
	transition_anim_player.speed_scale = 1.0/transition_duration
	transition_timer.wait_time = transition_duration
	hint_timer.wait_time = hint_frequency + finger_anim.get_animation('finger_swipe').length
	
	Global.yell()
	
	# init
	interaction_timer.start()
	
	# Load new scene
	#load_scene(scene_int)
	get_tree().get_root().size_changed.connect(resize)
	# Demo video resolution
	#get_viewport().size = Vector2(720,960)
	#get_window().position = Vector2(0,0)
  

func resize():
	var viewport_size = get_viewport().size
	var mat_pixelate: ShaderMaterial = postprocess_pixelate.material
	mat_pixelate.set_shader_parameter("res",viewport_size/1.5)
	#print('SHADER ',mat_pixelate.get_shader_parameter("res"))
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
		any_interaction()
		if(not pinching):
			pinchStartDist = 0.0
		usingTouch = true
		pass
	
	if event is InputEventScreenPinch and usingTouch:
		any_interaction()
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
		any_interaction()
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
	
	# --------------- <- SCENE CONTROL -> reset
	if event.is_action_pressed('next'):
		print('space')
		scene_int+=1
		load_scene(scene_int)
	if event.is_action_pressed('prev'):
		print('space')
		scene_int-=1
		load_scene(scene_int)
	if event.is_action_pressed('reset'):
		interaction_timer.wait_time = wait_until_reset_duration
		reset_view()
		hint_timer.start()
	
	# FULLSCREEN
	if event.is_action_pressed('fullscreen'):
		print('enter')
		if(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# Quit
	if event.is_action_pressed('quit'):
		print('esc')
		get_tree().quit()
	
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
			any_interaction()
			usingTouch = true
			mouse_now = event.position
			mouse_change = mouse_start - mouse_now
			mouse_start = mouse_now
			dragging = true
		pass

func any_interaction():
	label_title.hide()
	interaction_timer.start()
	hint_timer.stop()
	
func _process( delta ):
	if(debugonscreen.visible):
		debugonscreen.text = (
			'\n\nfullscreen toggle (ENTER)'
			+'\nclose (ESC)'
			+'\nnext/prev (ARROW KEYS)'
			+'\nreset (SPACE)'
			+'\n\nfps: '	+str(Engine.get_frames_per_second())
			+'\nmouse: '	+str(get_viewport().get_mouse_position())
			+'\nviewport: '	+str(get_viewport().size)
			+'\nreset: '+str(int(interaction_timer.time_left))+'s'
			+'\nhint: '	+str(int(hint_timer.time_left))+'s'
			)
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
		# Introduce Glitches
		#if(random.randi_range(0,25) == 0):
			#get_viewport().size = get_viewport().size - Vector2i(1,1)
			#get_viewport().scaling_3d_scale = 0.9 + random.randf()*0.2
		#print('mouse drag')
	
	#print('----- ',camera_interpolation)
	if(camera_interpolation):
		move_and_rotate()
	else:
		transition_camera()

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
	print('------ CALLED START SCENE TRANSITION')
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
	if(current_scene != null):
		current_scene.free()
	elif(current_sphere != null):
		current_sphere.free()
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
		# ------------- get next -----------------
		# texture of following scene's model material
		# (get last, cuz first model tends to be room itself with "empty" material, without objects)
		var load_scene_mat: StandardMaterial3D = load_scene_mdl.get_surface_override_material(load_scene_mdl.get_surface_override_material_count()-1)
		var next_image = load_scene_mat.emission_texture
		# ------------- get next -----------------
		
		# ------------- get current -----------------
		var current_mdl = current_scene.get_node_or_null("scene_model")
		var current_mat: StandardMaterial3D = current_mdl.get_surface_override_material(current_mdl.get_surface_override_material_count()-1)
		var current_image = current_mat.emission_texture
		print('------- new: ', next_image.resource_path)
		print('--- current: ', current_image.resource_path)
		# ------------- get current -----------------
		
		# applied to current sphere
		current_sphere = current_scene.get_node_or_null("scene_sphere")
		# get the LAST material
		var current_sphere_mat: Material = current_sphere.get_surface_override_material(0)
		var current_sphere_scale: float = current_sphere.scale.x
		current_sphere_mat.set_shader_parameter("image",next_image)
		# default scale is optimized for 0.4, if sphere smaller, needs to apply smaller shader scale
		current_sphere_mat.set_shader_parameter("scale",current_sphere_scale/0.4)
		
		var image_aspect_ratio:float 	= float(current_image.get_width()) / float(current_image.get_height())
		var viewport_aspect_ratio:float = float(get_viewport().size.x) / float(get_viewport().size.y)
		#print('image: ',image_aspect_ratio)
		#print('viewp: ',viewport_aspect_ratio)
		# Calculate new FOV based on width fitting
		if(image_aspect_ratio > viewport_aspect_ratio):
			var original_half_fov = deg_to_rad(camera.fov) / 2.0
			var adjusted_half_fov = atan(tan(original_half_fov) * image_aspect_ratio / viewport_aspect_ratio)
			camera.fov = rad_to_deg(adjusted_half_fov * 2.0)
		
		var title_height = label_title.get_minimum_size().x
		var window_size = get_tree().root.content_scale_size
		var viewport_size = get_viewport().size
		label_title.label_settings.font_size = 64.0 * float(viewport_size.x)/float(window_size.x)
		
		var full_size_y = (
			float(viewport_size.y)		# big screen: viewport (res)
			if viewport_size.y > window_size.y or viewport_aspect_ratio > image_aspect_ratio
			else float(window_size.y))	# small screen: ui window (720)
		
		# CENTER TEXT IN BLACK BAR ON TOP
		var title_y_relative = (
			(float(viewport_size.y)							# full.y
			- (float(viewport_size.x) / image_aspect_ratio))	# - img.h
			*0.25											# 25% = center upper black bar
			/float(viewport_size.y))							# %
		
		label_title.position.y = maxf(
			full_size_y * title_y_relative					# apply %
			- label_title.label_settings.font_size/2.0		# correct for text height
		, label_title.label_settings.font_size/2.0)			# don't go outside screen
		
		var finger_y_relative = (
			(float(viewport_size.y)							# full y
			- float(viewport_size.x) / image_aspect_ratio)	# - img.y
			*0.75											# 75% = center of bottom bar
			+ (float(viewport_size.x) / image_aspect_ratio)	# + img.y
			)/float(viewport_size.y)							# %
		
		
		print("up" if viewport_size.y > window_size.y else "down")
		finger.position.y = minf(
			(full_size_y * finger_y_relative					# relative position
			- finger.size.y * finger.scale.y / 2.0)			# - finger height
			,viewport_size.y - finger.size.y * finger.scale.y) # don't go over viewport
			
		#print('-- WINDOW ',window_size)
		#print('-- VIEWPORT ',viewport_size)
		#print('-- IMG aspect ', image_aspect_ratio)
		#print('-- IMG H:' , float(viewport_size.x) / image_aspect_ratio)
		#print('-- TITLE ', label_title.position.y)
		#print('-- PERCT ',finger_y_relative)
			# TEMPORARY: manual correction
	
	# set defaults
	transition_default_pos = camera.global_position
	transition_default_rot = camera.global_transform.basis.get_rotation_quaternion().normalized()
	
	hint_timer.start()
	

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
	interaction_timer.wait_time = wait_until_reset_duration
	reset_view()
	hint_timer.start()
	pass

## Plays animation to reset camera view
func reset_view(instant:bool = false):
	# ROTATION
	# current
	transition_start_pos = camera.global_position
	transition_start_rot = camera.global_transform.basis.get_rotation_quaternion().normalized()
	
	# default (peak in scene)
	transition_end_rot = transition_default_rot
	transition_end_pos = transition_default_pos
	
	# apply camera transforms
	transition_timer.start()
	interaction_timer.stop()
	if(instant):
		transition_anim_player.play('zoom_to_start',-1,0.1)
	else:
		transition_anim_player.play('zoom_to_start')

## HINT TIMER:
## play the finger animation
func _on_hint_timer_timeout() -> void:
	if(not title_anim.is_playing() and not label_title.visible):
		label_title.show()
		label_title.label_settings.font_color = [Color(1,0,0),Color(0,1,0),Color(0,1,1),Color(1,1,0),Color(1,0,1)].pick_random()
		title_anim.play('type_title',-1,0.25,false)
	elif(not label_title.visible):
		label_title.show()
		title_anim.play('type_title',-1,0.25,false)
	finger_anim.stop()
	finger_anim.play('finger_swipe')
	pass # Replace with function body.

func _on_init_timer_timeout() -> void:
	load_scene(scene_int)
	pass # Replace with function body.

# ON DOUBLE CLICK, HIDE DEBUG
@onready var debug_button_timer: Timer = $Camera3D/CanvasDebug/ButtonDebug/Timer
var debug_button_amount := 0
@onready var button_graphics: Button = $Camera3D/CanvasDebug/ButtonGraphics
@onready var button_graphics_label: Label = $Camera3D/CanvasDebug/ButtonGraphics/LabelGraphics

func _on_button_pressed() -> void:
	if(debug_button_timer.is_stopped()):
		debug_button_amount = 0
		debug_button_timer.start()
	if debugonscreen.visible:
		debugonscreen.hide()
		button_graphics.hide()
	else:
		debug_button_amount+=1
	# only show if double clicked
	if(debug_button_amount == 2):
		debug_button_timer.stop()
		debugonscreen.show()
		button_graphics.show()
	#debugonscreen.get_child(0).queue_free()
	#reset_view()
	#hint_timer.start()
	
	
	pass # Replace with function body.

enum graphic_settings {
	HIGH_NONE,
	HIGH_SMEAR,
	HIGH_PIXELATE,
	HIGH_BOTH,
	MID,
	LOW
}
var current_graphic_settings: int = graphic_settings.HIGH_BOTH as graphic_settings
func _on_button_graphics_pressed() -> void:
	current_graphic_settings = (current_graphic_settings + 1)  % graphic_settings.size() 
	button_graphics_label.text = 'Graphics: ' + str(graphic_settings.find_key(current_graphic_settings))
	if(current_graphic_settings == graphic_settings.LOW):
		get_tree().root.scaling_3d_scale = 0.25
		postprocess_pixelate.hide()
		postprocess_smear.hide()
	elif(current_graphic_settings == graphic_settings.MID):
		get_tree().root.scaling_3d_scale = 0.5
		postprocess_pixelate.hide()
		postprocess_smear.show()
	elif(current_graphic_settings == graphic_settings.HIGH_BOTH):
		get_tree().root.scaling_3d_scale = 1.0
		postprocess_pixelate.show()
		postprocess_smear.show()
	elif(current_graphic_settings == graphic_settings.HIGH_PIXELATE):
		get_tree().root.scaling_3d_scale = 1.0
		postprocess_pixelate.show()
		postprocess_smear.hide()
	elif(current_graphic_settings == graphic_settings.HIGH_SMEAR):
		get_tree().root.scaling_3d_scale = 1.0
		postprocess_pixelate.hide()
		postprocess_smear.show()
	elif(current_graphic_settings == graphic_settings.HIGH_NONE):
		get_tree().root.scaling_3d_scale = 1.0
		postprocess_pixelate.hide()
		postprocess_smear.hide()
	camera.environment = reset_env
	pass # Replace with function body.

@onready var icon_setting: TextureRect = $Camera3D/CanvasDebug/ButtonDebug/Center/IconSetting

func _on_button_debug_mouse_entered() -> void:
	icon_setting.modulate = Color(1,1,1,1)
	pass # Replace with function body.


func _on_button_debug_mouse_exited() -> void:
	icon_setting.modulate = Color(1,1,1,0.0625)
	pass # Replace with function body.


func _on_button_glitch_pressed() -> void:
	if(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
		# Set the new resolution
		get_tree().root.content_scale_size = DisplayServer.screen_get_size() - Vector2i(1,1)

		# Update the viewport to fill the entire display
		get_viewport().set_size(DisplayServer.screen_get_size())
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		
		# Reset
		get_tree().root.content_scale_size = DisplayServer.screen_get_size()
	pass # Replace with function body.
