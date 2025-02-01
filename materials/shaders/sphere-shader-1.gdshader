shader_type spatial;
render_mode unshaded;

uniform sampler2D image : source_color;
uniform vec2 format;

uniform float distance_start = 0.5;
uniform float distance_end = 2.0;
varying vec2 texture_size;

varying vec4 NODE_POSITION_CLIP;

void vertex() {
	NODE_POSITION_CLIP = (PROJECTION_MATRIX * vec4(NODE_POSITION_VIEW, 1.0));
	texture_size = vec2(textureSize(image,0));
}

void fragment() {
	/* UV fear: -------------------------
	Purpose: Center and fit image within mesh
	Adapted: https://godotshaders.com/shader/local-screen-space-uv/
	   UV fear: ------------------------- */
	vec2 local_uv_far;
	// screenspace mit wie groß objekt scaling
	local_uv_far = (SCREEN_UV * 2.0 - 1.0) * NODE_POSITION_CLIP.w - NODE_POSITION_CLIP.xy;
	// Adjust for aspect ratio and FOV
	local_uv_far.x *= VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	// correct for aspect ratio
	local_uv_far.x *= texture_size.y / texture_size.x;
	// larger to fit into object ?
	local_uv_far *= -1.0 / PROJECTION_MATRIX[1][1];

	/* UV near: -------------------------
	Purpose: Fit image into center of Viewport
	Adapted from: https://godotshaders.com/shader/screenspace-tiled-texturing/
	   UV near: ------------------------- */
	vec2 local_uv_near;
	local_uv_near = SCREEN_UV - 0.5; // fit exactly
	local_uv_near.y *= texture_size.x / texture_size.y; // fits image to viewport width
	local_uv_near.y *= VIEWPORT_SIZE.y / VIEWPORT_SIZE.x; // corrects aspect ratio for height
	
	/* OLD: clip space vertex depth
	 -------------------------
	float transition_speed = 4.0;
	float transition = NODE_POSITION_CLIP.w * transition_speed - transition_speed;
	float transition_clamped = transition > 1.0 ? 1.0 : (transition < 0.0 ? 0.0 : transition);
	vec2 local_uv = mix(local_uv_near,local_uv_far,transition_clamped);
	 -------------------------*/
	
	/* New: camera position depth
	 ------------------------- */
	vec3 vertexWorldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_camera = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float distanceToCamera = distance(world_camera, vertexWorldPos);
	
	float smoothDistance = 1.0 - smoothstep(distance_start, distance_end, distanceToCamera);
	
	// SMOOTHLY INTERPOLATE THE TWO SHADERS
	vec2 local_uv = mix(local_uv_far, local_uv_near,smoothDistance);
	
	// Crop the Image via brightness (instead of repeating)
	float brightness =
		local_uv.x > -0.49 &&  local_uv.x < 0.49
		&& local_uv.y > -0.49 && local_uv.y < 0.49 ? 1.0 : 0.0;
	
	ALBEDO = texture(image, local_uv + 0.5).rgb * brightness;
}