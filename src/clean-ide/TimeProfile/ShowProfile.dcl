definition module ShowProfile

import StdIOCommon, StdPicture, StdPSt, StdPrint

:: Profile
:: FormattedProfile

open_profile			:: {#.Char} !*a -> *((.Bool,[.Profile]),!*a) | FileSystem a;
sum_time_and_allocation	:: ![.Profile] -> .(Int,Int,Int,Int,Real);
totals_per_module		:: ![.Profile] -> [.Profile]
format_profile			:: .Int .Int .Int .Int .Real [.Profile] -> ([.FormattedProfile],.FormattedProfile);

le_module_name			:: !.Profile !.Profile -> Bool;

ge_profile_time			:: !.FormattedProfile !.FormattedProfile -> Bool;
g_profile_time			:: !.FormattedProfile !.FormattedProfile -> Bool;
le_profile_name			:: !.FormattedProfile !.FormattedProfile -> Bool;
l_profile_name			:: !.FormattedProfile !.FormattedProfile -> Bool;
ge_profile_byte			:: !.FormattedProfile !.FormattedProfile -> Bool;
ge_profile_strict		:: !.FormattedProfile !.FormattedProfile -> Bool;
ge_profile_lazy			:: !.FormattedProfile !.FormattedProfile -> Bool;
ge_profile_curried		:: !.FormattedProfile !.FormattedProfile -> Bool;

l_module_name			:: !.FormattedProfile !.FormattedProfile -> Bool;
g_profile_byte			:: !.FormattedProfile !.FormattedProfile -> Bool;
g_profile_strict		:: !.FormattedProfile !.FormattedProfile -> Bool;
g_profile_lazy			:: !.FormattedProfile !.FormattedProfile -> Bool;
g_profile_curried		:: !.FormattedProfile !.FormattedProfile -> Bool;

//draw_profile_lines		:: [.Int] ![.FormattedProfile] .Int .Int UpdateArea *Picture -> .Picture;
draw_profile_lines`		:: .Int [.Int] ![.FormattedProfile] .Int .Int !UpdateArea *Picture -> *Picture;
printTable :: Font !PrintSetup [.FormattedProfile] .FormattedProfile !*(PSt .a) -> *(PrintSetup,*PSt .a);

//--

//Start` :: !*World -> *World
