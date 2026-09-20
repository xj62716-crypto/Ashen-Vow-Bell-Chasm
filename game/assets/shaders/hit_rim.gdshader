shader_type spatial;
render_mode unshaded,blend_add,depth_draw_never,shadows_disabled;
uniform float strength=0.7;
void fragment(){
	float rim=pow(1.0-max(0.0,dot(normalize(NORMAL),normalize(VIEW))),2.0);
	ALBEDO=vec3(1.0,.67,.32);
	ALPHA=(rim*.65+.06)*strength;
}
