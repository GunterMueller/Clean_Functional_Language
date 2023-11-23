definition module PmPath


import StdFile, StdOverloaded, StdString//, StdMaybe
import StdPathname

//1.3
from UtilStrictLists import List
from PmTypes import Modulename, Processor
//3.1
/*2.0
from UtilStrictLists import ::List
from PmTypes import ::Modulename, ::Processor
0.2*/

IsDefPathname :: !Pathname -> Bool;
IsImpPathname :: !Pathname -> Bool;
IsPrjPathname :: !Pathname -> Bool;
MakeDefPathname :: !String -> Pathname;
MakeImpPathname :: !String -> Pathname;
MakeABCPathname :: !String -> Pathname;
MakeObjPathname	:: !Processor !String -> Pathname;
MakeProjectPathname	:: !String -> Pathname;
MakeExecPathname :: !String -> Pathname;
MakeABCSystemPathname :: !Pathname !Files -> (!Pathname,!Files);
MakeObjSystemPathname :: !Processor !Pathname !Files -> (!Pathname,!Files);
GetModuleName :: !Pathname -> Modulename;

/* The name of the system directory */

SystemDir			:== "Clean System Files";

