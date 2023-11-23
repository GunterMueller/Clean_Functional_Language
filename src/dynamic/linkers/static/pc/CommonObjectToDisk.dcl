definition module CommonObjectToDisk;

from StdFile import :: Files;
from PlatformLinkOptions import :: PlatformLinkOptions;
from State import :: State;

:: *WriteOutputRecord = {
		file_or_memory	:: !Int
	,	offset			:: !Int
	,	aligned_offset	:: !Int
	,	string			:: !{#Char}
	,	state			:: !*State
	};

class Target2 a
where
{
	WriteOutput :: !WriteOutputRecord !*a -> (!*State,*a)
};

write_code_to_pe_files :: !Int !Bool !Int !Int !(!Int,!Int) !State !Bool !*a !*Files -> ((!*a,!(!Int,!Int),!State),!*Files) | Target2 a;

:: *WriteState = {
		do_relocations	:: !Bool
	,	buffers			:: !*{*{#Char}}
	,	buffers_i		:: !*{#Int}
	,	text_offset		:: !Int
	,	text_buffer		:: !*{#Char}
	};
		
WriteCode :: !*File !*PlatformLinkOptions !*State !*Files -> (!*File,!*PlatformLinkOptions,!*State,!*Files,!*WriteState);
