shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void fragment(){
	vec2 p=world.xz*.6+vec2(TIME*.035,TIME*.017);
	float n=noise(p+noise(p*1.8)*1.7);
	float cracks=1.0-smoothstep(.025,.12,abs(n-.5));
	float flecks=pow(noise(p*10.0),12.0);
	ALBEDO=mix(vec3(.025,.013,.012),vec3(.16,.022,.005),cracks);
	EMISSION=vec3(1.0,.16,.012)*(cracks*.9+flecks*1.4);
	ROUGHNESS=.72;
}
