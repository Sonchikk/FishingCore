precision mediump float;

varying vec2 vTexCoords;

uniform sampler2D vDiffuseTexture;

void main()
{
  vec4 vColor = texture2D(vDiffuseTexture, vTexCoords);
  
  float fAverage = (vColor.x + vColor.y + vColor.z) / 4.2;
  vec4 vBlackColor = vec4(fAverage, fAverage, fAverage, 1.0);
  vec4 vFinalColor = mix(vBlackColor, vColor, vBlackColor);  
  //gl_FragColor = vec4(vFinalColor.x, vFinalColor.y, vFinalColor.z, 1.0);
  //gl_FragColor = vec4(vColor.x, vColor.y, vColor.z, 1.0);
  //gl_FragColor = vec4(1.0, 1.0, 0.0, 1.0);
  gl_FragColor = vec4(vFinalColor.x, vFinalColor.y, vFinalColor.z, 0.9);
}


