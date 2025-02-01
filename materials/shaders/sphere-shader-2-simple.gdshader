shader_type spatial;
render_mode unshaded;
// Renders a tileable 2D texture to screen, using spatial polygons as a mask.
// Remove blur from textures by unchecking "Detect 3D" and "Filter" in Import.
// Demo: https://github.com/DeerTears/Polygon-Mask-for-2D-Textures/

// uniform sampler2D tiling_texture;
uniform sampler2D tiling_texture : source_color;
uniform float tiling_scale = 1.0;

void fragment() {
	vec2 texture_size = vec2(textureSize(tiling_texture,0));
    vec2 uv = FRAGCOORD.xy;
    //vec2 tiling_uv = uv / tiling_scale;
	vec2 tiling_uv = vec2(uv.x / texture_size.x, uv.y / texture_size.y);
	// fit to y 
	tiling_uv = vec2(tiling_uv.x, tiling_uv.y * texture_size.y / VIEWPORT_SIZE.y);
    vec4 texture_result = texture(tiling_texture, tiling_uv);
    ALBEDO = texture_result.rgb;
    ALPHA = texture_result.a;
}