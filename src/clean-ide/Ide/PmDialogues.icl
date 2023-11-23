implementation module PmDialogues

import StdArray, StdFunc, StdMisc, StdTuple
import StdFileSelect,StdPStClass,StdWindow
import PmTypes, PmProject, PmPath, UtilStrictLists
import tabcontrol, ExtListBox, ioutil, IdeState
import ExtNotice, UtilObjectIO
import Platform, morecontrols
from projwin import pm_update_project_window

:: PO_LS =
	{ ao	:: !ApplicationOptions
	, cgo	:: !CodeGenOptions
	, paths	:: !List String
	, lo	:: !LinkOptions
	, xp	:: !String						// exepath
	, bytecodepath	:: !String
	, sl	:: !StaticLibInfo
	, post_link :: !Maybe String
	}

projectOptions :: !(PSt General) -> PSt General
projectOptions ps
	= projectDialog True ps

projectDefaults :: !(PSt General) -> PSt General
projectDefaults ps
	= projectDialog False ps

projectDialog :: !Bool !(PSt General) -> PSt General
projectDialog actualProject ps`
	# ((err,ret),ps)		= (if actualProject actualOpenOptionsDialog actualOpenDefaultsDialog) ps
	| NoError == err && isJust ret
		# ret				= fromJust ret
		// need to differentiate here between options and defaults...
		| actualProject
			// actualProject
			# prj			= PR_SetApplicationOptions ret.ao project
			# prj			= PR_SetCodeGenOptions ret.cgo prj
			# prj			= PR_SetLinkOptions prj ret.lo
			#(dp,ps)		= getCurrentPaths ps
			# prj			= PR_SetPaths False dp ret.paths prj
			# (appPath,ps)	= getStup ps
			# prjPath = PR_GetRootDir prj
			# prj			= PR_SetExecPath ret.xp prj
			# prj			= PR_SetByteCodePath ret.bytecodepath prj
			# prj			= PR_SetStaticLibsInfo ret.sl prj
			# (xxId,ps)		= getPWX ps
			# ps			= setFlexTexts [(xxId,ret.xp)] ps
			# prj			= PR_SetPostlink ret.post_link prj
			= setProject prj ps
		// prefs
		# (prfs,ps)			= getPrefs ps
		# prfs				= {prfs & cgenopts = ret.cgo}
		# prfs				= {prfs & linkopts = ret.lo}
		# prfs				= {prfs & applopts = ret.ao}
		= setPrefs prfs ps
	= ps
where
	actualOpenOptionsDialog :: !(PSt General) ->  (!(!ErrorReport,!Maybe PO_LS),!PSt General)
	actualOpenOptionsDialog ps = openModalDialog inils
									(Dialog "Project Options"
									(panesOptions :+: buttons)
									[WindowClose cancelfun
									,WindowOk okId
									,WindowCancel cancelId
									,WindowId dlogId
									]) ps
	actualOpenDefaultsDialog :: !(PSt General) ->  (!(!ErrorReport,!Maybe PO_LS),!PSt General)
	actualOpenDefaultsDialog ps = openModalDialog inils
									(Dialog "Project Defaults"
									(panesDefaults :+: buttons)
									[WindowClose cancelfun
									,WindowOk okId
									,WindowCancel cancelId
									,WindowId dlogId
									]) ps
	// actualProject
	(project,ps0)	= getProject ps`
	([okId,cancelId,dlogId,hsId,ssId,emId,hmId,ihId,mhId,c1id,r1id,c2id,c3id,c4id,xpId,bytecodepathId,rsrcsId,symbolsId,post_link_id:_],ps1)
					= openIds 19 ps0
	(lbpadId,ps2)	= openExtListBoxId ps1
	(lbobjId,ps3)	= openExtListBoxId ps2
	(lbdlibId,ps4)	= openExtListBoxId ps3
	(lbslibId,ps5)	= openExtListBoxId ps4
	(ap,ps6)		= getStup ps5
	pp = PR_GetRootDir project
	(prefs,ps)		= PlatformDependant
						(getPrefs ps6)	// Win
						(getPrefs ps9)	// Mac
// mac only...
	(fontNames`, ps8)
					= accPIO (accScreenPicture getFontNames) ps6		// filteren naar alleen fixed width fonts....
//	(fixed,ps9)		= seqList (map (\f->accPIO (accScreenPicture (lisFixedWidth f))) fontNames`) ps8
	(fixed,ps9)		= accPIO (accScreenPicture (seqList (map lisFixedWidth fontNames`))) ps8

	fontNames		= lfilter fixed fontNames`
	fontSizes		= [7, 8, 9, 10, 12, 14, 18, 24 ]
	inifn			= ao.fn
	inifs			= ao.fs
	fontfun name (ls,ps)
		# ls		= {ls & ao.fn = name}
		= (ls,ps)
	sizefun size (ls,ps)
		# ls		= {ls & ao.fs = size}
		= (ls,ps)
// ...mac only
 	ao				= if actualProject (PR_GetApplicationOptions project) prefs.applopts
	cgo				= if actualProject (PR_GetCodeGenOptions project) prefs.cgenopts
	lo				= if actualProject (PR_GetLinkOptions project) prefs.linkopts
	paths			= PR_GetPaths project
	sl				= PR_GetStaticLibsInfo project 
	root_path		= PR_GetRootModuleDir project
	(post_link,_)	= PR_GetPostlink project
	inils			= {ao=ao,cgo=cgo,paths=paths,lo=lo,xp=fulexepath,bytecodepath=fulbcpath,sl=sl,post_link=post_link}
	
	// generic...
	panesOptions = TabControl
							(	applicationPane
							:+: compilerPane
							:+: diagnosticsPane
							:+: pathsPane ap pp paths False 200 lbpadId c1id r1id root_path
							:+: linkerPane
							:+: objectsPane
							:+: slibsPane
							:+: dlibsPane
							:+: bytecodePane
							) (Columns 3) [ControlPos (Left,zero)]
	panesDefaults = TabControl
							(	applicationPane
							:+: compilerPane
							:+: diagnosticsPane
							:+: linkerPane
							) (Columns 2) [ControlPos (Left,zero)]
	buttons
		=	ButtonControl "OK"
			[ControlFunction okfun,ControlPos (Right,zero), ControlId okId]
		:+: ButtonControl "Cancel"
			[ControlFunction cancelfun, ControlPos (LeftOfPrev,zero), ControlId cancelId]

	okfun (ls,ps)
		#	(wdef,ps)	= accPIO (getWindow dlogId) ps
		| isNothing wdef = abort "Fatal error in Project Options Dialog"
		#	wdef		= fromJust wdef
			[(ok1,hs),(ok2,ss),(ok3,hm),(ok4,ih),(ok5,mh):_]	= getControlTexts [hsId,ssId,hmId,ihId,mhId] wdef
		| not (ok1 && ok2 && ok3 && ok4 && ok5)
			= abort "More fatal stuff in Project Options dialog"
		| (isNothing hs) || (isNothing ss) || (isNothing hm) || (isNothing ih) || (isNothing mh)
			= abort "Yet more fatal stuff in Project Options dialog"
		# ls = { ls	& ao =
				{ls.ao
				& hs								= MemSizeToInt (fromJust hs)
				, ss								= MemSizeToInt (fromJust ss)
//				, em								= MemSizeToInt (fromJust em)
				, heap_size_multiple				= StringToFixedPoint (fromJust hm)
				, initial_heap_size					= MemSizeToInt (fromJust ih)
				, memoryProfilingMinimumHeapSize	= MemSizeToInt (fromJust mh)
				}}
		# ls = PlatformDependant ls (macstuff ls wdef)
		= (ls, closeWindow dlogId ps)
	where
		macstuff ls wdef
			# (ok,em)= getControlText emId wdef
			| not ok || isNothing em = abort "Fatal mac specific"
			# ls = {ls & ao.em = MemSizeToInt (fromJust em)}
			= ls

	cancelfun (ls,ps) = (inils,closeWindow dlogId ps)

	fulexepath		= PR_GetExecPath project
	symexepath		= symPath ap pp fulexepath
	fulbcpath		= PR_GetByteCodePath project
	bytecodepath	= symPath ap pp fulbcpath

	setexe (ls,ps)
		# (prjPath,ps)	= getProjectFilePath ps
		# prjName		= RemoveSuffix (RemovePath prjPath)
		# prjPath = pp
		# (exename,ps)	= PlatformDependant
							(selectOutputFile` "Executable" "*.exe" "Set" ps)	// win
							(selectOutputFile "Executable" prjName ps)	// mac
		| isNothing exename
			= (ls,ps)
		# exename		= fromJust exename
		# (appPath,ps)	= getStup ps
		# exename		= symPath appPath prjPath exename
		# ls			= {ls & xp = exename}
		# ps			= appPIO (setControlText xpId ("Executable produced as: "+++exename)) ps
		= (ls,ps)

	setbytecodepath (ls,ps)
		# (prjPath,ps)	= getProjectFilePath ps
		# prjName		= RemoveSuffix (RemovePath prjPath)
		# prjPath = pp
		# (bcname,ps)	= PlatformDependant
							(selectOutputFile` "Bytecode" "*.bc" "Set" ps)	// win
							(selectOutputFile "Bytecode" prjName ps)	// mac
		| isNothing bcname
			= (ls,ps)
		# bcname		= fromJust bcname
		# (appPath,ps)	= getStup ps
		# bcname		= symPath appPath prjPath bcname
		# ls			= {ls & bytecodepath = bcname}
		# ps			= appPIO (setControlText bytecodepathId ("Bytecode produced as: "+++bcname)) ps
		= (ls,ps)

	applicationPane = Pane "Application"
		// heap size
		(	TextControl "Application Options" []
		:+:	EditControl (IntToMemSize ao.hs) (PixelWidth 100) 1
			[ ControlPos (Left,zero)
			, ControlId hsId
			, ControlActivate (noLS (appPIO (setEditControlSelection hsId 1 0)))
			]
		:+: TextControl "Maximum Heap Size" []
		// stack size
		:+: EditControl (IntToMemSize ao.ss) (PixelWidth 100) 1
			[ ControlPos (Left,zero)
			, ControlId ssId
			, ControlActivate (noLS (appPIO (setEditControlSelection ssId 1 0)))
			]
		:+: TextControl "Stack Size" []
		:+: PlatformDependant	// extra memory (want only on mac...)
			(NilLS)			// win
			(				// mac
				EditControl (IntToMemSize ao.em) (PixelWidth 100) 1
					[ ControlPos (Left,zero)
					, ControlId emId
					, ControlActivate (noLS (appPIO (setEditControlSelection emId 1 0)))
					]
			:+: TextControl "Extra Memory" []
			)
		// next heap size factor
		:+: EditControl (FixedPointToString ao.heap_size_multiple) (PixelWidth 100) 1
			[ ControlPos (Left,zero)
			, ControlId hmId
			, ControlActivate (noLS (appPIO (setEditControlSelection hmId 1 0)))
			]
		:+: TextControl "Next Heap Size Factor" []
		// initial heap size
		:+: EditControl (IntToMemSize ao.initial_heap_size) (PixelWidth 100) 1
			[ ControlPos (Left,zero)
			, ControlId ihId
			, ControlActivate (noLS (appPIO (setEditControlSelection ihId 1 0)))
			]
		:+: TextControl "Initial Heap Size" []
		// marking collector
		:+: CheckControl
			[	( "Dynamic linker"
				, Nothing
				, if (lo.method == LM_Static) NoMark Mark
				, noPS (\l->{l & lo = {l.lo & method = if (l.lo.method == LM_Static) LM_Dynamic LM_Static}})
				)
			,	( "Use Marking Garbage Collector"	
				, Nothing
				, toMark ao.marking_collection
				, noPS (\l->{l & ao = {l.ao & marking_collection = not l.ao.marking_collection}})
				)
			,	( "Disable RTS command line arguments"	
				, Nothing
				, toMark ao.disable_rts_flags
				, noPS (\l->{l & ao = {l.ao & disable_rts_flags = not l.ao.disable_rts_flags}})
				)				
			]
			(Columns 1)
			[ ControlPos (Left,zero)
			]
		// console type
		:+: TextControl "Console"
			[ ControlPos (Left,OffsetVector {zero & vy = 10})
			]
		:+: RadioControl
			[ ("Basic Values Only"	,Nothing,noPS (\l->{l & ao = {l.ao & o = BasicValuesOnly}}))
			, ("Show Constructors"	,Nothing,noPS (\l->{l & ao = {l.ao & o = ShowConstructors}}))
			, ("No Return Type"		,Nothing,noPS (\l->{l & ao = {l.ao & o = NoReturnType}}))
			, ("No Console"			,Nothing,noPS (\l->{l & ao = {l.ao & o = NoConsole}}))
			]
			(Columns 1)
			(case ao.o of
				BasicValuesOnly			-> 1
				ShowConstructors		-> 2
				NoReturnType			-> 3
				NoConsole				-> 4
			)
			[ ControlPos (Left,zero)
			]
		:+:	CheckControl
			[ ("Run from console", Nothing, toMark ao.run_from_console, noPS (\l->{l & ao = {l.ao & run_from_console = not l.ao.run_from_console}}))
			]
			(Columns 1)
			[ControlPos (Left,zero)]
		:+:	PlatformDependant
			NilLS
			(FontNameSizeControl inifn inifs fontNames fontSizes fontfun sizefun [])
		// .exe name and location
		:+: TextControl ("Executable produced as: "+++symexepath) [ControlId xpId,ControlPos (Left,zero):if actualProject [] [ControlHide]]
		:+: ButtonControl "Set executable..." [ControlFunction setexe,ControlPos (Left,zero):if actualProject [] [ControlHide]]
		)
	compilerPane = Pane "Compiler"
		(	TextControl "Profiling Options" []
		:+:	RadioControl
			[ ("Time Profile, Call Graph, and Stack Trace",Nothing,noPS (\l->{l & ao = {l.ao & profiling = True, callgraphProfiling = True, stack_traces = False}}))
			, ("Time Profile and Stack Trace",Nothing,noPS (\l->{l & ao = {l.ao & profiling = True, callgraphProfiling = False, stack_traces = False}}))
			, ("Stack Trace only",Nothing,noPS (\l->{l & ao = {l.ao & profiling = True, callgraphProfiling = False, stack_traces = True}}))
			, ("No Time Profiling",Nothing,noPS (\l->{l & ao = {l.ao & profiling = False, callgraphProfiling = False, stack_traces = False}}))
			]
			(Columns 1)
			(if ao.profiling (if ao.stack_traces 3 (if ao.callgraphProfiling 1 2)) 4)
			[ControlPos (Left,zero)]
		:+: CheckControl
			[("Heap Profile",Nothing,toMark ao.memoryProfiling, noPS (\l->{l & ao.memoryProfiling = not l.ao.memoryProfiling}))]
			(Columns 1) [ControlPos (Left,zero)]
		:+: EditControl (IntToMemSize ao.memoryProfilingMinimumHeapSize) (PixelWidth 100) 1
			[ ControlPos (Left,zero)
			, ControlId mhId
			, ControlActivate (noLS (appPIO (setEditControlSelection mhId 1 0)))
			]
		:+: TextControl "Minimum Profile Heap" []
		:+:	TextControl "Language Options" [ControlPos (Left,OffsetVector {vx=0,vy=10})]
		:+: CheckControl
			[("Dynamics",Nothing,toMark ao.dynamics,noPS (\l->{l & ao.dynamics = not l.ao.dynamics}))]
			(Columns 1) [ControlPos (Left,zero)]
		:+:	TextControl "Code Generation Options" [ControlPos (Left,OffsetVector {vx=0,vy=10})]
		:+: CheckControl
			[("Generic Fusion",Nothing,toMark ao.generic_fusion,noPS (\l->{l & ao.generic_fusion = not l.ao.generic_fusion}))]
			(Columns 1) [ControlPos (Left,zero)]
		:+: CheckControl
			[("Generate descriptors and export labels",Nothing,toMark ao.desc_exl,noPS (\l->{l & ao.desc_exl = not l.ao.desc_exl}))]
			(Columns 1) [ControlPos (Left,zero)]
		)
	diagnosticsPane = Pane "Diagnostics"
		(	TextControl "Diagnostics Options" []
		:+:	CheckControl
			[ ("Show Execution Time"		,Nothing, toMark ao.set,noPS (\l->{l & ao = {l.ao & set = not l.ao.set}}))
			, ("Show Garbage Collections"	,Nothing, toMark ao.sgc,noPS (\l->{l & ao = {l.ao & sgc = not l.ao.sgc}}))
			, ("Print Stack Size"			,Nothing, toMark ao.pss,noPS (\l->{l & ao = {l.ao & pss = not l.ao.pss}}))
			, ("Write stderr to file"		,Nothing, toMark ao.write_stderr_to_file,noPS (\l->{l & ao = {l.ao & write_stderr_to_file = not l.ao.write_stderr_to_file}}))
			, ("Check Stacks"				,Nothing, toMark cgo.cs, noPS (\l->{l & cgo = {l.cgo &  cs = not l.cgo.cs}}))
			, ("Check Indices"				,Nothing, toMark cgo.ci, noPS (\l->{l & cgo = {l.cgo &  ci = not l.cgo.ci}}))
			]
			(Columns 1)
			[ControlPos (Left,zero)]
		:+: TextControl "Stack tracing can be set in the profiling panel." [ControlPos (Left,zero)]
		)
	linkerPane = Pane "Linker"
		(	TextControl "Linker Options" []
/*
		:+:	TextControl "Link Method" [ControlPos (Left,zero)]
		:+:	RadioControl
			[("Static"	,Nothing,noPS (\l->{l & lo = {l.lo & method = LM_Static}}))
//			,("Eager"	,Nothing,noPS (\l->{l & lo = {l.lo & method = LM_Eager}}))
			,("Lazy"	,Nothing,noPS (\l->{l & lo = {l.lo & method = LM_Dynamic}}))
			]
			(Rows 1) inilinkmethod
			[ ControlPos (Left,zero)
			]
		:+: TextControl "Link Options"				
			[ ControlPos (Left,OffsetVector {zero & vy = 10})
			]
*/
		:+: CheckControl
			[ ("Generate Relocations"				,Nothing,toMark lo.generate_relocations,noPS (\ls -> {ls & lo = {ls.lo & generate_relocations = not ls.lo.generate_relocations}}))
			, ("Generate Symbol Table"				,Nothing,toMark lo.generate_symbol_table,noPS (\ls -> {ls & lo = {ls.lo & generate_symbol_table = not ls.lo.generate_symbol_table}}))
			, ("Generate Link Map"					,Nothing,toMark lo.generate_link_map,noPS (\ls -> {ls & lo = {ls.lo & generate_link_map = not ls.lo.generate_link_map}}))
			: PlatformDependant			
// winOnly
			[ ("Generate DLL"						,Nothing,toMark lo.generate_dll,noPS (\ls -> {ls & lo = {ls.lo & generate_dll = not ls.lo.generate_dll}}))
			, ("Use Standard Runtime Environment"	,Nothing,toMark ao.standard_rte,noPS (\l->{l & ao = {l.ao & standard_rte = not l.ao.standard_rte}}))
			, ("Include Resource Section"			,Nothing,toMark lo.link_resources,noPS (\ls->{ls & lo = {ls.lo & link_resources = not ls.lo.link_resources}}))
			]
// macOnly
//			[ ("Add 'carb' Resource"				,Nothing,toMark lo.add_carb_resource,noPS (\ls -> {ls & lo.add_carb_resource = not ls.lo.add_carb_resource}))
			[]
			] (Columns 1)
			[ ControlPos (Left,zero)
			]
		:+: PlatformDependant
// winOnly
		// .exe name and location
		(	TextControl ("Source of resource section: "+++lo.resource_source)
			[ControlId rsrcsId,ControlPos (Left,zero)]
		:+: ButtonControl "Set resource source..."
			[ControlFunction setrsrcs,ControlPos (Left,zero)]
		// .dll symbol source
		:+: TextControl ("Source of dll symbols: "+++lo.dll_export_list_name)
			[ControlId symbolsId,ControlPos (Left,zero)]
		:+: ButtonControl "Set dll symbol source..."
			[ControlFunction setsymbols,ControlPos (Left,zero)]
		:+: TextControl ("Postlink: "+++(case post_link of Just s -> s ; _ -> ""))
			[ControlId post_link_id,ControlPos (Left,zero)]
		:+: ButtonControl "Set postlink..."
			[ControlFunction set_post_link,ControlPos (Left,zero)]
		)
		NilLS
		)
	bytecodePane = Pane "Bytecode"
		(	TextControl "Bytecode options" []
		:+: CheckControl
			[("Generate bytecode",Nothing,toMark cgo.generate_bytecode,noPS (\l->{l & cgo.generate_bytecode = not l.cgo.generate_bytecode}))]
			(Columns 1) [ControlPos (Left,zero)]
		:+: CheckControl
			[("Use optimised ABC code",Nothing,toMark cgo.optimise_abc,noPS (\l->{l & cgo.optimise_abc = not l.cgo.optimise_abc}))]
			(Columns 1) [ControlPos (Left,zero)]
		:+: CheckControl
			[("Strip bytecode",Nothing,toMark lo.strip_bytecode,noPS (\l->{l & lo.strip_bytecode = not l.lo.strip_bytecode}))]
			(Columns 1) [ControlPos (Left,zero)]
		:+: CheckControl
			[("Keep bytecode symbols",Nothing,toMark lo.keep_bytecode_symbols,noPS (\l->{l & lo.keep_bytecode_symbols = not l.lo.keep_bytecode_symbols}))]
			(Columns 1) [ControlPos (Left,zero)]
		:+: CheckControl
			[("Prelink bytecode",Nothing,toMark lo.prelink_bytecode,noPS (\l->{l & lo.prelink_bytecode = not l.lo.prelink_bytecode}))]
			(Columns 1) [ControlPos (Left,zero)]
		:+: TextControl ("Generate main bytecode file as: "+++bytecodepath) [ControlId bytecodepathId,ControlPos (Left,zero):if actualProject [] [ControlHide]]
		:+: ButtonControl "Set bytecode file..." [ControlFunction setbytecodepath,ControlPos (Left,zero):if actualProject [] [ControlHide]]
		)

	setrsrcs (ls,ps)
		# (rsrcname,ps)	= PlatformDependant
							(selectOutputFile` "Resource source" "*.exe" "Set" ps)	// win
							(selectOutputFile "Resource source" "" ps)		// mac
		| isNothing rsrcname
			= (ls,ps)
		# rsrcname		= fromJust rsrcname
		# (rsrcname,ps) = make_sym_path rsrcname ps
		# ls			= {ls & lo.resource_source = rsrcname}
		# ps			= appPIO (setControlText rsrcsId ("Source of resource section: "+++rsrcname)) ps
		= (ls,ps)

	setsymbols (ls,ps)
		# (symbname,ps)	= PlatformDependant
							(selectOutputFile` "DLL symbol source" "*" "Set" ps)	// win
							(selectOutputFile "DLL symbol source" "" ps)	// mac
		| isNothing symbname
			= (ls,ps)
		# symbname		= fromJust symbname
		# (symbname,ps)	= make_sym_path symbname ps
		# ls			= {ls & lo.dll_export_list_name = symbname}
		# ps			= appPIO (setControlText symbolsId ("Source of dll symbols: "+++symbname)) ps
		= (ls,ps)

	set_post_link (ls,ps)
		# (post_link,ps)	= PlatformDependant
							(selectInputFile` ps)	// win
							(selectInputFile  ps)	// mac
		| isNothing post_link
			= ({ls & post_link = Nothing},ps)
		# post_link		= fromJust post_link
		# (post_link,ps) = make_sym_path post_link ps
		# ls			= {ls & post_link = Just post_link}
		# ps			= appPIO (setControlText post_link_id ("Postlink: "+++post_link)) ps
		= (ls,ps)

	make_sym_path name ps
		# (appPath,ps)	= getStup ps
		  prjPath = pp
		= (symPath appPath prjPath name,ps)
		
	objectsPane = Pane "Extra Objects"
		{addLS = inifull
		,addDef
		=	TextControl "Object Paths" []
		:+: LayoutControl
			(	ButtonControl "Append..."
				[ ControlFunction addObject
				, ControlWidth buttonWidth
				]
			:+: ButtonControl "Remove"
				[ ControlPos (Left,zero)
				, ControlFunction remObject
				, ControlWidth buttonWidth
				]
			) [ControlPos (Left,zero),ControlHMargin 0 0, ControlVMargin 0 0]
		:+: lbobj
		:+: CheckControl
			[ ("Show Full Names",Nothing,toMark inifull,showFullPaths)
			]
			(Columns 1)
			[ ControlPos (Left,zero)
			, ControlId c2id
			]
		}
	where
		lbobj = ExtListBoxControl
	  				(zip3(FullPaths inifull ap pp (StrictListToList lo.extraObjectModules))(repeat id)(repeat id))
	  				[] // initial selection
	  				(\_ ps -> ps)
	  				lbobjId
	  				[ControlViewSize {h=200,w=300}]
		buttonWidth = ContentWidth "Append..."
		inifull = False
		addObject ((full,tg),ps)
			#	(fs,ps)				= selectInputFile ps
			| isNothing fs = ((full,tg),ps)
			#	pathname			=  (fromJust fs)
				tg					= {tg & lo = {tg.lo & extraObjectModules = Append tg.lo.extraObjectModules pathname}}
				ps					= appendExtListBoxItems lbobjId (zip3[FullPath full ap pp pathname](repeat id)(repeat id)) ps
			= ((full,tg),ps)
		remObject ((full,tg),ps)
			#	((ok,sel),ps)		= getExtListBoxSelection lbobjId ps
			| not ok || isEmpty sel = ((full,tg),ps)
			#	(pathsel,indexsel)	= unzip sel
				tg					= {tg & lo = {tg.lo & extraObjectModules = RemoveMembers tg.lo.extraObjectModules (ListToStrictList [fulPath ap pp s \\ s <- pathsel])}}
				ps					= closeExtListBoxItems lbobjId indexsel ps
				ps					= setExtListBoxSelection lbobjId [] ps
			= ((full,tg),ps)
		showFullPaths ((full,tg=:{lo}),ps)
			#	full	= not full
				ps		= appPIO (setCheckControlMark full c2id) ps
				ps		= closeAllExtListBoxItems lbobjId ps
				ps		= appendExtListBoxItems lbobjId (zip3 (FullPaths full ap pp (StrictListToList lo.extraObjectModules))(repeat id)(repeat id)) ps
			= ((full,tg),ps)
	slibsPane = Pane "Static Libraries"
		{addLS = inifull
		,addDef = TextControl "Static Libraries" []
		:+: LayoutControl
			(	ButtonControl "Append..."
				[ ControlFunction addSlib
				, ControlWidth buttonWidth
				]
			:+: ButtonControl "Remove"
				[ ControlPos (Left,zero)
				, ControlFunction remSlib
				, ControlWidth buttonWidth
				]
			) [ControlPos (Left,zero),ControlHMargin 0 0, ControlVMargin 0 0]
		:+: lbobj
		:+: CheckControl
			[ ("Show Full Names",Nothing,toMark inifull,showFullPaths)
			]
			(Columns 1)
			[ ControlPos (Left,zero)
			, ControlId c3id
			]
		}
	where
		lbobj = ExtListBoxControl
	  				(zip3(FullPaths inifull ap pp (StrictListToList (SL_Libs sl)))(repeat id)(repeat id))
	  				[] // initial selection
	  				(\_ ps -> ps)
	  				lbslibId
	  				[ControlViewSize {h=200,w=300}]
		buttonWidth = ContentWidth "Append..."
		inifull = False
		addSlib ((full,tg),ps)
			#	(fs,ps)				= selectInputFile ps
			| isNothing fs = ((full,tg),ps)
			#	pathname			=  (fromJust fs)
				tg					= {tg & sl = SL_Add pathname tg.sl}
				ps					= appendExtListBoxItems lbslibId (zip3[FullPath full ap pp pathname](repeat id)(repeat id)) ps
			= ((full,tg),ps)
		remSlib ((full,tg),ps)
			#	((ok,sel),ps)		= getExtListBoxSelection lbslibId ps
			| not ok || isEmpty sel = ((full,tg),ps)
			#	(pathsel,indexsel)	= unzip sel
				tg					= {tg & sl = SL_Rem pathsel ap pp sl}
				ps					= closeExtListBoxItems lbslibId indexsel ps
				ps					= setExtListBoxSelection lbslibId [] ps
			= ((full,tg),ps)
		showFullPaths ((full,tg=:{sl}),ps)
			#	full	= not full
				ps		= appPIO (setCheckControlMark full c3id) ps
				ps		= closeAllExtListBoxItems lbslibId ps
				ps		= appendExtListBoxItems lbslibId (zip3 (FullPaths full ap pp (StrictListToList (SL_Libs sl)))(repeat id)(repeat id)) ps
			= ((full,tg),ps)
	dlibsPane = Pane "Dynamic Libraries"
		{addLS = inifull
		,addDef = TextControl "Dynamic Libraries" []
		:+: LayoutControl
			(	ButtonControl "Append..."
				[ ControlFunction addDlib
				, ControlWidth buttonWidth
				]
			:+: ButtonControl "Remove"
				[ ControlPos (Left,zero)
				, ControlFunction remDlib
				, ControlWidth buttonWidth
				]
			) [ControlPos (Left,zero),ControlHMargin 0 0, ControlVMargin 0 0]
		:+: lbobj
		:+: CheckControl
			[ ("Show Full Names",Nothing,toMark inifull,showFullPaths)
			]
			(Columns 1)
			[ ControlPos (Left,zero)
			, ControlId c4id
			]
		}
	where
		lbobj = ExtListBoxControl
	  				(zip3(FullPaths inifull ap pp (StrictListToList lo.libraries))(repeat id)(repeat id))
	  				[] // initial selection
	  				(\_ ps -> ps)
	  				lbdlibId
	  				[ControlViewSize {h=200,w=300}]
		buttonWidth = ContentWidth "Append..."
		inifull = False
		addDlib ((full,tg),ps)
			#	(fs,ps)				= selectInputFile ps
			| isNothing fs = ((full,tg),ps)
			#	pathname			=  (fromJust fs)
				tg					= {tg & lo = {tg.lo & libraries = Append tg.lo.libraries pathname}}
				ps					= appendExtListBoxItems lbdlibId (zip3[FullPath full ap pp pathname](repeat id)(repeat id)) ps
			= ((full,tg),ps)
		remDlib ((full,tg),ps)
			#	((ok,sel),ps)		= getExtListBoxSelection lbdlibId ps
			| not ok || isEmpty sel = ((full,tg),ps)
			#	(pathsel,indexsel)	= unzip sel
				tg					= {tg & lo = {tg.lo & libraries = RemoveMembers tg.lo.libraries (ListToStrictList [fulPath ap pp s \\ s <- pathsel])}}
				ps					= closeExtListBoxItems lbdlibId indexsel ps
				ps					= setExtListBoxSelection lbdlibId [] ps
			= ((full,tg),ps)
		showFullPaths ((full,tg=:{lo}),ps)
			#	full	= not full
				ps		= appPIO (setCheckControlMark full c4id) ps
				ps		= closeAllExtListBoxItems lbdlibId ps
				ps		= appendExtListBoxItems lbdlibId (zip3 (FullPaths full ap pp (StrictListToList lo.libraries))(repeat id)(repeat id)) ps
			= ((full,tg),ps)

pathsPane ap pp paths inifull height lbpadId c1id r1id root_path
  = Pane "Project Paths"
	{addLS = inifull
	,addDef = TextControl "Project Paths" []
	:+: LayoutControl
		(	ButtonControl "Append..."
			[ ControlFunction addPath
			, ControlWidth buttonWidth
			]
		:+: ButtonControl "Remove"
			[ ControlPos (Left,zero)
			, ControlFunction removePath
			, ControlWidth buttonWidth
			, ControlId r1id
			, ControlSelectState Unable
			]
		:+:	ButtonControl "Up" [ControlPos (Left,zero),ControlFunction lbUp]
		:+:	ButtonControl "Dn" [ControlPos (Left,zero),ControlFunction lbDn]
		) [ControlPos (Left,zero),ControlHMargin 0 0, ControlVMargin 0 0]
	:+: lbpad
	:+: CheckControl
		[ ("Show Full Names",Nothing,toMark inifull,showFullPaths)
		]
		(Columns 1)
		[ ControlPos (Left,zero)
		, ControlId c1id
		]
	}
where
	lbpad = ExtListBoxControl
  				(zip3(FullPaths inifull ap pp (StrictListToList paths))(repeat id)(repeat id))
  				[] // initial selection
  				(\sel ps->case sel of
  					[]	-> appPIO (disableControl r1id) ps
  					_	-> appPIO (enableControl r1id) ps
  				)						// selection update function
  				lbpadId
  				[ControlViewSize {h=height,w=300}]
	buttonWidth = ContentWidth "Append..."
	lbUp ((full,tg),ps)
		# lo = tg.paths
		# (_,(lo,ps)) = upSelItem lbpadId (StrictListToList lo,ps)
		# lo = ListToStrictList lo
		# tg = {tg & paths = lo}
		= ((full,tg),ps)
	lbDn ((full,tg),ps)
		# lo = tg.paths
		# (_,(lo,ps)) = dnSelItem lbpadId (StrictListToList lo,ps)
		# lo = ListToStrictList lo
		# tg = {tg & paths = lo}
		= ((full,tg),ps)

	addPath ((full,tg),ps)
		#	(fs,ps)				= selectDirectory` ps
		| isNothing fs = ((full,tg),ps)
		#	pathname			= fromJust fs
			tg					= {tg & paths = Append tg.paths pathname}
			ps					= appendExtListBoxItems lbpadId (zip3 [FullPath full ap pp pathname](repeat id)(repeat id)) ps
		= ((full,tg),ps)

	removePath ((full,tg),ps)
		#	((ok,sel),ps)		= getExtListBoxSelection lbpadId ps
		| not ok || isEmpty sel
			= ((full,tg),ps)
		#	(pathsel,indexsel)	= unzip sel
			pathsel				= ListToStrictList [fulPath ap pp s \\ s <- pathsel]
		| StringOccurs root_path pathsel
			#! ps				= okNotice ["Removing path to main module not allowed."] ps
			= ((full,tg),ps)
		#	tg					= {tg & paths = RemoveMembers tg.paths pathsel}
			ps					= closeExtListBoxItems lbpadId indexsel ps
			ps					= setExtListBoxSelection lbpadId [] ps
		= ((full,tg),ps)
	showFullPaths ((full,tg=:{paths}),ps)
		#	full	= not full
			ps		= appPIO (setCheckControlMark full c1id) ps
			ps		= closeAllExtListBoxItems lbpadId ps
			ps		= appendExtListBoxItems lbpadId (zip3 (FullPaths full ap pp (StrictListToList paths))(repeat id)(repeat id)) ps
		= ((full,tg),ps)

setCheckControlMark full id io
	= case full of
		True	-> markCheckControlItems id [1] io
		False	-> unmarkCheckControlItems id [1] io

project_directory_up :: !(PSt General) -> PSt General
project_directory_up ps
	# (project,ps) = getProject ps
	| not (PR_ProjectSet project)
		= okNotice ["No open project"] ps
	# (project_file_path,ps) = getProjectFilePath ps
	  project_file_dir = RemoveFilename project_file_path
	  relative_root_dir = PR_GetRelativeRootDir project
	  parent_project_dir = make_project_dir (size relative_root_dir+1) project_file_dir
	| size parent_project_dir==0 || parent_project_dir==PR_GetRootDir project
		= okNotice ["Project directory cannot be moved further up"] ps
	# relative_root_dir = relative_root_dir+++"."
	  project = change_root_directory_of_project relative_root_dir parent_project_dir project
	  ps = setProject project ps
	= pm_update_project_window ps

project_directory_down :: !(PSt General) -> PSt General
project_directory_down ps
	# (project,ps) = getProject ps
	| not (PR_ProjectSet project)
		= okNotice ["No open project"] ps
	# (project_file_path,ps) = getProjectFilePath ps
	  project_file_dir = RemoveFilename project_file_path
	  relative_root_dir = PR_GetRelativeRootDir project
	  child_project_dir = make_project_dir (size relative_root_dir-1) project_file_dir
	| size relative_root_dir<=1 || child_project_dir==PR_GetRootDir project
		= okNotice ["Project directory cannot be moved further down"] ps	
	# relative_root_dir = relative_root_dir % (0,size relative_root_dir-2)
	  project = change_root_directory_of_project relative_root_dir child_project_dir project
	  ps = setProject project ps
	= pm_update_project_window ps

doPathsDialog :: !String !Pathname !Pathname !(List Pathname) ((List Pathname) (PSt .l) -> (PSt .l)) (PSt .l) -> (PSt .l)
doPathsDialog titlestring ap pp lo set ps
	#	(wid,ps)	= openId ps
		(okid,ps)	= openId ps
		(cancelid,ps)	= openId ps
		buttonwidth = ContentWidth "Append..."
		(siz,ps)	= controlSize (LayoutControl
						(	ButtonControl "Append..."
							[ ControlWidth buttonwidth
							]
						:+:	ButtonControl "Remove"
							[ ControlPos (Left,zero)
							, ControlWidth buttonwidth
							]
						:+:	ButtonControl "Up"
							[ ControlPos (Left,zero)
							, ControlWidth buttonwidth
							]
						:+:	ButtonControl "Dn"
							[ ControlPos (Left,zero)
							, ControlWidth buttonwidth
							]
						) [ControlPos (Left,zero),ControlHMargin 0 0, ControlVMargin 0 0])
						True
						Nothing Nothing Nothing ps
		(lb1Id,ps) = openExtListBoxId ps
		(r1id,ps) = openId ps
		lbpad = ExtListBoxControl
	  				(zip3(FullPaths inifull ap pp (StrictListToList lo))(repeat id)(repeat id))
	  				[] // initial selection
	  				(\sel ps->case sel of
	  					[]	-> appPIO (disableControl r1id) ps
	  					_	-> appPIO (enableControl r1id) ps
	  				)						// selection update function
	  				lb1Id
	  				[ControlViewSize {h=siz.Size.h,w=300}]
		(_,ps) = openModalDialog (lo,inifull) (ddef wid okid cancelid lbpad lb1Id r1id siz) ps
	= ps
where
	inifull = False
	ddef wid okId cancelId lb1 lb1Id r1id siz = Dialog "Paths"
			(title :+: left :+: buttons)
			[WindowId wid, WindowOk okId, WindowCancel cancelId, WindowClose cancel]
	where
		title
			=	TextControl titlestring [ControlPos (Center,zero)]
		buttons
			=	ButtonControl "Cancel" [ControlFunction cancel, ControlPos (Left,zero), ControlId cancelId]
			:+: ButtonControl "OK" [ControlFunction okfun, ControlId okId]
		cancel (ls,ps)
			# ps = closeWindow wid ps
			= (ls, ps)
		okfun ((lo,full),ps)
			#	ps = set lo ps
				ps = closeWindow wid ps
			= ((lo,full), ps)

		left = LayoutControl
				(TextControl "Paths" []
				:+: LayoutControl
					(	ButtonControl "Append..." 
						[ ControlFunction addPath
						]
					:+: ButtonControl "Remove"
						[ ControlPos (Left,zero)
						, ControlFunction removePath
						, ControlSelectState Unable
						, ControlId r1id
						]
						:+:	ButtonControl "Up" [ControlPos (Left,zero),ControlFunction lbUp]
						:+:	ButtonControl "Dn" [ControlPos (Left,zero),ControlFunction lbDn]
					) [ControlPos (Left,zero),ControlHMargin 0 0, ControlVMargin 0 0]
				:+: lb1
				:+: CheckControl
					[ ("Show Full Names",Nothing,toMark inifull,showFullPaths)
					]
					(Columns 1)
					[ ControlPos (Left,zero)
					]
				)
				[ControlPos (Left,zero)]
		where
			lbUp ((lo,full),ps)
				# (_,(lo,ps)) = upSelItem lb1Id (StrictListToList lo,ps)
				= ((ListToStrictList lo,full),ps)
			lbDn ((lo,full),ps)
				# (_,(lo,ps)) = dnSelItem lb1Id (StrictListToList lo,ps)
				= ((ListToStrictList lo,full),ps)

			addPath ((lo,full),ps)
				#	(fs,ps)				= selectDirectory` ps
				| isNothing fs = ((lo,full),ps)
				#	pathname			= fromJust fs
				#	lo					= Append lo pathname
				#	ps					= appendExtListBoxItems lb1Id (zip3 [FullPath full ap pp pathname](repeat id)(repeat id)) ps
				= ((lo,full),ps)

			removePath ((lo,full),ps)
				#	((ok,sel),ps)		= getExtListBoxSelection lb1Id ps
				| not ok || isEmpty sel = ((lo,full),ps)
				#	(pathsel,indexsel)	= unzip sel
					lo					= seq [RemoveStringFromList (fulPath ap pp s) \\ s <- pathsel] lo
					ps					= closeExtListBoxItems lb1Id indexsel ps
					ps					= setExtListBoxSelection lb1Id [] ps
				= ((lo,full),ps)
			showFullPaths ((lo,full),ps)
				#	full				= not full
					ps					= closeAllExtListBoxItems lb1Id ps
					ps					= appendExtListBoxItems lb1Id (zip3 (FullPaths full ap pp (StrictListToList lo))(repeat id)(repeat id)) ps
				= ((lo,full),ps)
		
doCompilerOptionsDialog :: !String !CompilerOptions (CompilerOptions (PSt .l) -> (PSt .l)) !(PSt .l) -> (PSt .l)
doCompilerOptionsDialog titlestring ini set ps
	# (wid,ps) = accPIO openId ps
	# (cid,ps) = accPIO openId ps
	# (okId,ps) = accPIO openId ps
	# (_,ps) = openModalDialog ini (ddef okId wid cid) ps
	= ps
where
	ddef okId wid cancelId = Dialog titlestring
			(title :+: left :+: right :+: buttons)
			[WindowId wid
			,WindowOk okId
			,WindowClose cancel
			,WindowCancel cancelId
			]
	where
		title = TextControl titlestring [ControlPos (Center,zero)]
		left = LayoutControl
				(TextControl "Program Analysis" []
				:+: CheckControl
					[ ("Strictness Analyzer",Nothing,toMark ini.sa,noPS (\l->{l & sa = not l.sa}))
					]
					(Columns 1)
					[ ControlPos (Left,zero)
					]
				:+: TextControl "Code Generation"
					[ ControlPos (Left,OffsetVector {zero & vy = 10})
					]
				:+: CheckControl
					[ ("Generate Comments",Nothing,toMark ini.gc,noPS (\l->{l & gc = not l.gc}))
					, ("Reuse Unique Nodes",Nothing,toMark ini.reuseUniqueNodes,noPS (\l->{l & reuseUniqueNodes = not l.reuseUniqueNodes}))
					, ("Never Time Profile",Nothing,toMark ini.neverTimeProfile,noPS (\l->{l & neverTimeProfile = not l.neverTimeProfile}))
//					, ("Never Memory Profile",Nothing,toMark ini.neverMemoryProfile,noPS (\l->{l & neverMemoryProfile = not l.neverMemoryProfile}))
					]
					(Columns 1)
					[ ControlPos (Left,zero)
					]
				:+: TextControl "Fusion" [ControlPos (Left,zero)]
				:+: RadioControl
					[ ("Default",Nothing,noPS (\l->{l & fusion = FusionDefault}))
					, ("Off",Nothing,noPS (\l->{l & fusion = FusionOff}))
					, ("On",Nothing,noPS (\l->{l & fusion = FusionOn}))
					]
					(Rows 1)
					(case ini.fusion of
						FusionDefault	-> 1
						FusionOff		-> 2
						FusionOn		-> 3
					)
					[ ControlPos (Left,zero)
					]
				)
				[ControlPos (Left,zero)]
		right = LayoutControl
				(TextControl "Diagnostics" []
				:+: CheckControl
					[ ("Give Warnings",Nothing,toMark ini.gw,noPS (\l->{l & gw = not l.gw}))
					, ("Be Verbose",Nothing,toMark ini.bv,noPS (\l->{l & bv = not l.bv}))
					]
					(Columns 1)
					[ ControlPos (Left,zero)
					]
				:+: TextControl "List Types"
					[ ControlPos (Left,OffsetVector {zero & vy = 10})
					]
				:+: RadioControl
					[ ("No Types",Nothing,noPS (\l->{l & listTypes = NoTypes}))
					, ("Inferred Types",Nothing,noPS (\l->{l & listTypes = InferredTypes}))
					, ("Strict Export Types",Nothing,noPS (\l->{l & listTypes = StrictExportTypes}))
					, ("All Types",Nothing,noPS (\l->{l & listTypes = AllTypes}))
					]
					(Columns 1)
					(case ini.listTypes of
						NoTypes				-> 1
						InferredTypes		-> 2
						StrictExportTypes	-> 3
						AllTypes			-> 4
					)
					[ ControlPos (Left,zero)
					]
				:+: CheckControl
					[ ("Show Attributes",Nothing,toMark ini.attr,noPS (\l->{l & attr = not l.attr}))
					]
					(Columns 1)
					[ControlPos (Left,zero)
					]
				)
				[]
		buttons
			=	ButtonControl "Cancel"
				[ ControlWidth (ContentWidth "Cancel")
				, ControlFunction cancel
				, ControlPos (Left,zero)
				, ControlId cancelId
				]
			:+: ButtonControl "OK"
				[ ControlWidth (ContentWidth "Cancel")
				, ControlFunction okfun
				, ControlId okId
				]
		cancel (ls,ps)
			# ps = closeWindow wid ps
			= (ls, ps)
		okfun (ls,ps)
			# ps = closeWindow wid ps
			  ps = set ls ps
			= (ls, ps)

//---

// Conversion from memory size to strings and back
    
Mega	:== 1048576;
Kilo	:== 1024;

IntToMemSize :: !Int -> String;
IntToMemSize mem
	| mega && mem <> 0
		=  megamemstr;
	| kilo && mem <> 0
		=  kilomemstr;
		=  memstr;
	where 
		mega		= mem rem Mega  == 0;
		kilo		= mem rem Kilo  == 0;
		megamemstr	= toString (mem / Mega)  +++ "M";
		kilomemstr	= toString (mem / Kilo)  +++ "K";
		memstr		= toString mem;
	

MemSizeToInt :: !String -> Int;
MemSizeToInt size =  scale * scaleless;
	where 
		scale		= GetScale size;
		scaleless	= StringToInt (RemoveScale size);
	
// Converts a string into a number

StringToInt	:: !String -> Int;
StringToInt string =  TextToNumber string 0;

TextToNumber :: !String !Int -> Int;
TextToNumber ""	n				=  n;
TextToNumber s	n	| isdigit	=  number;
								=  n;
	where 
	number		= TextToNumber (s % (1, dec (size s))) ( 10 * n  + d);
	(isdigit,d)	= Digit (s .[ 0]);
	

Digit :: !Char -> (!Bool, !Int);
Digit '0'  =  (True, 0); 	  Digit '1' =  (True, 1);
Digit '2'  =  (True, 2); 	  Digit '3' =  (True, 3);
Digit '4'  =  (True, 4); 	  Digit '5' =  (True, 5);
Digit '6'  =  (True, 6); 	  Digit '7' =  (True, 7);
Digit '8'  =  (True, 8);	  Digit '9' =  (True, 9);
Digit c	   =  (False,0);

	
GetScale :: !String -> Int;
GetScale num
	| lennum == 0
		=  0;
	| last == 'k' || last == 'K'
		=  Kilo;
	| last == 'm' || last == 'M'
		=  Mega;
		=  1;
	where 
		last	= num .[dec lennum];
		lennum	= size num;
	
		
RemoveScale	:: !String -> String;
RemoveScale num
	| lennum < 2
		=  num;
	| last == 'k' || last == 'K' || last == 'm'	|| last == 'M'
		=  num % (0, lennum - 2);
		= num;
	where 
		lennum	= size num;
		last	= num.[dec lennum];

StringToFixedPoint :: !String -> Int
StringToFixedPoint s
	| n<512+128
		= 512+128;
	| n>100<<8
		= 100<<8;
		= n;
where
		n=string_to_fixed_point 0 0 s;
		
		string_to_fixed_point i v s
			| i>= size s
				= v<<8;
			| char>='0' && char<='9'
				= string_to_fixed_point (inc i) (v*10+(toInt char-48)) s;
			| char=='.'
				= (v<<8)+fraction (inc i) s;
				= v<<8;
		where
				char=s.[i];
			
		fraction i s
			| i>= size s || char1<'0' || char1>'9'
				= 0;
			| inc i>= size s || char2<'0' || char2>'9'
				= ((toInt char1-48)<<8) / 10;
				= (((toInt char1-48)*10+(toInt char2-48))<<8)/100;
		where
			char1=s.[i];
			char2=s.[inc i];

FixedPointToString :: !.Int -> String
FixedPointToString n
	| n<512+128
		= "2.5";
	| n>100<<8
		= "100";
	| second_digit<>0
		= toString (n>>8)+++"."+++toString first_digit+++toString second_digit;
	| first_digit<>0
		= toString (n>>8)+++"."+++toString first_digit;
		= toString (n>>8);
where
		first_digit=fraction / 10;
		second_digit=fraction rem 10;
		fraction=toInt (toReal (n bitand 255) * 100.0 / 256.0);

//-- path fiddling utils

FullPath True _ _ l = l
FullPath False ap pp l = symPath ap pp l

FullPaths True _ _ l = l
FullPaths False ap pp l
	#	l = map (symPath ap pp) l
	#	l = map (symPath ap pp) l
	= l
