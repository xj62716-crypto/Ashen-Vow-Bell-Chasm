shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 mineral : source_color = vec4(.13,.23,.25,1.0);
uniform float clock_seconds = 0.0;
uniform float readiness = 0.0;
uniform float release_strength = 0.0;
uniform float effect_weight = 1.0;
varying vec3 mineral_position;
float grain(vec3 p) {return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
void vertex(){mineral_position=VERTEX;}
void fragment(){
    vec3 p=mineral_position*120.0;
    float stratum=.5+.5*sin(p.x*1.5+p.y*2.2+sin(p.z*1.7)*.8);
    float seam=pow(stratum,22.0);
    float cloud=.5+.5*sin(p.x*.67+sin(p.z*2.1)+cos(p.y*1.6));
    ALBEDO=mix(mineral.rgb*.18,mineral.rgb*.65,cloud)*(.8+.2*stratum);
    METALLIC=.23;ROUGHNESS=.18+cloud*.14;CLEARCOAT=.65;CLEARCOAT_ROUGHNESS=.15;
    EMISSION=mineral.rgb*effect_weight*seam*(.08+readiness*.5+release_strength*.9)*(.6+.4*sin(clock_seconds*3.0+p.x*.3));
}
