definition module StdWebshop

import databaseHandler
import StdHtml

/**	webshopentry is the main function that creates the web shop.
	It does not depend on a specific database, but assumes the following interfaces:
		(1) opt     :: SearchOptions option;	these are the possible options a user can enter search strings for
		(2) extInfo :: ExtendedInfo d;			this presents extended information of a data item of type d
		(3) headers :: Headers      d;			these are the names of the headers by which a user browses through the database
		(4) database:: [ItemData    d];			these are the actual items of the database
*/
webshopentry :: (SearchOptions option) (ExtendedInfo d) (Headers d) [ItemData d] *HSt -> (Html,*HSt) | searchDB option d
