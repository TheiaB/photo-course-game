shader_type spatial;
render_mode unshaded;

uniform sampler2D image : source_color;

uniform float scale = 1.0;

uniform float distance_start = 0.5;
uniform float distance_end = 2.0;
varying vec2 texture_size;

varying vec4 NODE_POSITION_CLIP;

void vertex() {
	NODE_POSITION_CLIP = (PROJECTION_MATRIX * vec4(NODE_POSITION_VIEW, 1.0));
	texture_size = vec2(textureSize(image,0));
}

float fresnel(float amount, vec3 normal, vec3 view) {
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0 )), amount);
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
	local_uv_far /= scale;
	

	/* UV near: -------------------------
	Purpose: Fit image into center of Viewport
	Adapted from: https://godotshaders.com/shader/screenspace-tiled-texturing/
	   UV near: ------------------------- */
	// fit exactly
	vec2 local_uv_near = SCREEN_UV - 0.5;
	
	float image_aspect_ratio = texture_size.x / texture_size.y;
	float viewport_aspect_ratio = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;

	if (image_aspect_ratio > viewport_aspect_ratio) {
	    // Image is wider than viewport, fit to width
		local_uv_near.y *= texture_size.x / texture_size.y; // fits image to viewport width
		local_uv_near.y *= VIEWPORT_SIZE.y / VIEWPORT_SIZE.x; // corrects aspect ratio for height
	} else {
	    // Image is taller than viewport, fit to height
		local_uv_near.x *= texture_size.y / texture_size.x; // fits image to viewport height
		local_uv_near.x *= VIEWPORT_SIZE.x / VIEWPORT_SIZE.y; // corrects aspect ratio for width
	}
	
	
	/* OLD: clip space vertex depth
	 -------------------------
	float transition_speed = 4.0;
	float transition = NODE_POSITION_CLIP.w * transition_speed - transition_speed;
	float transition_clamped = transition > 1.0 ? 1.0 : (transition < 0.0 ? 0.0 : transition);
	vec2 local_uv = mix(local_uv_near,local_uv_far,transition_clamped);
	 -------------------------*/
	
	/* New: TRANSITION VIA CAMERA (POS) DEPTH
	 ------------------------- */
	vec3 vertexWorldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_camera = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float distanceToCamera = distance(world_camera, vertexWorldPos);
	float smoothDistance = 1.0 - smoothstep(distance_start, distance_end, distanceToCamera);
	
	// SMOOTHLY INTERPOLATE THE TWO SHADERS
	vec2 local_uv = mix(local_uv_far, local_uv_near,smoothDistance);
	
	// Crop the Image via brightness (instead of repeating)
	float threshold = 0.49;
	float brightness =
		local_uv.x > -threshold &&  local_uv.x < threshold
		&& local_uv.y > -threshold && local_uv.y < threshold ? 1.0 : 0.0;
	
	
	// FRESNEL
	
	vec3 base_color = vec3(0.0);
	float basic_fresnel = pow(1.0 - fresnel(1.5, NORMAL, VIEW),1.5) * 0.6 + 0.4;
	// ALBEDO = base_color + basic_fresnel;
	
	ALBEDO = texture(image, local_uv + 0.5).rgb * brightness * basic_fresnel;
	//ALPHA = clamp(basic_fresnel*2.0,0.0,1.0);
	// DEBUG: Yellow is far, blue is near
	// ALBEDO = texture(image, local_uv + 0.5).rgb * brightness + vec3(0.0,0.0,smoothDistance-0.5);
}