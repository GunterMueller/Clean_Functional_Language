implementation module commentstest

import StdEnv

import Clean.Parse
import Clean.Parse.Comments
import Data.Error
import Data.Func
import Data.GenDiff
import System.CommandLine
from Text import class Text(replaceSubString,trim), instance Text String

import syntax

dcl = "commentstest.dcl"

Start w
# (Ok (mod,_), w) = readModule dcl w
# (Ok comments, w) = scanComments dcl w
# comments = collectComments comments mod 
# comments = list_comments mod comments
# diff = gDiff{|*|} expected comments
# (io,w) = stdio w
# io = io <<< diffToConsole diff <<< "\n"
# (_,w) = fclose io w
# w = let [d:_] = diff in case d.status of
	Common -> w
	_      -> setReturnCode -1 w
= w

expected :: [Entry]
expected =
	[ {kind="module",   name="commentstest",   value= ?Just "*\n * This module is used to test the Clean documentation parser in Clean.Parse.Comments.\n * The documentation here is written obscurely on purpose!\n *\n * //* this may trip the parser up\n "}
	, {kind="type",     name="NT",             value= ?None}
	, {kind="type",     name="Entry",          value= ?Just "* A documentation entry\n"}
	, {kind="selector",    name="kind",        value= ?Just "* the kind of thing that is documented\n"}
	, {kind="selector",    name="name",        value= ?Just "* the name of the documented thing\n"}
	, {kind="selector",    name="value",       value= ?None}
	, {kind="type",     name="R",              value= ?None}
	, {kind="selector",    name="f",           value= ?Just "* This is a comment on f, not Entry.value\n"}
	, {kind="type",     name="TrickyADT",      value= ?Just "* This type is just here to test; it isn't used\n"}
	, {kind="constructor", name="TrickyADT_A", value= ?Just "* Documentation on same line\n"}
	, {kind="constructor", name="TrickyADT_B", value= ?Just "* New constructor with matching column\n"}
	, {kind="constructor", name="TrickyADT_C", value= ?None}
	, {kind="constructor", name="TrickyADT_D", value= ?Just "* Documentation on new line\n* Extra documentation line\n"}
	, {kind="constructor", name="TrickyADT_E", value= ?Just "* Documentation on new line\n"}
	, {kind="typespec", name="list_comments",  value= ?None}
	]

derive gDiff Entry, ?

list_comments :: !ParsedModule !CollectedComments -> [Entry]
list_comments mod comments
# entry =
	{ kind  = "module"
	, name  = mod.mod_ident.id_name
	, value = getComment mod comments
	}
= [entry:list_comments_of_definitions mod.mod_defs comments]

list_comments_of_definitions :: ![ParsedDefinition] !CollectedComments -> [Entry]
list_comments_of_definitions [] _ = []
list_comments_of_definitions [pd:pds] comments = case pd of
	PD_Type {td_ident,td_rhs}
		# entry =
			{ kind = "type", name = td_ident.id_name
			, value = getComment pd comments
			}
		-> [entry:list_comments_of_type_rhs td_rhs comments ++
			list_comments_of_definitions pds comments]
	PD_TypeSpec _ id _ _ _
		# entry =
			{ kind = "typespec", name = id.id_name
			, value = getComment pd comments
			}
		-> [entry:list_comments_of_definitions pds comments]
	PD_Class cd _
		# entry =
			{ kind = "class", name = cd.class_ident.id_name
			, value = getComment pd comments
			}
		-> [entry:list_comments_of_definitions pds comments]
	PD_Generic gd
		# entry =
			{ kind = "generic", name = gd.gen_ident.id_name
			, value = getComment pd comments
			}
		-> [entry:list_comments_of_definitions pds comments]
	_
		-> list_comments_of_definitions pds comments

list_comments_of_type_rhs :: !RhsDefsOfType !CollectedComments -> [Entry]
list_comments_of_type_rhs rhs comments = case rhs of
	ConsList           pcs -> map (flip comment_of_constructor comments) pcs
	ExtensibleConses   pcs -> map (flip comment_of_constructor comments) pcs
	MoreConses _       pcs -> map (flip comment_of_constructor comments) pcs
	SelectorList _ _ _ pss -> map (flip comment_of_selector comments) pss
	TypeSpec _ -> []
	NewTypeCons _ -> []
	EmptyRhs _ -> []
	AbstractTypeSpec _ _ -> []
where
	comment_of_selector :: !ParsedSelector !CollectedComments -> Entry
	comment_of_selector ps comments =
		{ kind = "selector", name = ps.ps_field_ident.id_name
		, value = getComment ps comments
		}

	comment_of_constructor :: !ParsedConstructor !CollectedComments -> Entry
	comment_of_constructor pc comments =
		{ kind = "constructor", name = pc.pc_cons_ident.id_name
		, value = getComment pc comments
		}
