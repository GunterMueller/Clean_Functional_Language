module BatchBuild

import StdEnv
import ArgEnv
import PmDriver
import PmProject
import IdeState
from UtilIO import GetFullApplicationPath,GetLongPathName
import PmEnvironment, logfile, set_return_code
from Platform import application_path,EnvsDirName,IF_WINDOWS,DirSeparator,DirSeparatorString

Start world
	# commandline				= getCommandLine
	  args						= [arg \\ arg <-: commandline]
	  (path_ok,force_rebuild,proj_path)
			= case args of
				[_,prj]
					-> (True,False,GetLongPathName prj)
				[_,"--force",prj]
					-> (True,True,GetLongPathName prj)
				_
					-> (False,False,"")
	  (startup,world) = accFiles GetFullApplicationPath world
	  startup = IF_WINDOWS startup (remove_dir_separator_bin_at_end startup)
	  envspath = IF_WINDOWS
					(application_path (EnvsDirName+++EnvsFileName))
					(startup+++(DirSeparatorString+++EnvsDirName+++EnvsFileName))
	  (envs,world)				= openEnvironments startup envspath world
//	| not ok					= wAbort ("Unable to read environments\n") world
	| not path_ok				= wAbort ("BatchBuild\nUse as: 'BatchBuild [--force] projectname.prj'\n") world
	# ((proj,ok,err),world)		= accFiles (ReadProjectFile proj_path startup) world
	| not ok || err <> ""		= wAbort ("BatchBuild failed while opening project: "+++.err+++."\n") world
	# (ok,logfile,world)		= openLogfile proj_path world
	| not ok					= wAbort ("BatchBuild failed while opening logfile.\n") world
	# default_compiler_options	= DefaultCompilerOptions
	# iniGeneral				= initGeneral True default_compiler_options startup proj_path proj envs logfile
	# ps = {ls=iniGeneral,gst_world=world,gst_continue_or_stop=False}
	# {ls,gst_world} = pinit force_rebuild ps
	= finish gst_world

remove_dir_separator_bin_at_end :: !{#Char} -> {#Char}
remove_dir_separator_bin_at_end s
	# size_s = size s
	| size_s>=4 && s.[size_s-4]==DirSeparator && s.[size_s-3]=='b' && s.[size_s-2]=='i' && s.[size_s-1]=='n'
		= s % (0,size_s-5)
		= s

pinit force_rebuild ps
	= BringProjectUptoDate force_rebuild cleanup ps
where
	cleanup exepath bool1 bool2 ps
		= abortLog (not bool2) "" ps

wAbort message world
	# stderr		= fwrites message stderr
	# (ok,world)	= fclose stderr world
	# world			= set_return_code_world (-1) world
	= finish world

finish w = w
