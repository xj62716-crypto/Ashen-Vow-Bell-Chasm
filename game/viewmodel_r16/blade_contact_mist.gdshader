shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float progress=0.;
uniform float opacity=.52;
uniform vec4 pigment:source_color=vec4(.34,.075,.055,1.);
float grain(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 a=floor(p),b=fract(p);b=b*b*(3.-2.*b);return mix(mix(grain(a),grain(a+vec2(1,0)),b.x),mix(grain(a+vec2(0,1)),grain(a+vec2(1,1)),b.x),b.y);}
void fragment(){
 vec2 p=UV*2.-1.;
 float edge=1.-smoothstep(.2,1.,length(vec2(p.x*.72,p.y)));
 float cloud=noise(p*4.+vec2(progress*2.4,progress*.85))*.7+noise(p*10.-progress)*.3;
 float dissolve=smoothstep(progress*.65,.85,cloud);
 ALBEDO=pigment.rgb;
 EMISSION=pigment.rgb*(.42+cloud*.34);
 ALPHA=edge*dissolve*(1.-progress)*opacity;
}
