implementation module library_identification

from StdReal import entier; // RWS marker

import StdEnv
import ExtFile

encode_library_identification :: !String !String !String -> String
encode_library_identification application_name code_id type_id
	#! application_name
		= snd (ExtractPathAndFile (fst (ExtractPathFileAndExtension application_name)))
	#! library_id_string
		= application_name +++ "_" +++ code_id +++ "_" +++ type_id;
	= library_id_string;
	