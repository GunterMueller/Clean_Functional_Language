definition module htmlFormData

// common data type definition used for forms
// (c) 2005 - MJP

import htmlHandler
import StdMaybe, StdBool
import GenEq

:: FormId d										// properties one has to assign to any form 
	=	{ id 		:: !String					// id *uniquely* identifying the form
		, lifespan	:: !Lifespan				// lifespan of form
		, mode		:: !Mode					// editable or not
		, storage	:: !StorageFormat			// serialization method
		, ival		:: !d						// initial value
		}

:: Init											// Usage of the value stored in FormId
	=	Const									//	The value is a constant
	|	Init 									// 	The value is taken as initial value
	|	Set  									// 	The value will be used as new iData value

:: Lifespan										// 	defines how long a form will be maintained		
	=	Database								//	persistent form stored in Database using generic db functions from Gerda
	|	TxtFile									// 	persistent form stored in a file
	|	TxtFileRO								//	persistent form stored in a file which is used Read-Only
	| 	Session									// 	form will live as long as one browses between the pages offered by the application
	| 	Page									// 	form will be automatically garbage collected when no reference is made to it in a page			
	|	Temp									//	form setting is not stored at all, only lives temporaly in the Clean application	

:: Mode											// one can choose:
	=	Edit									// 	an editable form where every change is commited to the server
	|	Submit									//	an editable form where the whole content is commited on submit 
	| 	Display									// 	a non-editable form
	|	NoForm									//	do not generate a form, only a value

:: HBimap d v 									// swiss army nife allowing to make a distinction between data and view domain
	=	{ toForm   	:: Init d (Maybe v) -> v	// 	converts data to view domain, given current view
		, updForm 	:: Changed v -> v			// 	update function, True when the form is edited 
		, fromForm 	:: Changed v -> d			// 	converts view back to data domain, True when form is edited
		, resetForm :: Maybe (v -> v)			// 	can be used to reset view (eg for buttons)
		}
:: Changed
	=	{ isChanged	:: Bool						// is this form changed
		, changedId	:: [String]					// id's of changed forms
		}
:: StorageFormat								// Serialization method:
	=	StaticDynamic							// + higher order types, fast, NO dynamic linker needed; - works only for a specific application !
	| 	PlainString								// - first order types only, slow (requires generic parser); + can be used by anyone who knows the type

:: Form a 										// result of any form
	=	{ changed 	:: Bool						// the user has edited the form
		, value		:: a						// current value in data domain (feel)
		, form		:: [BodyTag]				// html code to create the form, representing view domain (look)
		}

:: InIDataId d	:==	(!Init,!FormId d)			// Often used parameter of iData editors
:: IDataFun a	:== St *HSt (Form a)			// Often used iData HSt State transition functions

// **** easy creation of FormId's ****

class   (<@) infixl 4 att :: !(FormId d) !att -> FormId d

instance <@ String								// formId <@ x = {formId & id       = x}
instance <@ Lifespan							// formId <@ x = {formId & lifespan = x}
instance <@ Mode								// formId <@ x = {formId & mode     = x}
instance <@ StorageFormat						// formId <@ x = {formId & storage  = x}
mkFormId :: !String !d -> FormId d				// mkFormId str val = {id = str, ival = val} <@ Page <@ Edit <@ PlainString

// editable, string format
tFormId		:: !String !d -> FormId d			// temp
nFormId		:: !String !d -> FormId d			// page
sFormId		:: !String !d -> FormId d			// session
pFormId		:: !String !d -> FormId d			// persistent
rFormId		:: !String !d -> FormId d			// persistent read only
dbFormId	:: !String !d -> FormId d			// database

// non-editable, string format
tdFormId	:: !String !d -> FormId d			// temp                 + display
ndFormId	:: !String !d -> FormId d			// page                 + display
sdFormId	:: !String !d -> FormId d			// session              + display
pdFormId	:: !String !d -> FormId d			// persistent           + display
rdFormId	:: !String !d -> FormId d			// persistent read only + display
dbdFormId	:: !String !d -> FormId d			// database             + display

// noform, string format
xtFormId	:: !String !d -> FormId d			// temp                 + no form
xnFormId	:: !String !d -> FormId d			// page                 + no form
xsFormId	:: !String !d -> FormId d			// session              + no form
xpFormId	:: !String !d -> FormId d			// persistent           + no form
xrFormId	:: !String !d -> FormId d			// persistent read only + no form
xdbFormId	:: !String !d -> FormId d			// database             + no form

// editable, dynamic format also allows to store functions
nDFormId	:: !String !d -> FormId d			// page                 + static dynamic format
sDFormId	:: !String !d -> FormId d			// session              + static dynamic format
pDFormId	:: !String !d -> FormId d			// persistent           + static dynamic format
rDFormId	:: !String !d -> FormId d			// persistent read only + static dynamic format
dbDFormId	:: !String !d -> FormId d			// database             + static dynamic format

// non-editable, dynamic format also allows to store functions
ndDFormId	:: !String !d -> FormId d			// page                 + static dynamic format + display
sdDFormId	:: !String !d -> FormId d			// session              + static dynamic format + display
pdDFormId	:: !String !d -> FormId d			// persistent           + static dynamic format + display
rdDFormId	:: !String !d -> FormId d			// persistent read only + static dynamic format + display
dbdDFormId	:: !String !d -> FormId d			// database             + static dynamic format + display

// to create new FormId's ou of an existing one, handy for making unique identifiers

extidFormId :: !(FormId d) !String 		-> FormId d		// make new id by adding sufix 
subFormId 	:: !(FormId a) !String !d 	-> FormId d		// make new id for a new type by adding suffix
subnFormId 	:: !(FormId a) !String !d 	-> FormId d		// idem with lifespan Page
subsFormId 	:: !(FormId a) !String !d 	-> FormId d		// idem with lifespan Session
subpFormId 	:: !(FormId a) !String !d 	-> FormId d		// idem with lifespan Persitent
subtFormId 	:: !(FormId a) !String !d 	-> FormId d		// idem with lifespan Temp

setFormId 	:: !(FormId d) !d			-> FormId d		// set new initial value in formid
reuseFormId :: !(FormId a) !d			-> FormId d		// reuse id for new type (only to be used in gform)

initID		:: !(FormId d)				-> InIDataId d	// (Init,FormId a)
setID		:: !(FormId d) !d			-> InIDataId d	// (Set,FormId a)

onMode 		:: !Mode a a a a -> a						// chose arg depending on Edit, Submit, Display, NoForm

// manipulating initial values

toViewId	:: !Init !d! (Maybe d) -> d					// copy second on Set or if third is Nothing
toViewMap	:: !(d -> v) !Init !d !(Maybe v) -> v		// same, but convert to view domain

instance toBool Init
instance <  Lifespan
instance toString Lifespan 	
instance == Init, Mode, Lifespan
derive  gEq Init, Mode, Lifespan
