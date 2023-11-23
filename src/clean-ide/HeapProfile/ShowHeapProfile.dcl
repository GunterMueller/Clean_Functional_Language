definition module ShowHeapProfile

import StdPicture, StdPrint

:: ProgState a =
	{ node_size_list::a
	, node_size_sum::Int
	, printingSetup :: MaybePrintSetup
	, application_name :: String
	}

:: MaybePrintSetup = NoPrintSetup | PrintSetup !PrintSetup;

empty_progstate :: MaybePrintSetup -> *ProgState [.a];

:: SizeByNodeKindElem

p_open_file_function :: {#Char} *a -> *(Bool,{#Char},ProgState [SizeByNodeKindElem],*a) | FileEnv a;

draw_heap_profile_lines :: [.Int] .Bool [.SizeByNodeKindElem] .Int .Int .Int .Int *Picture -> *Picture;

compare_function_name :: !.SizeByNodeKindElem !.SizeByNodeKindElem -> Bool;
compare_module_name :: !.SizeByNodeKindElem !.SizeByNodeKindElem -> Bool;
compare_heap_use :: !.SizeByNodeKindElem !.SizeByNodeKindElem -> Bool;

printTable :: Font .(ProgState [SizeByNodeKindElem]) *a -> *(.ProgState [SizeByNodeKindElem],*a) | PrintEnvironments a;
show_next_page :: u:(ProgState [.SizeByNodeKindElem]) *a -> *(v:ProgState [SizeByNodeKindElem],*a) | FileEnv a, [u <= v];
show_prev_page :: u:(ProgState [.SizeByNodeKindElem]) *a -> *(v:ProgState [SizeByNodeKindElem],*a) | FileEnv a, [u <= v];

determine_previous_page :: !String -> (!Bool,!Int);
determine_next_page :: !String -> (!Bool,!Int);
