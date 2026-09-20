shader_type sky;
uniform vec3 zenith : source_color = vec3(0.025,0.055,0.082);
uniform vec3 horizon : source_color = vec3(0.19,0.25,0.26);
float noise(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	vec4 n=sin(vec4(dot(i,vec2(127.1,311.7)),dot(i+vec2(1,0),vec2(127.1,311.7)),dot(i+vec2(0,1),vec2(127.1,311.7)),dot(i+vec2(1),vec2(127.1,311.7))))*43758.5453;
	return mix(mix(fract(n.x),fract(n.y),f.x),mix(fract(n.z),fract(n.w),f.x),f.y);
}
void sky() {
	float h=clamp(EYEDIR.y,0.0,1.0);
	vec2 p=EYEDIR.xz/(max(0.15,h)+0.15)*1.6;
	float clouds=noise(p)*0.55+noise(p*2.8)*0.28+noise(p*7.5)*0.17;
	vec3 color=mix(horizon,zenith,pow(h,0.45));
	color*=mix(0.50,1.06,smoothstep(0.2,0.85,clouds));
	float moon=dot(EYEDIR,normalize(vec3(-0.4,0.45,-0.8)));
	color+=vec3(0.45,0.53,0.50)*smoothstep(0.9991,0.9995,moon);
	color+=vec3(0.055,0.065,0.06)*pow(max(0.0,moon),140.0);
	COLOR=mix(vec3(0.018,0.031,0.039),color,smoothstep(-0.3,0.05,EYEDIR.y));
}
