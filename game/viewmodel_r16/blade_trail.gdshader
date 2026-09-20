shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,blend_mix;
uniform vec4 tint:source_color=vec4(.18,.12,.21,1);
uniform vec4 core_color:source_color=vec4(.86,.91,.92,1);
uniform float age=0.;
uniform float strength=1.;
uniform float brightness=.85;
uniform float bloom=.25;
uniform float breakup=.4;
uniform int style=0;
uniform float contact=0.;
uniform float ghost=0.;
uniform float empowered=0.;
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 float edge=pow(max(0.,sin(UV.y*3.14159265)),.65);
 float life=pow(UV.x,1.5);
 float core=exp(-pow((UV.x-.92)*12.,2.))*smoothstep(.02,.25,UV.y);
 float wisps=.55+.45*sin(UV.y*37.+sin(UV.x*17.-age*2.)*2.);
 float erode=mix(1.,smoothstep(.12,.60,wisps+UV.x*.4),breakup*(1.-UV.x));
 float fleck=step(.89,hash21(floor(vec2(UV.x*61.,UV.y*19.))))*(1.-UV.x)*edge;
 vec3 pigment=mix(tint.rgb,vec3(.075,.026,.10),UV.y*.6);
 ALBEDO=mix(pigment,core_color.rgb,core*.93);
 EMISSION=(pigment*(3.4+empowered*1.6)+core_color.rgb*core*(2.7+empowered*2.3))*brightness*(1.+bloom);
 ALPHA=edge*life*erode*strength*(.65+core*.35)*(1.-ghost*.65);
 ALPHA*=1.-fleck*.55;
}
