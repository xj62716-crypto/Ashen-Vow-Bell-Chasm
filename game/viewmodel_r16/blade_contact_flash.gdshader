shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
uniform vec4 colour:source_color=vec4(.8,.85,.77,1.);
void fragment(){
 float ends=pow(max(0.,sin(UV.x*3.14159265)),.65);
 float feather=exp(-pow((UV.y-.5)*6.,2.));
 float notch=.82+.18*sin(UV.x*48.);
 ALBEDO=colour.rgb;
 EMISSION=colour.rgb*(.65+feather);
 ALPHA=ends*feather*notch*.75;
}
