shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,blend_add;
uniform vec4 tint : source_color=vec4(.65,.57,.40,1);
uniform float age=0.0;
uniform float strength=1.0;
void fragment(){
 float tail=pow(UV.x,.8)*(1.0-smoothstep(.96,1.0,UV.x));
 float edge=pow(1.0-UV.y,1.8);
 float fibres=.48+.52*pow(max(0.0,sin(UV.y*89.0+UV.x*13.0-age*7.0)),3.0);
 float split=smoothstep(.12,.48,sin(UV.x*18.0+UV.y*7.0)*.5+.5);
 ALBEDO=tint.rgb;EMISSION=tint.rgb*(.85+edge*1.2);
 ALPHA=tail*edge*fibres*strength*(.75+.25*split)*1.4;
}
