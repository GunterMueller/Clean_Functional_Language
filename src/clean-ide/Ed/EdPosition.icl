implementation module EdPosition

import StdClass, StdBool, StdInt, StdString

:: Position
	= { col		:: ColumnNr
	  , row		:: LineNr
	  }

:: ColumnNr	 :== Int
:: LineNr	 :== Int

// Positions can be tested for equality and ordering.

instance == Position where
  (==) { col=col1, row=row1 } { col=col2, row=row2 }
    = col1 == col2 && row1 == row2

instance < Position where
  (<) { col=col1, row=row1 } { col=col2, row=row2 }
    = row1 < row2 || (row1 == row2 && col1 < col2)

instance toString Position where
	toString {col,row} = "(" +++ toString row +++ "," +++ toString col +++ ")"
