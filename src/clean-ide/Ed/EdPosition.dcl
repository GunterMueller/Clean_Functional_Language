definition module EdPosition

from StdClass import class <, class ==, class toString

:: Position
	= { col		:: ColumnNr
	  , row		:: LineNr
	  }

:: ColumnNr	 :== Int
:: LineNr	 :== Int

instance < Position
instance == Position
instance toString Position
