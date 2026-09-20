shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 inlay_color : source_color = vec4(.34,.25,.13,1.0);
uniform float clock_seconds = 0.0;
uniform float readiness : hint_range(0.0,1.0) = 0.0;
uniform float release_strength : hint_range(0.0,1.0) = 0.0;
uniform float flow_direction = 1.0;
uniform float effect_weight : hint_range(0.0,1.0) = 1.0;
void fragment() {
    ALBEDO = inlay_color.rgb * .48;
    METALLIC = .68;
    ROUGHNESS = .38;
    float wave = pow(.5 + .5 * sin(UV.x*31.0 - clock_seconds*flow_direction*(2.1+readiness*3.0)), 6.0);
    EMISSION = inlay_color.rgb * effect_weight * (.10 + wave*.23 + readiness*(.25+wave*.42) + release_strength*1.1);
}
