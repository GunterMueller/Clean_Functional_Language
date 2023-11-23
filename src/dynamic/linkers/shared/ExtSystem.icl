implementation module ExtSystem;

import
	StdEnv;
	
import
	pdExtSystem;
	
// a word ABCD is represented in memory as:
:: ByteOrder 
	= BigEndian		// ABCD	e.g. PowerPC 
	| LittleEndian	// DCBA e.g. Intel x86
	;
	
// Extract a byte from a word ABCD at index index. Byte A is the most significant
// byte.
extract_D_from_ABCD	abcd index :== extract_D_from_ABCD abcd index
where {
	extract_D_from_ABCD abcd index
		| IsLittleEndian
			= toInt abcd.[index + 0];
};

extract_C_from_ABCD abcd index :== extract_C_from_ABCD abcd index
where {
	extract_C_from_ABCD abcd index
		| IsLittleEndian
			=  (toInt abcd.[index + 1]) << 8;
};

extract_B_from_ABCD abcd index :== extract_B_from_ABCD abcd index
where {
	extract_B_from_ABCD abcd index
		| IsLittleEndian
			= (toInt abcd.[index + 2]) << 16;
};

extract_A_from_ABCD abcd index :== extract_A_from_ABCD abcd index
where {
	extract_A_from_ABCD abcd index
		| IsLittleEndian
			= (toInt abcd.[index + 3]) << 24;
};