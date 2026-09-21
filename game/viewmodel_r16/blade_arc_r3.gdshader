shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_add;
uniform vec4 core_color:source_color=vec4(.79,.89,1.,1.);
uniform vec4 outer_color:source_color=vec4(.31,.055,.15,1.);
uniform float emission_power=2.8;
uniform float opacity=.65;
uniform float clock=0.;
void fragment(){
 float live=clamp(UV.x,0.,1.);
 float ridge=exp(-pow((UV.y-.69)*7.2,2.));
 float body=smoothstep(0.,.25,UV.y)*(1.-smoothstep(.94,1.,UV.y));
 float noise=sin(UV.y*49.+UV.x*21.-clock*11.)*sin(UV.y*117.-UV.x*15.);
 float erosion=mix(smoothstep(-.3,.7,noise),1.,smoothstep(.35,.8,live));
 float intensity=pow(live,.65)*body*erosion;
 vec3 colour=mix(outer_color.rgb,core_color.rgb,ridge);
 ALBEDO=colour;
 EMISSION=(core_color.rgb*ridge+outer_color.rgb*1.15*(1.-ridge))*emission_power*intensity;
 ALPHA=clamp(intensity*(.78+ridge*.65)*opacity,0.,1.);
}
