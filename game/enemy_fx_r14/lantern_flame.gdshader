shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float world_age=0.0;
uniform float layer_phase=0.0;
uniform float energy=1.0;
uniform vec3 bend_axis=vec3(1.0,0.0,0.0);

float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
    vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex(){
    float t=UV.y;
    float flutter=sin(world_age*6.3+t*7.0+layer_phase)+0.35*sin(world_age*13.0+t*18.0+layer_phase);
    VERTEX+=bend_axis*flutter*t*t*0.010;
    VERTEX+=NORMAL*sin(world_age*9.0+UV.x*18.8496+t*13.0+layer_phase)*0.002*t;
}
void fragment(){
    float t=UV.y;
    vec2 uv=vec2(UV.x*7.0,t*4.5-world_age*1.9+layer_phase);
    float n=noise(uv)*0.65+noise(uv*2.3)*0.35;
    float edge=1.0-smoothstep(0.65+n*0.30,1.0,t);
    float base=smoothstep(0.0,0.13,t);
    float heat=clamp((1.0-t)*0.9+n*0.5,0.0,1.0);
    vec3 ember=vec3(0.76,0.065,0.004);
    vec3 hot=vec3(1.0,0.65,0.16);
    vec3 color=mix(ember,hot,pow(heat,2.0));
    ALBEDO=color;
    EMISSION=color*(0.8+heat*1.4)*energy;
    ALPHA=base*edge*mix(0.30,0.78,n)*min(energy,1.0);
}
