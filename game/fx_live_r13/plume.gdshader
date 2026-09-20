shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0,.24,.025,1);
uniform vec4 core : source_color = vec4(1.0,.82,.38,1);
uniform float age=0.0;
uniform float strength=1.0;
uniform float seed=0.0;
uniform int style=0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.54);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
float fbm(vec2 p){float v=0.0,a=.55;for(int i=0;i<4;i++){v+=noise(p)*a;p=p*2.03+vec2(13.1,7.3);a*=.5;}return v;}
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);}
void fragment(){
    vec2 p=UV*2.0-1.0;
    vec2 flow=vec2(p.x*2.7+seed,p.y*2.0+age*3.6);
    float n=fbm(flow+fbm(flow*.67)*2.5);
    float taper=mix(.17,.92,UV.y);
    float body=1.0-length(vec2(p.x/taper,(p.y+.10)*.83));
    float flame=smoothstep(.0,.42,body-n*.64);
    float wisps=smoothstep(.15,.6,body)*smoothstep(.38,.72,n);
    float alpha=flame*.7+wisps*.35;
    if(style==1){alpha=smoothstep(.0,.8,1.0-length(p))*n*.45;}
    if(style==2){alpha=exp(-abs(length(p)-.58-n*.13)*24.0)*.38;}
    ALBEDO=mix(tint.rgb,core.rgb,pow(flame,2.6));
    EMISSION=ALBEDO*.45;
    ALPHA=alpha*strength;
}
