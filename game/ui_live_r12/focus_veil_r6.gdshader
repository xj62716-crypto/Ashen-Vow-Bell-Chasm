shader_type canvas_item;
render_mode unshaded;
uniform float strength=0.0;
uniform float phase_age=0.0;
void fragment(){
 vec2 p=UV*2.0-1.0;
 float edge=smoothstep(.52,1.08,max(abs(p.x),abs(p.y)));
 float pulse=.94+.06*sin(phase_age*2.4);
 vec3 tint=mix(vec3(.055,.07,.075),vec3(.13,.19,.20),edge);
 COLOR=vec4(tint,edge*.22*strength*pulse);
}
