// https://godotshaders.com/shader/how-to-get-vertical-camera-fov/

shader_type spatial;
render_mode unshaded;

uniform float compare_FOV = 70;

void fragment() {

	float FOV_in_radians = atan(-1.0 / PROJECTION_MATRIX[1][1]) * 2.0;
	float FOV_in_degrees = degrees(FOV_in_radians);

	if(FOV_in_degrees > compare_FOV - 0.1 && FOV_in_degrees < compare_FOV + 0.1)
	{
		ALBEDO = vec3(1.0,1.0,1.0);
	}
	else
	{
		ALBEDO = vec3(0.0,0.0,0.0);
	}

}