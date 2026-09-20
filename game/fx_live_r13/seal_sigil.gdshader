shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint:source_color=vec4(.72,.64,.42,1);
uniform float age=0.0;
uniform float strength=1.0;
uniform float rupture=0.0;
float stroke(float d,float width){return 1.0-smoothstep(width,width+.004,abs(d));}
void fragment(){
 vec2 p=UV-.5;float r=length(p);float a=atan(p.y,p.x);
 float band=stroke(r-.38,.0035)*step(.2,abs(sin(a*3.+.3)));
 band+=stroke(r-.30,.0025)*step(.38,abs(sin(a*6.-age*.08)));
 float sector=mod(a+3.14159265,1.04719755)-.52359878;
 vec2 q=vec2(cos(sector),sin(sector))*r;
 float rune=stroke(q.y,.006)*step(.322,q.x)*step(q.x,.36);
 rune+=stroke(abs(q.y)-(q.x-.32)*.65,.004)*step(.32,q.x)*step(q.x,.36);
 float diamond=stroke(abs(p.x)+abs(p.y)-.14,.005);
 float inner=stroke(abs(p.x)*1.9+abs(p.y)-.075,.0035);
 float texture_noise=fract(sin(dot(floor(UV*310.),vec2(12.9898,78.233)))*43758.5453);
 float ash=mix(.55,1.,texture_noise);float cracks=step(rupture,fract(sin(floor(a*11.)*7.71)*73.1));
 float alpha=clamp(band+rune+diamond+inner,0.,1.)*ash*strength*cracks;
 ALBEDO=tint.rgb;EMISSION=tint.rgb*(.65+.18*sin(age*2.));ALPHA=alpha;
}
