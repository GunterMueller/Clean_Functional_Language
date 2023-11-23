definition module fbi

import	StdString
import	StdId
from	PmParse		import :: SearchKind
import	ExtListBox

// search dialog local data
// split out to avoid cyclic dependencies

:: FindBoxInfo p =
	{ dlogId		:: !Id				// search dialog id
	, intrId		:: !Id				// search dialog interrupt id
	, msgId			:: !Id				// info message id
	, findId		:: !Id
	, closeId		:: !Id
	, stringId		:: !Id
	, kind			:: !SearchKind
	, type			:: !SearchType
	, is_searching	:: !Bool			// currently searching?
	, cleanid		:: ![String]
	, verb			:: !Bool
	, export_		:: !Bool
	, windId		:: !Id				// search window id
	, windlbId		:: !ExtListBoxId p	// search win listbox id
	, src_offset	:: !Vector2
	, src_font		:: !Font
	, src_forg		:: !Colour
	, src_back		:: !Colour
	, src_size		:: !Size
	, pathname		:: !String
	, recvId		:: !RId Bool
	}

:: SearchType = SearchPaths | SearchImports | SearchProject

instance == SearchType
