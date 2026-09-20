shader_type spatial;
render_mode blend_mix,cull_disabled,depth_draw_never,shadows_disabled;
uniform vec4 tint : source_color=vec4(.10,.07,.06,1.0);
uniform float emission_scale=1.0;
uniform float age=0.0;
uniform float strength=1.0;
uniform float seed=0.0;
uniform int style=3;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
float fbm(vec2 p){float n=0.0,a=.5;for(int i=0;i<4;i++){n+=noise(p)*a;p=p*2.02+vec2(13,7);a*=.5;}return n;}
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);}
void fragment(){
 vec2 p=UV*2.0-1.0;
 float n=fbm(p*3.0+vec2(seed,age*.65));
 float edge=1.0-smoothstep(.20,.95,length(p)+n*.20);
 ALBEDO=tint.rgb*(.55+n*.7);
 ROUGHNESS=1.0;
 ALPHA=edge*smoothstep(.18,.70,n)*strength*.40;
}
