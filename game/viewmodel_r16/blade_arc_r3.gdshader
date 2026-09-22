shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_add;
uniform vec4 core_color:source_color=vec4(.79,.89,1.,1.);
uniform vec4 outer_color:source_color=vec4(.31,.055,.15,1.);
uniform vec4 rune_color:source_color=vec4(.31,.055,.15,1.);
uniform float rune_strength=0.;
uniform float emission_power=2.8;
uniform float opacity=.65;
uniform float clock=0.;
void fragment(){
 float live=clamp(UV.x,0.,1.);
 float ridge=exp(-pow((UV.y-.50)*4.6,2.));
 float body=smoothstep(0.,.08,UV.y)*(1.-smoothstep(.96,1.,UV.y));
 float noise=sin(UV.y*49.+UV.x*21.-clock*11.)*sin(UV.y*117.-UV.x*15.);
 float erosion=mix(smoothstep(-.3,.7,noise),1.,smoothstep(.35,.8,live));
 float intensity=pow(live,.65)*body*erosion;
 vec3 rune_outer=mix(outer_color.rgb,rune_color.rgb,clamp(rune_strength,0.,1.));
 vec3 colour=mix(rune_outer,core_color.rgb,ridge);
 ALBEDO=colour;
 EMISSION=(core_color.rgb*ridge+rune_outer*1.15*(1.-ridge))*emission_power*intensity;
 ALPHA=clamp(intensity*(.62+ridge*.38)*opacity,0.,1.);
}
