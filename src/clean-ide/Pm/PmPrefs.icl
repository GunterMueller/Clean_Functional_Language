implementation module PmPrefs

import StdArray, StdFunc, StdInt
import StdSystem, StdFile, StdMisc
import UtilStrictLists, PmPath
import EdMonad
import PmCompilerOptions
import PmFiles
import colourclip
import UtilOptions
import UtilNewlinesFile

PrefsFileName :== "IDEPrefs"

:: ErrPrefs =
	{ err_pos		:: !Vector2
	, err_siz		:: !Size
	, err_fname		:: !String
	, err_fsize		:: !Int
	, err_forc		:: !Colour
	, err_bacc		:: !Colour
	, err_err		:: !Bool
	, err_wrn		:: !Bool
	, err_inf		:: !Bool
	}

:: SrcPrefs =
	{ src_pos		:: !Vector2
	, src_siz		:: !Size
	, src_fname		:: !String
	, src_fsize		:: !Int
	, src_forc		:: !Colour
	, src_bacc		:: !Colour
	}	

:: TypPrefs =
	{ typewinfont	:: !FontDef
	, typewinpos	:: !Vector2
	, typewinsiz	:: !Size
	, typewinsync	:: !SyntaxColours
	}

:: ConPrefs =
	{ conswinfont	:: !FontDef
	, conswinpos	:: !Vector2
	, conswinsiz	:: !Size
	, conswinsync	:: !SyntaxColours
	}

:: PrjPrefs =
	{ proj_pos		:: !Vector2
	, proj_siz		:: !Size
	, proj_topc		:: !Colour
	, proj_forc		:: !Colour
	, proj_bacc		:: !Colour
	, proj_font		:: !FontDef
	, proj_shft		:: !Bool		// True: open dcl default; False: open icl default;
	}

:: Prefs =
	{ pmp_pth		:: !List Pathname
	, pmp_lnk		:: !List Pathname
	, pmp_obj		:: !List Pathname
	, typ_prefs		:: !TypPrefs
	, con_prefs		:: !ConPrefs
	, err_prefs		:: !ErrPrefs
	, src_prefs		:: !SrcPrefs
	, prj_prefs		:: !PrjPrefs

	, edwinfont		:: !FontDef
	// FIXME use a record for these options
	, edwintabs		:: !(Int,Bool,Bool,Bool,Bool)	// tabsize, autotab, showtabs, showlinenos, showsyncol
	, edwinmargin	:: !Int							// right margin (in #characters), 0: no margin

	, compopts		:: !CompilerOptions
	, cgenopts		:: !CodeGenOptions
	, linkopts		:: !LinkOptions
	, applopts		:: !ApplicationOptions
//	, pmanopts		:: !ProjectOptions
	, syncols		:: !SyntaxColours				// default syntax colours
	, defcols		:: !SyntaxColours				// .dcl syntax colours
	, impcols		:: !SyntaxColours				// .icl syntax colours
	, proj_hist		:: !List Pathname				// project history
	, file_hist		:: !List Pathname				// file history
	, switch_close	:: !Bool						// close associated editor windows on project switch
	, show_toolbar	:: !Bool						// enable toolbar
//	, enable_prover	:: !Bool						// enable theorem prover
	, be_verbose	:: !Bool						// give extended diagnostics
	, altgr_workaround :: !Bool						// temp fix to workaround french azerty keyboard menu shortcuts...
	, newline_handling	:: !NewlinePrefs
	
	, reg_prefs		:: !RegPrefs
	}

:: RegPrefs =
	{ rp_flags		:: ![(String,String)]
	, tp_name		:: !String
	, tp_path		:: !String
	, hp_name		:: !String
	, hp_path		:: !String
	, pr_name		:: !String
	, pr_path		:: !String
	, ve_name		:: !String
	, ve_path		:: !String
	}

:: NewlinePrefs
	= LeaveAlone NewlineConvention	// leave alone existing files, use given convention for new files
	| AlwaysUse NewlineConvention	// always save with given newline convention

emptyPrefs =
	{ pmp_pth		= Nil
	, pmp_lnk		= Nil
	, pmp_obj		= Nil
	, typ_prefs		= emptyTypPrefs
	, con_prefs		= emptyConPrefs
	, err_prefs		= emptyErrPrefs
	, src_prefs		= emptySrcPrefs
	, prj_prefs		= emptyPrjPrefs
	, edwinfont		= NonProportionalFontDef
	, edwintabs		= (4,True,False,False,True)
	, edwinmargin	= 0
	, compopts		= DefaultCompilerOptions
	, cgenopts		= DefCodeGenOptions
	, linkopts		= DefaultLinkOptions
	, applopts		= DefApplicationOptions
	, syncols		= scSyntaxColours
	, defcols		= dmSyntaxColours
	, impcols		= imSyntaxColours
	, proj_hist		= Nil
	, file_hist		= Nil
	, switch_close	= False
	, show_toolbar	= True
//	, enable_prover	= False
	, be_verbose	= False
	, altgr_workaround = False
	, newline_handling = LeaveAlone NewlineConventionNone
	, reg_prefs		= emptyRegPrefs
	}

emptyRegPrefs =
	{ rp_flags		= []
	, tp_name		= "ShowTimeProfile.exe"
	, tp_path		= "{Application}\\Tools\\Time Profiler 2.0\\"
	, hp_name		= "ShowHeapProfile.exe"
	, hp_path		= "{Application}\\Tools\\Heap Profiler 2.0\\"
	, pr_name		= "Sparkle.exe"
	, pr_path		= "{Application}\\Tools\\Sparkle 0.0.3a\\"
	, ve_name		= "VisualEditor.exe"
	, ve_path		= "{Application}\\Tools\\Visual Editor\\"
	}
	
emptyTypPrefs =
	{ typewinfont	= NonProportionalFontDef
	, typewinpos	= {vx=30,vy=30}
	, typewinsiz	= {w=800,h=300}
	, typewinsync	= twSyntaxColours
	}
emptyConPrefs =
	{ conswinfont	= NonProportionalFontDef
	, conswinpos	= {vx=30,vy=30}
	, conswinsiz	= {w=800,h=300}
	, conswinsync	= cwSyntaxColours
	}
emptyErrPrefs =
	{ err_pos		= {vx=300,vy=300}
	, err_siz		= {w=500,h=300}
	, err_fname		= SansSerifFontDef.fName
	, err_fsize		= SansSerifFontDef.fSize
	, err_forc		= Black
	, err_bacc		= ewBack
	, err_err		= True
	, err_wrn		= True
	, err_inf		= True
	}

emptySrcPrefs =
	{ src_pos		= {vx=250,vy=250}
	, src_siz		= {w=300,h=200}
	, src_fname		= SansSerifFontDef.fName
	, src_fsize		= SansSerifFontDef.fSize
	, src_forc		= Black
	, src_bacc		= swBack
	}

emptyPrjPrefs =
	{ proj_pos		= {vx = 0, vy = 0}
	, proj_siz		= {w=200,h=400}
	, proj_topc		= pwTopc
	, proj_forc		= pwFore
	, proj_bacc		= pwBack
	, proj_font		= SansSerifFontDef
	, proj_shft		= True
	}

//--

twSyntaxColours :: SyntaxColours
twSyntaxColours =
	{ textColour		= Black
	, tabColour			= twTabs
	, backgroundColour	= twBack
	, marginColour		= darkerColour twBack
	, commentColour		= twComm
	, stringColour		= twStri
	, charColour		= Magenta
	, keywordColour		= twChar
	, typedefColour		= Black
	, typedeclColour	= Black
	}

cwSyntaxColours :: SyntaxColours
cwSyntaxColours =
	{ textColour		= Black
	, tabColour			= twTabs
	, backgroundColour	= cwBack
	, marginColour		= darkerColour cwBack
	, commentColour		= cwComm
	, stringColour		= cwStri
	, charColour		= Magenta
	, keywordColour		= twChar
	, typedefColour		= Black
	, typedeclColour	= Black
	}

ewSyntaxColours :: SyntaxColours
ewSyntaxColours =
	{ textColour		= Black
	, tabColour			= twTabs
	, backgroundColour	= twBack
	, marginColour		= darkerColour twBack
	, commentColour		= twComm
	, stringColour		= twStri
	, charColour		= Magenta
	, keywordColour		= twChar
	, typedefColour		= Black
	, typedeclColour	= Black
	}

scSyntaxColours :: SyntaxColours
scSyntaxColours =
	{ textColour		= Black
	, tabColour			= scTabs
	, backgroundColour	= scBack
	, marginColour		= darkerColour scBack
	, commentColour		= scComm
	, stringColour		= scStri
	, charColour		= scChar
	, keywordColour		= scKeyw
	, typedefColour		= Black
	, typedeclColour	= Black
	}

dmSyntaxColours :: SyntaxColours
dmSyntaxColours =
	{ textColour		= Black
	, tabColour			= scTabs
	, backgroundColour	= dmBack
	, marginColour		= darkerColour dmBack
	, commentColour		= scComm
	, stringColour		= scStri
	, charColour		= scChar
	, keywordColour		= scKeyw
	, typedefColour		= dmType
	, typedeclColour	= dmDecl
	}

imSyntaxColours :: SyntaxColours
imSyntaxColours =
	{ textColour		= Black
	, tabColour			= scTabs
	, backgroundColour	= imBack
	, marginColour		= darkerColour imBack
	, commentColour		= scComm
	, stringColour		= scStri
	, charColour		= scChar
	, keywordColour		= scKeyw
	, typedefColour		= imType
	, typedeclColour	= imDecl
	}

twBack	= RGB {r = 215, g = 255, b = 255}
twTabs	= RGB {r = 215, g =   0, b =   0}
twComm	= RGB {r =   0, g =   0, b = 215}
twStri	= RGB {r =   0, g = 175, b =   0}
twChar	= RGB {r = 185, g =   0, b = 255}
ewBack	= RGB {r = 255, g = 215, b = 255}
swBack	= RGB {r = 143, g = 219, b = 255}
pwTopc	= RGB {r = 215, g = 255, b = 229}
pwFore	= RGB {r = 109, g =   0, b =   0}
pwBack	= RGB {r = 210, g = 210, b = 179}
scBack	= RGB {r = 215, g = 255, b = 215}
scTabs	= RGB {r = 195, g =   0, b =   0}
scComm	= RGB {r =   0, g =   0, b = 195}
scStri	= RGB {r =   0, g = 155, b =   0}
scChar	= RGB {r = 155, g =   0, b = 155}
scKeyw	= RGB {r = 127, g =   0, b = 127}
dmBack	= RGB {r = 255, g = 215, b = 215}
imBack	= RGB {r = 255, g = 255, b = 215}
cwBack	= RGB {r = 244, g = 215, b = 244}
cwComm	= RGB {r =   0, g =   0, b = 215}
cwStri	= RGB {r =   0, g = 215, b =   0}
dmType	= RGB {r = 195, g =   0, b =   0}
imType	= RGB {r = 195, g =   0, b =   0}
dmDecl	= RGB {r = 195, g =   0, b =   0}
imDecl	= RGB {r = 195, g =   0, b =   0}

darkerColour :: Colour -> Colour
darkerColour (RGB rgb=:{r, g, b})
	=	RGB {rgb & r = darker r, g = darker g, b = darker b}
	where
		darker c
			=	c * 95 / 100
darkerColour colour
	=	colour
//--

openPrefs :: !String !*a -> *(!Prefs,!*a) | FileEnv a
openPrefs prefspath env
	# ((prefs,ok,err),env)	= accFiles (ReadPrefsFile prefspath) env
	| not ok
//		= abort ("Unable to read preferences: \n" +++ err)
		# env				=  savePrefs prefspath emptyPrefs env
		= (emptyPrefs,env)
	= (prefs,env)

savePrefs :: !String Prefs *a -> *a | FileEnv a
savePrefs prefspath prefs env
//	# prefspath		= applicationpath PrefsFileName
	# (ok,env)		= accFiles (SavePrefsFile prefspath prefs) env
	| not ok
//		= trace_n "Unable to write preferences" env
		= env
	= env

//-- OptionsFile Prefs

PrefsFileVersion :== "1.0"

SavePrefsFile	:: !{#Char} !Prefs !*Files -> (!Bool, !*Files);
SavePrefsFile	prefsPath prefs files
	#! (opened, file, files)	=	fopen prefsPath FWriteText files
	| not opened
		=	(False, files)
	#! options					=	WriteTable prefs
	#! file						=	WriteOptionsFile PrefsFileVersion options file
	=	fclose file files
	
ReadPrefsFile	:: !{#Char} !*Files -> ((!Prefs, !Bool, !{#Char}),!*Files)
ReadPrefsFile prefsPath ps
	#	(opened, file, ps)		= fopen prefsPath FReadData ps
	| not opened
		= ((emptyPrefs,False,"The file \"" +++  prefsPath +++ "\" could not be opened."),ps)
	#	(version, file)			= ReadVersion file
	| version <> PrefsFileVersion
		#	(_, ps)				= fclose file ps
		= ((emptyPrefs,False,"The file \"" +++  prefsPath +++ "\" has the wrong version."+++version+++"<<<"),ps)
	#!	(options, file)			= ReadOptionsFile file
		prefs					= ReadTable options
		(closed, ps)			= fclose file ps
	| not closed
		// generate warning?
		=	((prefs, True,"The file \"" +++ prefsPath +++ "\" clould not be closed."), ps)
	=	((prefs, True,""), ps)
	
WriteTable :: !Prefs -> [Option]
WriteTable prefs
	= PutOptions (PrefsOptionsTable) prefs

ReadTable :: .[Option] -> Prefs
ReadTable options
	# prefs = GetOptions PrefsOptionsTable options emptyPrefs
	= prefs

PathOption = SimpleWithStringConversionOption convert_path_separators "Path" id const

PrefsOptionsTable :: OptionsTable Prefs
PrefsOptionsTable =
	{ ListOption "PmpPaths" (PathOption) "" (\a->a.pmp_pth) (\v a->{a & pmp_pth=v})
	, ListOption "PmpLinks" (PathOption) "" (\a->a.pmp_lnk) (\v a->{a & pmp_lnk=v})
	, ListOption "PmpObjcs" (PathOption) "" (\a->a.pmp_obj) (\v a->{a & pmp_obj=v})
	, GroupedOption "TWFnt" FontOptionsTable (\a->a.typ_prefs.typewinfont) (\v a->{a & typ_prefs.typewinfont=v})
	, GroupedOption "TWPos" VectOptionsTable (\a->a.typ_prefs.typewinpos) (\v a->{a & typ_prefs.typewinpos=v})
	, GroupedOption "TWSiz" SizeOptionsTable (\a->a.typ_prefs.typewinsiz) (\v a->{a & typ_prefs.typewinsiz=v})
	, GroupedOption "TWSync" SyncOptionsTable (\a->a.typ_prefs.typewinsync) (\v a->{a & typ_prefs.typewinsync=v})
	, GroupedOption "CWFnt" FontOptionsTable (\a->a.con_prefs.conswinfont) (\v a->{a & con_prefs.conswinfont=v})
	, GroupedOption "CWPos" VectOptionsTable (\a->a.con_prefs.conswinpos) (\v a->{a & con_prefs.conswinpos=v})
	, GroupedOption "CWSiz" SizeOptionsTable (\a->a.con_prefs.conswinsiz) (\v a->{a & con_prefs.conswinsiz=v})
	, GroupedOption "CWSync" SyncOptionsTable (\a->a.con_prefs.conswinsync) (\v a->{a & con_prefs.conswinsync=v})
	, GroupedOption "EWPrefs" ErrPrefsOptionsTable (\a->a.err_prefs) (\v a->{a & err_prefs=v})
	, GroupedOption "SWPrefs" SrcPrefsOptionsTable (\a->a.src_prefs) (\v a->{a & src_prefs=v})
	, GroupedOption "PWPos" VectOptionsTable (\a->a.prj_prefs.proj_pos) (\v a->{a & prj_prefs.proj_pos=v})
	, GroupedOption "PWSiz" SizeOptionsTable (\a->a.prj_prefs.proj_siz) (\v a->{a & prj_prefs.proj_siz=v})
	, SimpleOption "PWTop" (\a->a.prj_prefs.proj_topc) (\v a->{a & prj_prefs.proj_topc=v})
	, SimpleOption "PWFor" (\a->a.prj_prefs.proj_forc) (\v a->{a & prj_prefs.proj_forc=v})
	, SimpleOption "PWBak" (\a->a.prj_prefs.proj_bacc) (\v a->{a & prj_prefs.proj_bacc=v})
	, GroupedOption "PWFnt" FontOptionsTable (\a->a.prj_prefs.proj_font) (\v a->{a & prj_prefs.proj_font=v})
	, SimpleOption "PWDcl" (\a->if a.prj_prefs.proj_shft "1" "0") (\v a->{a & prj_prefs.proj_shft=(if (v=="1") True False)})
	, GroupedOption "EdFnt" FontOptionsTable (\a->a.edwinfont) (\v a->{a & edwinfont=v})
	, SimpleOption "EdTab" (\a->a.edwintabs) (\v a->{a & edwintabs=v})
	, SimpleOption "EdMargin" (\a->a.edwinmargin) (\v a->{a & edwinmargin=v})
	, GroupedOption "ComOp" CompilerOptionsTable (\a->a.compopts) (\v a->{a & compopts=v})
	, GroupedOption "GenOp" CodeGenOptionsTable (\a->a.cgenopts) (\v a->{a & cgenopts=v})
	, GroupedOption "LnkOp" LinkOptionsTable (\a->a.linkopts) (\v a->{a & linkopts=v})
	, GroupedOption "AppOp" ApplicationOptionsTable (\a->a.applopts) (\v a->{a & applopts=v})
	, GroupedOption "SynCl" SyncOptionsTable (\a->a.syncols) (\v a->{a & syncols=v})
	, GroupedOption "DefCl" SyncOptionsTable (\a->a.defcols) (\v a->{a & defcols=v})
	, GroupedOption "ImpCl" SyncOptionsTable (\a->a.impcols) (\v a->{a & impcols=v})
	, ListOption "ProjHist" (PathOption) "" (\a->a.proj_hist) (\v a->{a & proj_hist=v})
	, ListOption "FileHist" (PathOption) "" (\a->a.file_hist) (\v a->{a & file_hist=v})
	, SimpleOption "SwitchClose" (\a->if a.switch_close "1" "0") (\v a->{a & switch_close=(if (v=="1") True False)})
	, SimpleOption "ShowToolbar" (\a->if a.show_toolbar "1" "0") (\v a->{a & show_toolbar=(if (v=="1") True False)})
//	, SimpleOption "ProveTheorems" (\a->if a.enable_prover "1" "0") (\v a->{a & enable_prover=(if (v=="1") True False)})
	, SimpleOption "BeVerbose" (\a->if a.be_verbose "1" "0") (\v a->{a & be_verbose=(if (v=="1") True False)})
	, SimpleOption "AltGrWorkaround" (\a->if a.altgr_workaround "1" "0") (\v a->{a & altgr_workaround=(if (v=="1") True False)})
	, SimpleOption "NewlineHandling" writeNLH readNLH
	, GroupedOption "RegPrefs" RegPrefsOptionsTable (\a->a.reg_prefs) (\v a->{a & reg_prefs = v})
	}
where
	writeNLH {newline_handling}
		= case newline_handling of
			(LeaveAlone NewlineConventionNone)	-> "L0"
			(LeaveAlone NewlineConventionMac)	-> "L1"
			(LeaveAlone NewlineConventionUnix)	-> "L2"
			(LeaveAlone NewlineConventionDos)	-> "L3"
			(AlwaysUse NewlineConventionNone)	-> "A0"
			(AlwaysUse NewlineConventionMac)	-> "A1"
			(AlwaysUse NewlineConventionUnix)	-> "A2"
			(AlwaysUse NewlineConventionDos)	-> "A3"
	readNLH v a
		= case v of
			"L0"	-> {a & newline_handling = LeaveAlone NewlineConventionNone}
			"L1"	-> {a & newline_handling = LeaveAlone NewlineConventionMac}
			"L2"	-> {a & newline_handling = LeaveAlone NewlineConventionUnix}
			"L3"	-> {a & newline_handling = LeaveAlone NewlineConventionDos}
			"A0"	-> {a & newline_handling = AlwaysUse NewlineConventionNone}
			"A1"	-> {a & newline_handling = AlwaysUse NewlineConventionMac}
			"A2"	-> {a & newline_handling = AlwaysUse NewlineConventionUnix}
			"A3"	-> {a & newline_handling = AlwaysUse NewlineConventionDos}
			_		-> {a & newline_handling = LeaveAlone NewlineConventionNone}

RegPrefsOptionsTable :: OptionsTable RegPrefs
RegPrefsOptionsTable =
	{ ListOption "ClideFlags" FlagOption ("","") (\a->ListToStrictList a.rp_flags) (\v a->{a & rp_flags=StrictListToList v})
	, SimpleOption "TimepName" (\a->a.tp_name) (\v a->{a & tp_name=v})
	, SimpleOption "TimepPath" (\a->a.tp_path) (\v a->{a & tp_path=v})
	, SimpleOption "HeappName" (\a->a.hp_name) (\v a->{a & hp_name=v})
	, SimpleOption "HeappPath" (\a->a.hp_path) (\v a->{a & hp_path=v})
	, SimpleOption "ProofName" (\a->a.pr_name) (\v a->{a & pr_name=v})
	, SimpleOption "ProofPath" (\a->a.pr_path) (\v a->{a & pr_path=v})
	, SimpleOption "VisedName" (\a->a.ve_name) (\v a->{a & ve_name=v})
	, SimpleOption "VisedPath" (\a->a.ve_path) (\v a->{a & ve_path=v})
	}

FlagOption = GroupedOption "Flags" FlagsOptionsTable id const

FlagsOptionsTable :: OptionsTable (String,String)
FlagsOptionsTable =
	{ SimpleOption "fName" (\(a,_)->a) (\v (a,b)->(v,b))
	, SimpleOption "fPath" (\(_,a)->a) (\v (a,b)->(a,v))
	}

ErrPrefsOptionsTable :: OptionsTable ErrPrefs
ErrPrefsOptionsTable =
	{ GroupedOption "EWPos" VectOptionsTable (\a->a.err_pos) (\v a->{a & err_pos=v})
	, GroupedOption "EWSiz" SizeOptionsTable (\a->a.err_siz) (\v a->{a & err_siz=v})
	, SimpleOption "EWFNm" (\a->a.err_fname) (\v a->{a & err_fname=v})
	, SimpleOption "EWFSz" (\a->a.err_fsize) (\v a->{a & err_fsize=v})
	, SimpleOption "EWFor" (\a->a.err_forc) (\v a->{a & err_forc=v})
	, SimpleOption "EWBak" (\a->a.err_bacc) (\v a->{a & err_bacc=v})
	, SimpleOption "EWErr" (\a->if a.err_err "1" "0") (\v a->{a & err_err=(if (v=="1") True False)})
	, SimpleOption "EWWrn" (\a->if a.err_wrn "1" "0") (\v a->{a & err_wrn=(if (v=="1") True False)})
	, SimpleOption "EWInf" (\a->if a.err_inf "1" "0") (\v a->{a & err_inf=(if (v=="1") True False)})
	}

SrcPrefsOptionsTable :: OptionsTable SrcPrefs
SrcPrefsOptionsTable =
	{ GroupedOption "EWPos" VectOptionsTable (\a->a.src_pos) (\v a->{a & src_pos=v})
	, GroupedOption "EWSiz" SizeOptionsTable (\a->a.src_siz) (\v a->{a & src_siz=v})
	, SimpleOption "EWFNm" (\a->a.src_fname) (\v a->{a & src_fname=v})
	, SimpleOption "EWFSz" (\a->a.src_fsize) (\v a->{a & src_fsize=v})
	, SimpleOption "EWFor" (\a->a.src_forc) (\v a->{a & src_forc=v})
	, SimpleOption "EWBak" (\a->a.src_bacc) (\v a->{a & src_bacc=v})
	}

instance toString (Int,Bool,Bool,Bool,Bool)
where
	toString (i,a,b,c,d) = booltriple a b c d +++ toString i
	where
		booltriple True True True True = "0"
		booltriple True True True False = "1"
		booltriple True True False True = "2"
		booltriple True True False False = "3"
		booltriple True False True True = "4"
		booltriple True False True False = "5"
		booltriple True False False True = "6"
		booltriple True False False False = "7"
		booltriple False True True True = "8"
		booltriple False True True False = "9"
		booltriple False True False True = "A"
		booltriple False True False False = "B"
		booltriple False False True True = "C"
		booltriple False False True False = "D"
		booltriple False False False True = "E"
		booltriple False False False False = "F"

instance fromString (Int,Bool,Bool,Bool,Bool)
where
	fromString s
		| size s == 0 = (0,False,False,False,False)
		# (a,b,c,d) = booltriple s.[0]
		# i = toInt (s%(1,size s - 1))
		= (i,a,b,c,d)
	where
		booltriple '0' = (True,True,True,True)
		booltriple '1' = (True,True,True,False)
		booltriple '2' = (True,True,False,True)
		booltriple '3' = (True,True,False,False)
		booltriple '4' = (True,False,True,True)
		booltriple '5' = (True,False,True,False)
		booltriple '6' = (True,False,False,True)
		booltriple '7' = (True,False,False,False)
		booltriple '8' = (False,True,True,True)
		booltriple '9' = (False,True,True,False)
		booltriple 'A' = (False,True,False,True)
		booltriple 'B' = (False,True,False,False)
		booltriple 'C' = (False,False,True,True)
		booltriple 'D' = (False,False,True,False)
		booltriple 'E' = (False,False,False,True)
		booltriple  _  = (False,False,False,False)

instance fromString Int where fromString s = toInt s

FontOptionsTable :: OptionsTable FontDef
FontOptionsTable =
	{ SimpleOption "Name" (\a->a.fName) (\v a->{a & fName=v})
	, ListOption "Styles" StyleOption "" (\a->ListToStrictList a.fStyles) (\v a->{a & fStyles=StrictListToList v})
	, SimpleOption "Size" (\a->a.fSize) (\v a->{a & fSize=v})
	}
StyleOption =SimpleOption "Style" id const

VectOptionsTable :: OptionsTable Vector2
VectOptionsTable =
	{ SimpleOption "VX" (\a->a.vx) (\v a->{a & vx=v})
	, SimpleOption "VY" (\a->a.vy) (\v a->{a & vy=v})
	}

SizeOptionsTable :: OptionsTable Size
SizeOptionsTable =
	{ SimpleOption "W" (\a->a.w) (\v a->{a & w=v})
	, SimpleOption "H" (\a->a.Size.h) (\v a->{Size | a & h=v})
	}

SyncOptionsTable :: OptionsTable SyntaxColours
SyncOptionsTable =
	{ SimpleOption "col_text" (\a->a.textColour) (\v a->{a & textColour=v})
	, SimpleOption "col_back" (\a->a.backgroundColour) (\v a->{a & backgroundColour=v})
	, SimpleOption "col_margin" (\a->a.marginColour) (\v a->{a & marginColour=v})
	, SimpleOption "col_tabs" (\a->a.tabColour) (\v a->{a & tabColour=v})
	, SimpleOption "col_comm" (\a->a.commentColour) (\v a->{a & commentColour=v})
	, SimpleOption "col_stri" (\a->a.stringColour) (\v a->{a & stringColour=v})
	, SimpleOption "col_char" (\a->a.charColour) (\v a->{a & charColour=v})
	, SimpleOption "col_keyw" (\a->a.keywordColour) (\v a->{a & keywordColour=v})
	, SimpleOption "col_type" (\a->a.typedefColour) (\v a->{a & typedefColour=v})
	, SimpleOption "col_decl" (\a->a.typedeclColour) (\v a->{a & typedeclColour=v})
	}

