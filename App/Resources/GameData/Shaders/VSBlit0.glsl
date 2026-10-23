attribute vec2 vInPosition;
attribute vec2 vInTexCoords;

varying vec2 vTexCoords;

invariant gl_Position;

void main() 
{
  gl_Position = vec4(vInPosition.x, vInPosition.y, 0.5, 1.0);
   
  vTexCoords = vInTexCoords;  
}