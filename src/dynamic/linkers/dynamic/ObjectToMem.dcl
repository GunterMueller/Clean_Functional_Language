definition module ObjectToMem;

from StdFile import class FileEnv;
from StdMaybe import :: Maybe;
from State import :: State;
from DLState import :: DLClientState;
from UnknownModuleOrSymbol import :: ModuleOrSymbolUnknown;
from pdObjectToMem import ::WriteImageInfo;	
from LibraryInstance import ::Libraries;

LinkUnknownSymbols :: [ModuleOrSymbolUnknown] !*State !Int !Libraries !*DLClientState *f -> *(*(!(Maybe WriteImageInfo),[Int],!*State,!*DLClientState),*f) | FileEnv f;
