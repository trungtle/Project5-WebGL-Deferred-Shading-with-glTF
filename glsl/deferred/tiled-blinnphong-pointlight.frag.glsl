#version 100
#extension GL_EXT_draw_buffers: enable

precision highp float;
precision highp int;

#define NUM_GBUFFERS 4
#define NUM_MAX_LIGHTS 200
#define LIGHT_GRID_CELL_DIM 32

uniform vec3 u_cameraPos;
uniform sampler2D u_gbufs[NUM_GBUFFERS];
uniform sampler2D u_depth;

// Texture that stores all light positions, colors, radius
uniform sampler2D u_lightCol;
uniform sampler2D u_lightPos;
uniform sampler2D u_lightRad;

// The structure that contains light indices for each tile
uniform sampler2D u_tileLightIndices;

// The light count and light index offet for looking up into u_tileLightIndices
uniform int u_lightCount;
uniform int u_lightOffset;

// Tile index
uniform int u_tileIdx;

uniform bool u_colorLightCountOnly;

varying vec2 v_uv;

vec3 applyNormalMap(vec3 geomnor, vec3 normap) {
    normap = normap * 2.0 - 1.0;
    vec3 up = normalize(vec3(0.001, 1, 0.001));
    vec3 surftan = normalize(cross(geomnor, up));
    vec3 surfbinor = cross(geomnor, surftan);
    return normap.y * surftan + normap.x * surfbinor + normap.z * geomnor;
}

// Blinn-Phong adapted from http://sunandblackcat.com/tipFullView.php?l=eng&topicid=30&topic=Phong-Lighting

vec3 diffuseLighting(vec3 nor, vec3 col, vec3 lightCol, vec3 lightDir) {
    float diffuseTerm = clamp(dot(nor, lightDir), 0.0, 1.0);
    return lightCol * col * diffuseTerm;
}


vec3 specularLighting(vec3 col, vec3 pos, vec3 nor, vec3 lightDir) {
    float specularTerm = 0.0;

    // Compute specular term if light facing the surface
    if (dot(nor, lightDir) > 0.0) {

        vec3 viewDir = normalize(u_cameraPos - pos);
        // Half vector
        vec3 halfVec = normalize(lightDir + viewDir);
        specularTerm = pow(dot(nor, halfVec), 10.0);
    }

    return vec3(1,1,1) * specularTerm;
}


void main() {
    vec4 gb0 = texture2D(u_gbufs[0], v_uv);
    vec4 gb1 = texture2D(u_gbufs[1], v_uv);
    vec4 gb2 = texture2D(u_gbufs[2], v_uv);
    vec4 gb3 = texture2D(u_gbufs[3], v_uv);
    float depth = texture2D(u_depth, v_uv).x;
    // TODO: Extract needed properties from the g-buffers into local variables

    // If nothing was rendered to this pixel, set alpha to 0 so that the
    // postprocessing step can render the sky color.
    if (depth == 1.0) {
        gl_FragData[0] = vec4(1, 0, 0, 0);
        return;
    }

    vec3 pos = gb0.xyz;      // World-space position
    vec3 geomnor = gb1.xyz;  // Normals of the geometry as defined, without normal mapping
    vec3 colmap = gb2.rgb;   // The color map - unlit "albedo" (surface color)
    vec3 normap = gb3.xyz;   // The raw normal map (normals relative to the surface they're on)
    vec3 nor = applyNormalMap (geomnor, normap);     // The true normals as we want to light them - with the normal map applied to the geometry normals (applyNormalMap above)

    if (u_colorLightCountOnly) {
        float colorFromLightCountValue = (1.0 - 1.0 / float(u_lightCount));
       if (u_lightCount == 0) {
            colorFromLightCountValue = 0.0;
        }
        gl_FragData[0] = vec4(colorFromLightCountValue, colorFromLightCountValue, colorFromLightCountValue, 1.0);
    }


    // Loop through lights
    for (int i = 0; i < 100; ++i) {
        if (i >= u_lightCount) {
            break;
        }

    //     // Extract light info
    //     vec3 lightCol = u_lightCol[u_lightOffset + i];
    //     vec3 lightPos = u_lightPos[u_lightOffset + i];
    //     float lightRad = u_lightRad[u_lightOffset + i];

    //     // Shading
    //     vec3 lightDir = normalize(lightPos - pos);
    //     float dis = distance(lightPos, pos);
    //     if (dis < lightRad) {

    //         // Write out to colorTex
    //         float attenuation = max(0.0, lightRad - dis);
    //         vec4 color = vec4(
    //             diffuseLighting(nor, colmap, lightCol, lightDir) * attenuation +
    //             specularLighting(colmap, pos, nor, lightDir) * 0.0,
    //             1.0);
    //         gl_FragData[0] = color;

    //         // Write out to hdrTex
    //         float brightness = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    //         if (brightness > 0.7) {
    //             gl_FragData[1] = vec4(color.rgb, 1.0);
    //         }
    //     }
    }
}
