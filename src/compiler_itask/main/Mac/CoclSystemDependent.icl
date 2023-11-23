// this is for the PowerMac
implementation module CoclSystemDependent

// import for filesystem
import code from "cDirectory."; // this is the only platform dependent line in this module

import StdEnv
import Clean2AppleEventHandler,compile,docommand,cache_variable

from Clean2AppleEventHandler import get_apple_event_string;
import DirectorySeparator

PathSeparator
	:==	','

script_handler :: !{#Char} *Files -> (!Int,!*Files);
script_handler script files
	= case args of
		["cocl":coclArgs]
			# cache = load_state 0;
			# (ok,cache,files) = compile coclArgs cache files;
			->	(if ok 1 0,store_cache_or_clear_cache cache files)
		["clear_cache"]
			# cache = load_state 0;
			| store_state (empty_cache cache.hash_table.hte_symbol_heap)>0
//				# (r,s) = DoCommandNullTerminated ("clear_cache" +++ "\0") 0
				# r=clear_cache 1
//				# r=1
				-> (r,files)
//				# (r,s) = DoCommandNullTerminated ("clear_cache" +++ "\0") 0
				# r=clear_cache 1
//				# r=1
				-> (r,files)
		_
			// +++ handle errors from docommand
			# (r,s) = DoCommandNullTerminated (script +++ "\0") 0
//			# r=1
			-> (r,files)
	where
		args
			=	filter ((<>) "") (map replace scriptArgs)
		scriptArgs
			=	splitArgs script

		store_cache_or_clear_cache cache files
			| isMember "-clear_cache" scriptArgs
				| store_state (empty_cache cache.hash_table.hte_symbol_heap)>0
					# r=clear_cache 1
//					# (r,s)=DoCommandNullTerminated "clear_cache\0" 0
					| r==0
						= files;
						= files;
					= files;
			| store_state cache>0
				=	files
				=	files

		replace s
			| s == "\xb3" /* \xb3 == >= ligature */
				=	"-RE"
			| s == ">"
				=	"-RO"
			| s == "-clear_cache"
				=	""
			// otherwise
				=	s

		splitArgs s
			=	split False 0 0 (size s) s
		where
			split quoted frm to n s
				| to >= n
					=	[s % (frm, to)]
				| s.[to] == '\\' && to < n-1
					=	split quoted frm (to+2) n s
				| s.[to] == ' ' && not quoted 
					=	[s % (frm, to-1) : split False (to+1) (to+1) n s]
				| s.[to] == '\''
					| quoted
						| to<n-1 && s.[to+1]=='\''
							# s=(s % (0,to-1))+++(s % (to+1,n-1))
							= split quoted frm (to+1) (n-1) s
					=	[s % (frm, to-1) : split False (to+1) (to+1) n s]
					=	[s % (frm, to-1) : split True (to+1) (to+1) n s]
				// otherwise
					=	split quoted frm (to+1) n s

//import StdDebug,StdString;

//get_apple_event_string_dummy :: !Int !String -> Int;
//get_apple_event_string_dummy _ _ = 0;

clean2_compiler :: !Int !*Files -> (!Int,!*Files);
clean2_compiler length files
	# string=createArray length ' ';
	# r=get_apple_event_string length string;
//	| trace_t length && trace_t ':' && trace_t r && trace_t '\n'
//	| trace_t string

	| r==r
//		= (1,files);
		= script_handler (string%(6,r-1)) files;
//		= (0,files);
//		= (0,files);

clean2_compile :: !Int -> Int;
clean2_compile length
	# (r,files)=clean2_compiler length create_files;
	= r;

clean2_compile_c_entry :: !Int -> Int;
clean2_compile_c_entry r = code {
	.d 0 1 i
	rtn
	centry clean2_compile e_CoclSystemDependent_sclean2_compile "I:I"
 }

set_compiler_id :: !Int -> Int;
set_compiler_id id = code {
	ccall set_compiler_id "I:I"
 };

clear_cache :: !Int -> Int;
clear_cache i = code {
 	ccall clear_cache ":V:I"
 }

::	* MyFiles = MyFiles;

create_myfiles = MyFiles;

create_files :: *Files;
create_files = cast create_myfiles;

cast :: !*a -> *b;
cast f = code {
	pop_b 0
 }

ensureCleanSystemFilesExists :: !String !*Files -> (!Bool, !*Files)
ensureCleanSystemFilesExists _ files = (True, files)
  // because of dcl file caching the Clean System Files folder should exist always
 