definition module heap_profile_os_dependent

import StdInt,StdBool,StdClass,StdArray,StdFile;

PCorMac pc mac :== mac;

::	Header = {
		heap_begin		:: !Int,
		heap_end		:: !Int,
		heap2_begin		:: !Int,
		heap2_end		:: !Int,
		text_begin		:: !Int,	// for PowerPC
		data_begin		:: !Int,
		small_integers	:: !Int,
		characters		:: !Int,
		text_addresses	:: !{#Int}	// for 68k
	};

FileExists	:: !String -> Bool;

IF_BIG_ENDIAN big little :== big;

:: Text :== {#Char};

read_application_name :: !*File -> (!{#Char},!*File);
read_text_addresses :: !*File -> (!{#Int},!*File);
read_application :: !{#Char} !{#Char} Header !Files -> (!Bool,!{#Char},!Text,Header,!Files);

PageNumberOffsetFromEndInFileName:==1;

get_text_resource_n address header text :== in_text_section address header.text_begin (size text);

in_text_section :: !Int !Int !Int -> Int;

long_in_text_resource _ /*text_resource_n*/ a header text
	:== text LONG (a-header.text_begin);

relocate_descriptor descriptor header :== descriptor+header.data_begin;

is_closure descriptor :== (descriptor bitand 2)==0;

non_relocated_descriptor_to_data_offset descriptor _/*header*/ _/*data*/ :== descriptor-2;

relocated_descriptor_to_data_offset descriptor header _ /*data*/ :== descriptor-2-header.data_begin;

address_to_data_offset a data_begin _ /*data*/ :== a-data_begin;

non_record_arity :: !Int -> Int;

constructor_name data_begin data_offset arity data text :== constructor_name_ data_offset arity data text;

constructor_name_ :: !Int !Int !{#Char} {#Char} -> (!{#Char},!{#Char});

closure_text_offset descriptor _ /*text_resource_n*/ header
	:== descriptor-header.text_begin-4;

get_closure_arity text_offset _ /*text_resource_n*/ text
	:== text LONG text_offset;

is_selector arity :== arity<0 && arity>=(-4);

get_closure_name :: !Int .a .b .c !{#Char} !{#Char} -> .(!{#Char},!{#Char});
record_name :: .a !Int !{#Char} .b -> .(!{#Char},!{#Char});

(LONG) :: !{#Char} !Int -> Int;
