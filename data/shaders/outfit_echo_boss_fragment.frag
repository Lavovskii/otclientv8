uniform mat4 u_Color;
varying vec2 v_TexCoord;
varying vec2 v_TexCoord2;
varying vec2 v_Texel;
uniform sampler2D u_Tex0;

const vec3 RED = vec3(1.0, 0.125, 0.125);
const float HALO = 0.45;
const float EMPTY = 0.01;

float alphaAt(vec2 d)
{
    return texture2D(u_Tex0, v_TexCoord + d * v_Texel).a;
}

// 1 if there is only air from d on in that direction: a small hole or gap in the sprite gets no contour
float isClearFrom(vec2 d)
{
    float a = max(max(alphaAt(d), alphaAt(d * 2.0)), max(alphaAt(d * 3.0), alphaAt(d * 4.0)));
    return max(a, alphaAt(d * 5.0)) < EMPTY ? 1.0 : 0.0;
}

// 1 if the sprite is on the side of d and only air on the other
float isBesideSprite(vec2 d)
{
    return step(EMPTY, alphaAt(d)) * isClearFrom(-d);
}

// The contour is the sprite's own outermost pixels, with a soft pixel just outside them. The engine only draws the box around
// the sprite, so the soft ones are missing where the sprite touches that box, which doesn't show
void main()
{
    gl_FragColor = texture2D(u_Tex0, v_TexCoord);
    if(gl_FragColor.a < EMPTY) {
        float beside = max(max(isBesideSprite(vec2(1.0, 0.0)), isBesideSprite(vec2(-1.0, 0.0))),
                           max(isBesideSprite(vec2(0.0, 1.0)), isBesideSprite(vec2(0.0, -1.0))));
        if(beside < 0.5) discard;
        gl_FragColor = vec4(RED, HALO);
        return;
    }
    float edge = max(max(isClearFrom(vec2(1.0, 0.0)), isClearFrom(vec2(-1.0, 0.0))),
                     max(isClearFrom(vec2(0.0, 1.0)), isClearFrom(vec2(0.0, -1.0))));
    if(edge > 0.5) {
        gl_FragColor = vec4(RED, 1.0);
        return;
    }
    vec4 texcolor = texture2D(u_Tex0, v_TexCoord2);
    if(texcolor.r > 0.9) {
        gl_FragColor *= texcolor.g > 0.9 ? u_Color[0] : u_Color[1];
    } else if(texcolor.g > 0.9) {
        gl_FragColor *= u_Color[2];
    } else if(texcolor.b > 0.9) {
        gl_FragColor *= u_Color[3];
    }
}
