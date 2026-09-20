shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never,shadows_disabled;
uniform vec4 tint : source_color=vec4(.6,.7,.65,1);
uniform float emission_scale=1.0;
uniform float age=0.0;
uniform float strength=1.0;
uniform float seed=0.0;
void fragment(){
 float across=pow(max(0.0,1.0-abs(UV.y*2.0-1.0)),1.6);
 float ends=pow(max(0.0,sin(UV.x*3.14159265)),.7);
 float filaments=.45+.55*pow(sin(UV.y*35.0+sin(UV.x*22.0-age*9.0+seed)*1.6),2.0);
 ALBEDO=tint.rgb;
 EMISSION=(tint.rgb*.85)*emission_scale;
 ALPHA=across*ends*filaments*strength*.6;
}
