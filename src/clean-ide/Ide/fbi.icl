implementation module fbi

import StdString
import StdId, PmParse
import ExtListBox

:: FindBoxInfo p =
	{ dlogId		:: !Id
	, intrId		:: !Id
	, msgId			:: !Id
	, findId		:: !Id
	, closeId		:: !Id
	, stringId		:: !Id
	, kind			:: !SearchKind
	, type			:: !SearchType
	, is_searching	:: !Bool			// currently searching?
	, cleanid		:: ![String]
	, verb			:: !Bool
	, export_		:: !Bool
	, windId		:: !Id
	, windlbId		:: !ExtListBoxId p
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
where
	(==) SearchPaths SearchPaths = True
	(==) SearchImports SearchImports = True
	(==) SearchProject SearchProject = True
	(==) _ _ = False

