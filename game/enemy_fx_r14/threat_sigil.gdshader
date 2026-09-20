shader_type spatial;
render_mode unshaded,blend_mix,cull_disabled,depth_draw_never,shadows_disabled;
uniform vec4 tint:source_color=vec4(.75,.32,.15,1);
uniform float progress=0.0;
uniform float strength=1.0;
uniform float age=0.0;
uniform bool square=false;
uniform bool front_only=false;
float line(float x,float w){return 1.-smoothstep(w,w+.005,abs(x));}
void fragment(){
 vec2 p=(UV-.5)*2.;float r=square?max(abs(p.x),abs(p.y)):length(p);float a=atan(p.y,p.x);
 float edge=line(r-.975,.013);
 float glyph=line(r-.865,.006)*step(.22,abs(sin(a*8.)));
 float sector=mod(a+3.14159,.5235988)-.2617994;vec2 q=vec2(cos(sector),sin(sector))*r;
 glyph+=line(q.y,.009)*step(.89,q.x)*step(q.x,.935);
 float fill=step(r,.96)*(.035+.055*progress);
 float countdown=line(r-mix(.16,.965,progress),.010)*.55;
 float fissure=line(sin(p.x*14.+sin(p.y*12.))*cos(p.y*10.),.035)*step(r,.93)*progress*.2;
 float pulse=.85+.15*sin(age*7.);
 if(front_only){fill=0.;countdown=0.;fissure=0.;}
 ALBEDO=tint.rgb;EMISSION=tint.rgb*(.45+.55*progress);
 ALPHA=clamp(edge+glyph*.7+fill+countdown+fissure,0.,.9)*strength*pulse;
}
