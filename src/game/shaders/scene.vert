ATTR vec3 vertexPosition;
ATTR vec3 vertexNormal;
ATTR vec2 vertexTexCoord;
uniform mat4 mvp;
uniform mat4 matNormal;
uniform mat4 matModel;
uniform mat4 matView;
uniform mat4 matProjection;
uniform float windTime;
uniform float sway; // how far the top of the shape moves in the wind
VARY vec3 normal;
VARY vec3 position;
VARY vec3 local;
VARY vec2 uv;
void main() {
    local = vertexPosition;
    uv = vertexTexCoord;
    normal = normalize((matNormal * vec4(vertexNormal, 0.0)).xyz);
    position = (matModel * vec4(local, 1.0)).xyz;
    if (sway > 0.0) {
        // Leaves move in the wind; the higher on the shape, the more.
        float phase = position.x * 0.37 + position.z * 0.29;
        vec3 push = vec3(sin(windTime * 1.7 + phase), 0.0, cos(windTime * 1.3 + phase * 1.3));
        position += push * sway * (local.y * 0.5 + 0.5);
        gl_Position = matProjection * matView * vec4(position, 1.0);
    } else {
        gl_Position = mvp * vec4(local, 1.0);
    }
}
