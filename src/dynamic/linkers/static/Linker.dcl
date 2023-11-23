definition module Linker;

from StdFile import :: Files;
from State import :: State;
from PlatformLinkOptions import :: PlatformLinkOptions;

link_xcoff_files :: !Bool ![String] ![String] ![String] !String !String !String !Int !PlatformLinkOptions !Files  -> (!*State,!Files);
