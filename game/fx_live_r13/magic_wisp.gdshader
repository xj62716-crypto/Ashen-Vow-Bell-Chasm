shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color=vec4(.9,.4,.12,1);
uniform float emission_scale=1.0;
uniform float age=0.0;
uniform float strength=1.0;
uniform float seed=0.0;
uniform int style=0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
float fbm(vec2 p){float n=0.0,a=.5;for(int i=0;i<4;i++){n+=noise(p)*a;p=p*2.02+vec2(13,7);a*=.5;}return n;}
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);}
void fragment(){
 vec2 p=UV*2.0-1.0;
 vec2 flow=vec2(p.x*3.2+seed,p.y*2.4+age*3.8);
 float n=fbm(flow+fbm(flow*.65)*2.0);
 float envelope=1.0-smoothstep(.25,1.0,length(vec2(p.x,p.y*.87)));
 float flame=envelope*smoothstep(.28,.69,n+envelope*.22);
 float alpha=flame;
 vec3 color=mix(tint.rgb*.45,tint.rgb,smoothstep(.2,.7,n));
 if(style==0){
  float heat=smoothstep(.66,.90,flame);
  color=mix(color,vec3(1.0,.69,.22),heat);
  alpha*=1.0-smoothstep(.70,1.0,abs(p.y));
 }
 if(style==1){alpha=exp(-abs(p.x-p.y*.28)*20.0)*(1.0-smoothstep(.15,1.0,abs(p.y)))*(.2+.8*n);color=tint.rgb;}
 if(style==2){
  float angle=atan(p.y,p.x);
  float band=abs(length(p)-(.48+.10*sin(angle*2.0-age*3.0+seed)));
  alpha=exp(-band*45.0)*smoothstep(.20,.72,n)*(0.45+0.55*sin(angle+seed)*sin(angle+seed));
  color=tint.rgb*.8;
 }
 if(style==4){alpha=exp(-dot(p,p)*7.0)*(0.5+0.5*n);color=mix(tint.rgb,vec3(1.0,.86,.58),.5);}
 ALBEDO=color;
 EMISSION=(color*(style==4 ? 2.0 : 1.15))*emission_scale;
 ALPHA=clamp(alpha*strength,0.0,1.0)*.82;
}
