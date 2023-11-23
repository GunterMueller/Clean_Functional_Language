definition module Relocations;

import StdString;
import SymbolTable;
import State;

//relocate_text :: Int Int !Int !Int !String !String SymbolsArray !Int {#Int} {#Int} !Int !Int !SymbolIndexList SymbolArray *String *String -> (!*String,!*String);
//relocate_data :: Int Int Int Int Int String Int {#Int} {#Int} {!Symbol} SymbolsArray *{#Char}-> *{#Char};
relocate_text2 :: Int Int !Int !Int !Int !String !String  !Int   !Int !Int !SymbolIndexList  *String *String !*State -> (!*String,!*String,!*State);
