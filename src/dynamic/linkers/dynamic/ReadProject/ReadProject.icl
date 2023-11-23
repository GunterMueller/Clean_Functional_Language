module ReadProject;

import
	StdEnv;

import
	ReadState;

import
	ExtFile;

Start world
	= accFiles f world;
where {
	f files
		#! (state,files)
			= ReadState dat_file files;
		# (messages,state)
			= st_getLinkerMessages state;		
		
		= ((messages,state),files);
		
	dat_file
		//= "\\windows\\desktop\\compiler\\main.dat";
		= "www:Test project:a.dat";
}

/*
	#! (dat_ok,state,files) 
		= ReadState dat_file files;
*/