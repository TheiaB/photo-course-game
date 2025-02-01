shader_type spatial;
render_mode unshaded;

uniform sampler2D image : source_color;
uniform vec2 format;
uniform vec2 tiling = vec2(1.0);
uniform vec2 offset = vec2(0.0);

varying vec4 NODE_POSITION_CLIP;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

void vertex() {
	 NODE_POSITION_CLIP = (PROJECTION_MATRIX * vec4(NODE_POSITION_VIEW, 1.0));
}

void fragment() {
	vec2 texture_size = vec2(textureSize(image,0));
	vec2 local_uv_far;
	// screenspace mit wie groß objekt scaling
	local_uv_far = (SCREEN_UV * 2.0 - 1.0) * NODE_POSITION_CLIP.w - NODE_POSITION_CLIP.xy;
	// Adjust for aspect ratio and FOV
	local_uv_far.x *= VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	local_uv_far.x *= format.y / format.x; // correct for aspect ratio
	local_uv_far *= -1.0 / PROJECTION_MATRIX[1][1];

	vec2 local_uv_near;
	local_uv_near = SCREEN_UV - 0.5; // fit exactly
	local_uv_near.y *= format.x / format.y; // correct for aspect ratio
	local_uv_near.y *= VIEWPORT_SIZE.y / VIEWPORT_SIZE.x;
	
	float transition_speed = 4.0;
	float transition = NODE_POSITION_CLIP.w * transition_speed - transition_speed;
	float transition_clamped = transition > 1.0 ? 1.0 : (transition < 0.0 ? 0.0 : transition);
	vec2 local_uv = mix(local_uv_near,local_uv_far,transition_clamped);
	
	
	
	float brightness =
		local_uv.x > -0.49 &&  local_uv.x < 0.49
		&& local_uv.y > -0.49 && local_uv.y < 0.49 ? 1.0 : 0.0;
	//brightness = 1.0;
	ALBEDO = texture(image, local_uv * tiling + 0.5 + offset).rgb * brightness;
}