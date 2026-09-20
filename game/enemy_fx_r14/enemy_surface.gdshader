shader_type spatial;
render_mode blend_mix,depth_draw_never;
uniform float frost=0.;
uniform float flash=0.;
uniform vec4 tint:source_color=vec4(.73,.57,.30,1);
void fragment(){
 float rim=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),2.8);
 float grain=fract(sin(dot(VERTEX.xz+VERTEX.yy,vec2(127.1,311.7)))*43758.5453);
 ALBEDO=mix(tint.rgb,vec3(.51,.69,.72),frost);
 ROUGHNESS=.35;EMISSION=ALBEDO*flash*.6;
 ALPHA=clamp(frost*(rim*.36+step(.84,grain)*.07)+flash*rim*.4,0.,.55);
}
