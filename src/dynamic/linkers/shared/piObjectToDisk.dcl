definition module piObjectToDisk;

// platform independent Object to Disk

from StdFile import :: Files;
from PlatformLinkOptions import :: PlatformLinkOptions;
from State import :: State;

/*
write_object_to_disk :: !Bool .{#Char} Int Int Int .LibraryList Int *{#Bool} *{#Int} *{#*Xcoff} *Files !*NamesTable !PlatformLinkOptions
 -> (/*!Bool,*/!*State,!PlatformLinkOptions,*Files);
*/
write_object_to_disk :: !PlatformLinkOptions !*State !*Files -> (!*State,!PlatformLinkOptions,!*Files);
