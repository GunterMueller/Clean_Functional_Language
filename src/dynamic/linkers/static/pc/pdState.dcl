definition module pdState;

from StdMisc import abort;

sel_platform winos macos :== winos;

// dummy functions; needed because
//FIXME: well, why are they needed???
get_text_relocations	:== abort "pdState: dummy";
get_data_relocations	:== abort "pdState: dummy"; 
get_header				:== abort "pdState: dummy";
get_n_symbols			:== abort "pdState: dummy";
get_text_v_address		:== abort "pdState: dummy";
get_data_v_address		:== abort "pdState: dummy";
get_toc0_symbols		:== abort "pdState: dummy";
get_toc_symbols			:== abort "pdState: dummy";
sel_file_name			:== abort "pdState: dummy";

:: *PDState;

DefaultPDState :: *PDState;
