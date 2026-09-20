shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform float strength=1.0;
uniform float age=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.54);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1.,0.)),f.x),mix(hash(i+vec2(0.,1.)),hash(i+vec2(1.,1.)),f.x),f.y);}
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);}
void fragment(){
    vec2 p=(UV-vec2(.22,.5))*vec2(1.7,2.5);
    float fan=smoothstep(.06,.25,UV.x)*(1.-smoothstep(.64,1.,UV.x));
    fan*=1.-smoothstep(.03,.5,abs(p.y)/(p.x+.3));
    vec2 flow=UV*vec2(14.,22.)+age*vec2(-3.,.8);
    float fog=noise(flow)*.65+noise(flow*2.13)*.23+noise(flow*4.31)*.12;
    ALBEDO=mix(vec3(.055,.006,.01),vec3(.28,.023,.035),fog);
    ALPHA=fan*smoothstep(.30,.68,fog)*strength*.7;
}
