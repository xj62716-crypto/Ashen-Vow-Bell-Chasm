shader_type spatial;
render_mode blend_mix,depth_draw_never;
void fragment(){
	float rim=pow(1.0-max(0.0,dot(normalize(NORMAL),normalize(VIEW))),1.5);
	float grain=fract(sin(dot(VERTEX.xy,vec2(127.1,311.7)))*43758.5);
	ALBEDO=vec3(.28,.68,.86)+grain*.13;
	ROUGHNESS=.3;
	METALLIC=.2;
	EMISSION=vec3(.10,.27,.40)*rim;
	ALPHA=.22+rim*.5;
}
