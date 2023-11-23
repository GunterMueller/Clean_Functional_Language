definition module Relocations;

from State import :: State;

relocate_text :: !Int !Int /* end JMP */ !Int !Int !Int !Int !Int !Int !Int !State !*{#Char} !Int !String -> (!*{#Char},!State);
