implementation module Ext_deltaIOState;

import StdFile;

from deltaIOState import class FileEnv, instance FileEnv (IOState s), ::IOState;

instance FileSystem (IOState s)
where {
	fopen a0 a1 io
		#! ((r0,r1),io)
			= accFiles fopen2 io;
		= (r0,r1,io);
	where {
		fopen2 files
			# (r0,r1,files)
				= fopen a0 a1 files;
			= ((r0,r1),files);
	} // fopen
	
	fclose file io
		= accFiles (fclose file) io; 
	
	stdio io
		= accFiles stdio io;
	sfopen a0 a1 io
		#! ((r0,r1),io)
			= accFiles fopen2 io;
		= (r0,r1,io);
	where {
		fopen2 files
			# (r0,r1,files)
				= sfopen a0 a1 files;
			= ((r0,r1),files);
	} // sfopen

};
