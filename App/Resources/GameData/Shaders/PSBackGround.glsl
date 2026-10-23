precision mediump float;

varying vec2 vTexCoords;
varying vec2 vNormalizedXYCoords;

uniform sampler2D vDiffuseTexture;
uniform sampler2D vNoise1Texture;
uniform sampler2D vNoise2Texture;

uniform float vOffset;
uniform vec3 vLightPos;


void main()
{ 
  vec2 vOffsetedTexCoords1 = vTexCoords;
  vOffsetedTexCoords1.x -= vOffset;       
  vec4 vNoise1 = texture2D(vNoise1Texture, vOffsetedTexCoords1);
  vNoise1.xyz = (vNoise1.xyz - 0.5) * 2.0;
  
  vec2 vOffsetedTexCoords2 = vTexCoords;
  vOffsetedTexCoords2.x += vOffset;    
  vec4 vNoise2 = texture2D(vNoise2Texture, vOffsetedTexCoords2);
  vNoise2.xyz = (vNoise2.xyz - 0.5) * 2.0;
  vec4 vNoise = normalize(vNoise1 + vNoise2);
  
  vec3 vPixelToLightPos = vLightPos - vec3(vNormalizedXYCoords.x, vNormalizedXYCoords.y, 0.0);
  //vec3 vPixelToCamera = vec3(0.0, 0.0, 1.0) - vec3(vNormalizedXYCoords.x, vNormalizedXYCoords.y, 0.0);  
  vec3 vPixelToCamera = vPixelToLightPos;
  vec3 vHalfDir = vPixelToLightPos + vPixelToCamera;
  
  float fCos = dot(normalize(vHalfDir), normalize(vNoise.xyz));  
  float fGlosiness = 192.0;
  float vSpecularFactor = pow(fCos, fGlosiness); 
  vSpecularFactor = clamp(vSpecularFactor, 0.01, 0.99) * 2.5;
  
  float fLenght = clamp(length(vPixelToLightPos.xy), 0.5, 2.0);
  //float fMask = clamp(fLenght, 0.5, 1.0);
  //fMask = (fMask - 1.0) * -2.0;
  
  vec2 vOffsetedCoords = vTexCoords - (vNoise.xy / (50.0 * fLenght));
  //vec2 vOffsetedCoords = vTexCoords + ((vNoise.xy * fMask) / (13.0 * fLenght));
  vOffsetedCoords = clamp(vOffsetedCoords, 0.01, 0.99);

  vec4 vColor = texture2D(vDiffuseTexture, vOffsetedCoords);
  vec4 vSpecularColor = vec4(1.0, 0.8, 0.0, 1.0);
  vColor = mix(vColor, vSpecularColor, vSpecularFactor);
  //gl_FragColor = vec4(vColor.x, vColor.y, vColor.z, 1.0);
  gl_FragColor = vec4(vColor.x, vColor.y, vColor.z, 0.8); // Альфа 0.8 для полупрозрачности
}



