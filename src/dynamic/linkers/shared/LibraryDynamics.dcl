definition module LibraryDynamics;

from StdFile import :: Files;
from State import :: State;
from PlatformLinkOptions import :: PlatformLinkOptions;

build_type_and_code_library :: [String] [String] ![String] !String !*State !*PlatformLinkOptions !*Files -> (!*State,!*PlatformLinkOptions,!*Files);
build_type_library :: [String] [String] ![String] !String !*State !*PlatformLinkOptions !*Files -> (!*State,!*PlatformLinkOptions,!*Files);
