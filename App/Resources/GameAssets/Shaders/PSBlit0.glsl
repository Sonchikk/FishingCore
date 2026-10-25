precision mediump float;

varying vec2 vTexCoords;

uniform sampler2D vDiffuseTexture;

void main()
{
  vec4 vColor = texture2D(vDiffuseTexture, vTexCoords);
  //gl_FragColor = vec4(vColor.x, vColor.y, vColor.z, 1.0);
  //gl_FragColor = vec4(1.0, 1.0, 0.0, 1.0);
  gl_FragColor = vec4(vColor.x, vColor.y, vColor.z, 0.9);
}


