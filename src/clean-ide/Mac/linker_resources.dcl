definition module linker_resources;

from StdFile import :: Files;

:: ResourceClass = Classic | Carbon | MachO;

read_application_options :: !{#Char} !*Files -> (!Bool,(!Int, !{#Char}), !Int, !Int, !Int, !Int, !Int, !Int, !Int, !Int, !*Files);
create_application_resource :: !{#Char} !ResourceClass /* RWS ... */ !Bool /* ... RWS */ (!Int, !{#Char}) !Int !Int !Int !Int !Int !Int !Int !*Files -> (!Bool,!*Files);
