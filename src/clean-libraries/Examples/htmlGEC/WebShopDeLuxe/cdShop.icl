module cdShop

import CDdatabaseHandler
import StdWebshop

// demo application showing a web shop programmed in Clean using the iData - HtmlGec library
// MJP 2005

Start :: *World -> *World
Start world 
	# (database,world) = readDB world									// read the database (lazily)
//	= doHtml (webshopentry options extendedinfo headers database) world	// goto the main page
	= doHtmlServer (webshopentry options extendedinfo headers database) world	// goto the main page
where
	options :: SearchOptions CDSearch
	options = searchOptions
	
	extendedinfo :: ExtendedInfo CD
	extendedinfo = extendedInfoDB
	
	headers :: Headers CD
	headers = headersDB
