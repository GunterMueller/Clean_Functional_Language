 implementation module iDataState

// encoding and decoding of information
// (c) 2005 MJP

import StdArray, StdList, StdOrdList, StdString, StdTuple, ArgEnv, StdMaybe, Directory
import htmlDataDef, htmlTrivial, htmlFormData, EncodeDecode
import GenPrint, GenParse
import dynamic_string
import EstherBackend
//import Debug // TEMP


// This module controls the handling of state forms and the communication with the browser
// iData states are maintained in a binairy tree

// The are currently two storage formats for iData values: 
// 1. a string format, generically generated; works for any first order type.
// A generic parser is needed to convert the string back to a value of the required type.
// 2. a static (= no dynamic linker needed) dynamic; works for any type, including higher order types.
// But watch it: only the application which wrotes the dynamic, can read it back: no plug ins! recompiling means: all information lost!
// A distinction is made between old states (states retrieved from the html form)
// and new states (states of newly created forms and updated forms)

:: *FormStates 	=										// collection of states of all forms
				{ fstates 	:: *FStates					// internal tree of states
				, triplets	:: [(Triplet,String)]		// indicates what has changed: which form, which postion, which value
				, updateid	:: String					// which form has changed
				, server	:: ServerKind				// is an external server required
				}		

:: FStates		:== Tree_ (String,FormState)			// each form needs a different string id
:: Tree_ a 		= Node_ (Tree_ a) a (Tree_ a) | Leaf_
:: FormState 	= OldState !FState						// Old states are the states from the previous calculation
				| NewState !FState 						// New states are newly created states or old states that have been inspected and updated
:: FState		= { format	:: !Format					// Encoding method used for serialization
				  , life	:: !Lifespan				// Its life span
				  }
:: Format		= PlainStr 	!.String 					// Either a string is used for serialization
				| StatDyn	!Dynamic 					// Or a dynamic which enables serialization of functions defined in the application (no plug ins yet)
				| DBStr		!.String (*Gerda -> *Gerda)	// In case a new value has to bestored in the database 
				
// Options

readGerda` id gerda 
:== IF_GERDA (readGerda id gerda)
					(abort "Reading Database, yet option is swiched off\n", 
					 abort "Reading Database, yet option is swiched off\n")

writeGerda` id val 
:== IF_GERDA (writeGerda id val)
					(\_ -> abort "Writing Database, yet option is swiched off\n")

// functions defined on the FormStates abstract data type

instance < FormState
where
	(<) _ _ = True

emptyFormStates :: *FormStates
emptyFormStates = { fstates = Leaf_ , triplets = [], updateid = "", server = Internal}

getTriplets :: !String !*FormStates -> (Triplets,!*FormStates)
getTriplets id formstates=:{triplets} = ([mytrips \\ mytrips=:((tripid,_,_),_) <- triplets | id == tripid] ,formstates)

getUpdateId :: !*FormStates -> ([String],!*FormStates)
getUpdateId formStates=:{triplets} = (removeDup [tripid \\ ((tripid,_,_),_) <- triplets] ,formStates)

getUpdate :: !*FormStates -> (String,!*FormStates)
//getUpdate formStates=:{update} = (update,formStates)
getUpdate formStates = ("",formStates)

findState :: !(FormId a) !*FormStates *NWorld -> (Bool,Maybe a,*FormStates,*NWorld)	| iPrint, iParse, iSpecialStore a	
findState formid formstates=:{fstates,server} world
# (bool,ma,fstates,world) = findState` formid fstates world
= (bool,ma,{formstates & fstates = fstates},world)
where
//	findState` :: !(FormId a) *FStates *NWorld -> (Bool,Maybe a,*FStates,*NWorld)| gPrint{|*|}, gerda{|*|}, TC, gParse{|*|} a //iDataSerAndDeSerialize a
	findState` formid formstate=:(Node_ left (fid,info) right) world
	| formid.id == fid	= case info of
							(OldState state)	= (True, fetchFState state,formstate,world)
							(NewState state)	= (False,fetchFState state,formstate,world)
	with
		fetchFState :: FState -> Maybe a | TC a & gParse{|*|} a
		fetchFState {format = PlainStr string}	= parseString string
		fetchFState {format = DBStr string _}	= parseString string
		fetchFState {format = StatDyn (v::a^)}	= Just v    
		fetchFState _							= Nothing
	| formid.id  < fid 	= (bool,parsed, Node_ leftformstates (fid,info) right,nworld)
						with
							(bool,parsed,leftformstates,nworld)  = findState` formid left world
	| otherwise			= (bool,parsed, Node_  left (fid,info) rightformstates,nworld)
						with
							(bool,parsed,rightformstates,nworld) = findState` formid right world

	// value is not yet available in the tree storage...
	// all stuff read out from persistent store is now marked as OldState (was NewState)	
	// read out database and store as string 

	findState` {id,lifespan = Database,storage = PlainString} Leaf_ world=:{gerda} 
	# (value,gerda)		= readGerda` id	gerda
	# world				= {world & gerda = gerda}
	= case value of
		Just a			= (True, Just a, Node_ Leaf_ (id,OldState {format = PlainStr (printToString a), life = Database}) Leaf_,world)
		Nothing			= (False,Nothing,Leaf_,world)

	// read out database and store as dynamic

	findState` {id,lifespan = Database,storage = StaticDynamic} Leaf_ world=:{gerda} 
	# (value,gerda)		= readGerda` id	gerda
	# world				= {world & gerda = gerda}
	= case value of 
		Nothing 		= (False,Nothing,Leaf_,world)
		Just string		= case string_to_dynamic` string of
							dyn=:(dynval::a^) 	-> (True, Just dynval,Node_ Leaf_ (id,OldState {format = StatDyn dyn, life = Database}) Leaf_,world)
							else				-> (False,Nothing,    Leaf_,world)

	// read out file and store as string

	findState` {id,lifespan = TxtFile,storage = PlainString} Leaf_ world 
	# (string,world)	= readState (MyDir server) id world
	= case parseString string of
		Just a			= (True, Just a, Node_ Leaf_ (id,OldState {format = PlainStr string, life = TxtFile}) Leaf_,world)
		Nothing			= (False,Nothing,Leaf_,world)

	findState` {id,lifespan = TxtFileRO,storage = PlainString} Leaf_ world 
	# (string,world)	= readState (MyDir server) id world
	= case parseString string of
		Just a			= (True, Just a, Node_ Leaf_ (id,OldState {format = PlainStr string, life = TxtFileRO}) Leaf_,world)
		Nothing			= (False,Nothing,Leaf_,world)

	// read out file and store as dynamic

	findState` {id,lifespan = TxtFile,storage = StaticDynamic} Leaf_ world 
	# (string,world)	= readState (MyDir server) id world
	= case string of 
		""				= (False,Nothing,Leaf_,world)
		_				= case string_to_dynamic` string of
							dyn=:(dynval::a^)	= (True, Just dynval,Node_ Leaf_ (id,OldState {format = StatDyn dyn, life = TxtFile}) Leaf_,world)
							else				= (False,Nothing,    Leaf_,world)
//	with
//		mydebug s dyn = ["\n" <+++ s <+++ ShowValueDynamic dyn <+++ " :: " <+++ ShowTypeDynamic dyn]

	findState` {id,lifespan = TxtFileRO,storage = StaticDynamic} Leaf_ world 
	# (string,world)	= readState (MyDir server) id world
	= case string of 
		""				= (False,Nothing,Leaf_,world)
		_				= case string_to_dynamic` string of
							dyn=:(dynval::a^)	= (True, Just dynval,Node_ Leaf_ (id,OldState {format = StatDyn dyn, life = TxtFileRO}) Leaf_,world)
							else				= (False,Nothing,    Leaf_,world)

	// cannot find the value at all

	findState` _ Leaf_ world	= (False,Nothing,Leaf_,world)
	findState` _ _ world		= (False,Nothing,Leaf_,world)

string_to_dynamic` :: {#Char} -> Dynamic	// just to make a unique copy as requested by string_to_dynamic
string_to_dynamic` s	= string_to_dynamic {s` \\ s` <-: s}

replaceState ::  !(FormId a) a !*FormStates *NWorld -> (*FormStates,*NWorld)	| iPrint,iSpecialStore a	
replaceState formid val formstates=:{fstates} world
# (fstates,world)		= replaceState` formid val fstates world
= ({formstates & fstates = fstates},world)
where
	replaceState` ::  !(FormId a) a *FStates *NWorld -> (*FStates,*NWorld)	| iPrint, iSpecialStore a	
	replaceState` formid val Leaf_ world 									// id not part of tree yet
						= (Node_ Leaf_ (formid.id,NewState (initNewState formid.id (adjustlife formid.lifespan) Temp formid.storage val)) Leaf_,world)
	replaceState` formid val (Node_ left a=:(fid,fstate) right) world
	| formid.id == fid	= (Node_ left (fid,NewState (initNewState formid.id formid.lifespan (detlifespan fstate) formid.storage val)) right,world)
	| formid.id <  fid	= (Node_ nleft a right,nworld)
							with
								(nleft, nworld) = replaceState` formid val left  world
	| otherwise			= (Node_ left a nright,nworld)
							with
								(nright,nworld) = replaceState` formid val right world

	// NewState Handling routines 

	initNewState :: !String !Lifespan !Lifespan !StorageFormat !a  -> FState | iPrint,  iSpecialStore a	
	initNewState id Database olifespan PlainString   nv = {format = DBStr    (printToString nv) (writeGerda` id nv), life = order Database olifespan}
	initNewState id lifespan olifespan PlainString   nv = {format = PlainStr (printToString nv),                     life = order lifespan olifespan}
	initNewState id lifespan olifespan StaticDynamic nv = {format = StatDyn  (dynamic nv),                           life = order lifespan olifespan}// convert the hidden state information stored in the html page

	adjustlife TxtFileRO = TxtFile		// to enforce that a read only persistent file is written once
	adjustlife life		= life

	detlifespan (OldState formstate) = formstate.life
	detlifespan (NewState formstate) = formstate.life

	order l1 l2			= if (l1 < l2) l2 l1	// longest lifetime chosen will be the final setting Database > TxtFile > Session > Page > temp

deleteStates :: !(String -> Bool) !*FormStates *NWorld -> (*FormStates,*NWorld)	
deleteStates pred formstates=:{fstates,server} world
# (fstates,world)		= deleteStates` fstates world
= ({formstates & fstates = fstates},world)
where
	deleteStates` :: *FStates *NWorld -> (*FStates,*NWorld)	
	deleteStates` Leaf_ world 									// id not part of tree yet
						= (Leaf_,world)
	deleteStates` (Node_ left a=:(fid,fstate) right) world
	# (nleft, world) 	= deleteStates` left  world
	# (nright,world)	= deleteStates` right world
	| pred fid			= deleteIData nleft nright a world
	= (Node_ nleft a nright,world)

	deleteIData left right a world
	# world = deleteTxtFileIData a world
	= (join left right,world)
	where
		join Leaf_  right 	= right
		join left   Leaf_  	= left    
		join left   right	= Node_ nleft largest right
		where
			(largest,nleft)	= FindRemoveLargest left
	
			FindRemoveLargest (Node_ left x Leaf_)  = (x,left)
			FindRemoveLargest (Node_ left x right ) = (largest,Node_ left x nright)
			where
				(largest,nright) = FindRemoveLargest right

		deleteTxtFileIData (fid,OldState {life}) world 	= deleteTxtFile fid life world
		deleteTxtFileIData (fid,NewState {life}) world 	= deleteTxtFile fid life world

		deleteTxtFile fid Database 		world=:{gerda}	= {world & gerda  = deleteGerda fid gerda}
		deleteTxtFile fid TxtFile 	world 			= deleteState (MyDir server) fid world
		deleteTxtFile fid TxtFileRO 	world			= deleteState (MyDir server) fid world
		deleteTxtFile fid _ 				world 			= world

// Serialization and De-Serialization of states
//
// De-serialize information from server to the internally used form states

retrieveFormStates :: ServerKind (Maybe [(String, String)]) *NWorld -> (*FormStates,*NWorld) 					// retrieves all form states hidden in the html page
retrieveFormStates serverkind args world 
	= ({ fstates = retrieveFStates, triplets = triplets, updateid = calc_updateid triplets, server = serverkind },world)
where
	retrieveFStates 
		= Balance (sort [(sid,OldState {format = toExistval storageformat state, life = lifespan}) 
						\\ (sid,lifespan,storageformat,state) <- htmlStates
						|  sid <> ""
						])
	where
		toExistval PlainString   string	= PlainStr string						// string that has to be parsed in the context where the type is known
		toExistval StaticDynamic string	= StatDyn (string_to_dynamic` string)	// recover the dynamic

	(htmlStates,triplets)	= DecodeHtmlStatesAndUpdate serverkind args
	
	calc_updateid [] 	= ""		
	calc_updateid [(triplet,upd):_]	= case triplet of
							("",0,UpdI 0)	= ""
							(id,_,_)		= id 
							else			= ""

// Serialize all states in FormStates that have to be remembered to either hidden encoded Html Code
// or store them in a persistent file, all depending on the kind of states

storeFormStates :: !FormStates *NWorld -> (BodyTag,*NWorld)
storeFormStates {fstates = allFormStates,server} world
#	world							= writeAllTxtFileStates allFormStates world			// first write all persistens states
=	(BodyTag
	[ submitscript    
	, globalstateform (SV encodedglobalstate) 
	],world)
where
	encodedglobalstate				= EncodeHtmlStates (FStateToHtmlState allFormStates [])

	FStateToHtmlState :: !(Tree_ (String,.FormState)) *[HtmlState] -> *[HtmlState]
	FStateToHtmlState Leaf_ accu	= accu
	FStateToHtmlState (Node_ left x right) accu
		= case htmlStateOf x of
			Just state				= FStateToHtmlState left [state : FStateToHtmlState right accu]
			nothing					= FStateToHtmlState left         (FStateToHtmlState right accu)
	where
		htmlStateOf :: !(String,.FormState) -> Maybe HtmlState
		// old states which have not been used this time, but with lifespan session, are stored again in the page
		// other old states will have lifespan page or are persistent; they need not to be stored
		htmlStateOf (fid,OldState {life=Session,format=PlainStr stringval})	= Just  (fid,Session,PlainString,stringval)
		htmlStateOf (fid,OldState {life=Session,format=StatDyn  dynval})	= Just  (fid,Session,StaticDynamic,dynamic_to_string dynval)
		htmlStateOf (fid,OldState s)										= Nothing

		// persistent stores (either old or new) have already been stored in files and can be skipped here
		// temperal form don't need to be stored and can be skipped as well
		// the state of all other new forms created are stored in the page 
		htmlStateOf (fid,NewState {life})
			| isMember life [Database,TxtFile,TxtFileRO,Temp]			= Nothing
		htmlStateOf (fid,NewState {format = PlainStr string,life})			= Just (fid,life,PlainString,string)
		htmlStateOf (fid,NewState {format = StatDyn dynval, life})			= Just (fid,life,StaticDynamic,dynamic_to_string dynval)

	writeAllTxtFileStates :: !FStates *NWorld -> *NWorld				// store states in persistent stores
	writeAllTxtFileStates Leaf_ nworld = nworld
	writeAllTxtFileStates (Node_ left st right) nworld
		= writeAllTxtFileStates right (writeAllTxtFileStates left (writeTxtFileState st nworld))
	where
	// only new states need to be stored, since old states have not been changed (assertion)
		writeTxtFileState (sid,NewState {format,life = Database}) nworld=:{gerda}
		= case format of
			DBStr string gerdafun	= {nworld & gerda = gerdafun gerda}										// last value is stored in curried write function
			StatDyn dynval			= {nworld & gerda = writeGerda sid (dynamic_to_string dynval) gerda}	// write the dynamic as a string to the database
		writeTxtFileState (sid,NewState {format,life = TxtFile}) nworld
		= case format of
				PlainStr string		= writeState (MyDir server) sid string nworld
				StatDyn  dynval		= writeState (MyDir server) sid (dynamic_to_string dynval) nworld
		writeTxtFileState _ nworld
		= nworld

// trace States
 
traceStates :: !*FormStates -> (BodyTag,!*FormStates)
traceStates formstates=:{fstates}
# (bodytags,fstates) = traceStates` fstates
= (BodyTag [Br, B [] "State values when application ended:",Br,		
			 STable [] ([[B [] "Id:", B[] "Inspected:", B [] "Lifespan:", B [] "Format:", B [] "Value:"]] ++ 
						 bodytags)
			],{formstates & fstates = fstates})
where
	traceStates` Leaf_		= ([],Leaf_)
	traceStates` (Node_ left a right)
	# (leftTrace,left)		= traceStates` left
	# nodeTrace				= nodeTrace a
	# (rightTrace,right)	= traceStates` right
	= (leftTrace ++ nodeTrace ++ rightTrace,Node_ left a right)

	nodeTrace (id,OldState fstate=:{format,life}) = [[Txt id,Txt "No", Txt (toString life):toStr format]]
	nodeTrace (id,NewState fstate=:{format,life}) = [[Txt id,Txt "Yes",Txt (toString life):toStr format]]
	
	toStr (PlainStr str) = [Txt "String", Txt str]
	toStr (StatDyn  dyn) = [Txt "S_Dynamic", Txt (ShowValueDynamic dyn <+++ " :: " <+++ ShowTypeDynamic dyn )]
	toStr (DBStr    str _) = [Txt "Database", Txt str]
	
strip s = { ns \\ ns <-: s | ns >= '\020' && ns <= '\0200'}

ShowValueDynamic :: Dynamic -> String
ShowValueDynamic d = strip (foldr (+++) "" (fst (toStringDynamic d)) +++ " ")

ShowTypeDynamic :: Dynamic -> String
ShowTypeDynamic d = strip (snd (toStringDynamic d) +++ " ")
// debugging code 

print_graph :: !a -> Bool;
print_graph a = code {
.d 1 0
jsr _print_graph
.o 0 0
pushB TRUE
}

my_dynamic_to_string :: !Dynamic -> {#Char};
my_dynamic_to_string d
| not (print_graph d)
= abort ""
#! s=dynamic_to_string d;
| not (print_graph (tohexstring s))
= abort "" 
# d2 = string_to_dynamic {c \\ c <-: s};
| not (print_graph d2)
= abort ""
= s;

tohexstring :: {#Char} -> {#Char};
tohexstring s = {tohexchar s i \\ i<-[0..2*size s-1]};

tohexchar :: {#Char} Int -> Char;
tohexchar s i
# c=((toInt s.[i>>1]) >> ((1-(i bitand 1))<<2)) bitand 15;
| c<10
= toChar (48+c);
= toChar (55+c);

//	create balanced storage tree:

Balance :: ![a] -> .(Tree_ a)
Balance []					= Leaf_
Balance [x]					= Node_ Leaf_ x Leaf_
Balance xs
	= case splitAt (length xs/2) xs of
		(a,[b:bs])			= Node_ (Balance a) b (Balance bs)
		(as,[])				= Node_ (Balance (init as)) (last as) Leaf_

import GenMap
derive gMap Tree_

// interfaces added for testing:

initTestFormStates :: *NWorld -> (*FormStates,*NWorld)													// retrieves all form states hidden in the html page
initTestFormStates world 
	= ({ fstates = Leaf_, triplets = [], updateid = "" , server = JustTesting},world)

setTestFormStates :: [(Triplet,String)] String String *FormStates *NWorld -> (*FormStates,*NWorld)			// retrieves all form states hidden in the html page
setTestFormStates triplets updateid update states world 
	= ({ fstates = gMap{|*->*|} toOldState states.fstates, triplets = triplets, updateid = updateid, server = JustTesting},world)
where
	toOldState (s,NewState fstate)	= (s,OldState fstate)
	toOldState else					= else
