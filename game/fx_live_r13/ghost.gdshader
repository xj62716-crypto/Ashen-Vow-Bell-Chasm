shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color=vec4(.48,.40,.63,1);
uniform float strength=1.0;
uniform float age=0.0;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.54);}
float smoke(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void fragment(){
 float fresnel=pow(1.0-max(0.0,dot(normalize(NORMAL),normalize(VIEW))),2.0);
 float mist=smoke(world_position*7.+vec3(0,age*.6,0))*.7+smoke(world_position*15.)*.3;
 float dissolve=smoothstep(age*.24-.12,age*.24+.18,mist);
 float distance_fade=smoothstep(.75,2.15,length(VERTEX));
 ALBEDO=tint.rgb*(.36+fresnel*.5);EMISSION=tint.rgb*(.12+fresnel*.24);
 ALPHA=(.085+fresnel*.24)*dissolve*strength*distance_fade;
}
