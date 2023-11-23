definition module pdReadState;

// macOS
import SymbolTable;

read_xcoff :: !String !Int !{#*Xcoff} !*File -> !(!{#*Xcoff},!*File);
