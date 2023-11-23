definition module UtilPatch

// RWS ...
/* this function is compatible with patchbin in the Unix Clean
   distribution (1.3), variableName should be ' ' (space) padded
   to 10 characters, value should end with a null character
*/ 
PatchableValue :: {#Char} !{#Char} -> {#Char};
// ... RWS
