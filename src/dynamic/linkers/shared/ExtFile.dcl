definition module ExtFile;

from StdOverloaded import class + (+), class - (-), class == (==),
			class < (<),  class zero (zero), class one (one);
from StdClass import class IncDec, inc, class Eq, <=, class Ord;
from StdBool import ||, not;
from StdFile import fwritei, fwrites, fwritec, freadi;
from StdTuple import fst, snd;
from StdList import map;
from ExtString import ends;
from StdArray import class Array (..);

from ExtArray import class ExtArrayDefaultElem (ExtArrayDefaultElem),
		loopAfill, loopA, loopAur;

import link32or64bits;

(FWI) infixl;
(FWI) f i :== fwritei i f;

(FWL) infixl;
(FWL) f i :== Link32or64bits (fwritei i f) (fwritei 0 (fwritei i f));

(FWS) infixl;
(FWS) f s :== fwrites s f;

(FWC) infixl;
(FWC) f c :== fwritec c f;

(FWZ) infixl;
(FWZ) f i :== write_zero_bytes_to_file i f;

(THEN) infixl;
(THEN) a f :== f a;

write_zero_bytes_to_file :: !Int !*File -> *File;
write_zero_longs_to_file :: !Int !*File -> *File;

ExtractPathAndFile :: !String -> (!String,!String);
ExtractFileNameFromPath :: !String -> String;
ExtractPathFileAndExtension :: !String -> (!String,!String);
construct_path :: !String !String -> String;

loopAonOutput f a output :== loopAonOutput2 f a output
where {
	loopAonOutput2 f a output
		#! (s_a,a)
			= usize a;
		#! output
			= fwritei s_a output;
		= loopA f a output;
}

loopAurOnOutput f a output :== loopAurOnOutput f a output
where {
	loopAurOnOutput f a output
		#! (s_a,a)
			= usize a;
		#! output
			= fwritei s_a output;
		= loopAur f a output;
}

loopAfillOnInput f s :== loopAfillOnInput f s
where {
	loopAfillOnInput f s
		#! (_,s_a,s)
			= freadi s;
		= loopAfill f (createArray s_a ExtArrayDefaultElem) s
}
		
loopAurfillOnInput f s :== loopAfillOnInput f s
where {
	loopAfillOnInput f s
		#! (_,s_a,s)
			= freadi s;
		= loopAfill f {ExtArrayDefaultElem \\ i <- [1..s_a]} s
}

read_int :: !Int !*{#Int} !*File -> (!*{#Int},!*File);

extract_module_name :: !String -> String;

strip_abc_and_o_extension path_file_extension :== if ((ends path_file_extension ".obj") || (ends path_file_extension ".lib")) path_file_extension (fst (ExtractPathFileAndExtension path_file_extension));
strip_paths_from_file_names files :== map (\path_name_extension -> (snd (ExtractPathAndFile path_name_extension))) files;

ExtractFileName :: !String -> String;
