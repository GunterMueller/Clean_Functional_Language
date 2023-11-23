definition module gc_state

from StdMaybe import :: Maybe

:: *State
	= {
	// from user space:
		s_user_dynamics			:: !*{#UserDynamic}
	,	s_user_applications		:: !*{#DynamicApp}

	// from system space:
	,	system_dynamics			:: !*{#SystemDynamic}
	,	non_system_dynamics		:: ![String]
	
	,	system_libraries		:: !*{#Library}
	,	non_system_libraries	:: ![String]
	
	// dynamic linker path:
	,	dynamic_linker_path		:: !String
	}

initial_state :: *State
		
:: SystemDynamic
	= {
		sd_id						:: !String
	,	sd_count					:: !Int
	,	sd_passed_md5_check			:: !Maybe Bool
	,	sd_unknown_libraries		:: !{String}
	,	sd_unknown_system_dynamics	:: !{String}
	}
	
initial_system_dynamic :: SystemDynamic
	
:: Library
	= {
		l_id				:: !String
	,	l_used				:: !Bool
	,	l_passed_md5_check	:: !Maybe Bool
	,	l_lib_ok			:: !Bool
	,	l_typ_ok			:: !Bool
	}
		
:: UserDynamic
	= {
		ud_name				:: !String
	,	ud_path_name_ext	:: !String
	,	ud_system_id		:: !String
	,	ud_system_exists	:: !Bool
	}

initial_user_dynamic :: UserDynamic
	
:: DynamicApp
	= {
		da_name				:: !String
	,	da_path_name_ext	:: !String
	,	da_library_id		:: !String
	, 	da_library_exists	:: !Bool
	}

initial_user_application :: DynamicApp

:: UserState
	= {
		us_dynamics			:: [UserDynamic]
	,	us_applications		:: [DynamicApp]
	}

initial_user_state :: UserState
