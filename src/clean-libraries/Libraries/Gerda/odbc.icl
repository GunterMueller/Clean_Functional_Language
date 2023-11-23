implementation module odbc;

import code from library "odbc_library";

import StdEnv;

:: SqlState:==Int;

openSqlState :: !*World -> (!*SqlState,*World);
openSqlState w = (0,w);

closeSqlState :: !*SqlState !*World -> *World;
closeSqlState _ w = w;

syncSqlState :: !*SqlState !*World -> (!*SqlState,*World);
syncSqlState s w = (s,w);

short_to_int i :== (i<<16)>>16;

SQLAllocHandle :: !SQLSMALLINT !SQLHANDLE !*SqlState -> (!SQLRETURN,!SQLHANDLE,!*SqlState);
SQLAllocHandle handleType inputHandle sql_state
	# (r,h)=SQLAllocHandle_ handleType inputHandle;
	= (short_to_int r,h,sql_state);

SQLAllocHandle_ :: !SQLSMALLINT !SQLHANDLE -> (!SQLRETURN,!SQLHANDLE);
SQLAllocHandle_ handleType inputHandle = code inline {
	ccall SQLAllocHandle@12 "PII:II"
}

SQLSetEnvAttr :: !SQLHENV !SQLINTEGER !SQLPOINTER !SQLINTEGER !*SqlState -> (!SQLRETURN,!*SqlState);
SQLSetEnvAttr environmentHandle attribute value stringLength sql_state
	= (short_to_int (SQLSetEnvAttr_ environmentHandle attribute value stringLength),sql_state);

SQLSetEnvAttr_ :: !SQLHENV !SQLINTEGER !SQLPOINTER !SQLINTEGER -> SQLRETURN;
SQLSetEnvAttr_ environmentHandle attribute value stringLength = code inline {
	ccall SQLSetEnvAttr@16 "PIIII:I"
}

SQLExecDirect :: !SQLHSTMT !{#Char} !SQLINTEGER !*SqlState -> (!SQLRETURN,!*SqlState);
SQLExecDirect statementHandle statementText textLength sql_state 
	= (short_to_int (SQLExecDirect_ statementHandle statementText textLength),sql_state);

SQLExecDirect_ :: !SQLHSTMT !{#Char} !SQLINTEGER -> SQLRETURN;
SQLExecDirect_ statementHandle statementText textLength = code inline {
	ccall SQLExecDirect@12 "PIsI:I"
}

SQLNumResultCols :: !SQLHSTMT !*SqlState -> (!SQLRETURN,!SQLSMALLINT,!*SqlState);
SQLNumResultCols statementHandle sql_state
	# (r,columnCount) = SQLNumResultCols_ statementHandle;
	= (short_to_int r,short_to_int columnCount,sql_state);

SQLNumResultCols_ :: !SQLHSTMT -> (!SQLRETURN,!SQLSMALLINT);
SQLNumResultCols_ statementHandle = code inline {
	ccall SQLNumResultCols@8 "PI:II"
}

SQLColAttributeString :: !SQLHSTMT !SQLUSMALLINT !SQLUSMALLINT !SQLSMALLINT !*SqlState -> (!SQLRETURN,!{#Char},!SQLSMALLINT,!*SqlState);
SQLColAttributeString statementHandle columnNumber fieldIdentifier bufferLength sql_state
	# characterAttribute = createArray bufferLength '\0'
	# (r,l,n)= SQLColAttribute_ statementHandle columnNumber fieldIdentifier characterAttribute bufferLength;
	# l=short_to_int l
	= (short_to_int r,resize_string characterAttribute l,l,sql_state);

SQLColAttribute :: !SQLHSTMT !SQLUSMALLINT !SQLUSMALLINT !SQLSMALLINT !*SqlState -> (!SQLRETURN,!{#Char},!SQLSMALLINT,!Int,!*SqlState);
SQLColAttribute statementHandle columnNumber fieldIdentifier bufferLength sql_state
	# characterAttribute = createArray bufferLength '\0'
	# (r,l,n)= SQLColAttribute_ statementHandle columnNumber fieldIdentifier characterAttribute bufferLength;
	= (short_to_int r,characterAttribute,short_to_int l,n,sql_state);

SQLColAttribute_ :: !SQLHSTMT !SQLUSMALLINT !SQLUSMALLINT !{#Char} !SQLSMALLINT -> (!SQLRETURN,!SQLSMALLINT,!Int);
SQLColAttribute_ statementHandle columnNumber fieldIdentifier characterAttribute bufferLength = code inline {
	ccall SQLColAttribute@28 "PIIIsI:III"
}

SQLColAttributeInt :: !SQLHSTMT !SQLUSMALLINT !SQLUSMALLINT !*SqlState -> (!SQLRETURN,!Int,!*SqlState);
SQLColAttributeInt statementHandle columnNumber fieldIdentifier sql_state
	# (r,l,n)= SQLColAttributeInt_ statementHandle columnNumber fieldIdentifier 0 0;
	= (short_to_int r,short_to_int n,sql_state);

SQLColAttributeInt_ :: !SQLHSTMT !SQLUSMALLINT !SQLUSMALLINT !Int !SQLSMALLINT -> (!SQLRETURN,!SQLSMALLINT,!Int);
SQLColAttributeInt_ statementHandle columnNumber fieldIdentifier characterAttribute bufferLength = code inline {
	ccall SQLColAttribute@28 "PIIIII:III"
}

SQLBindCol :: !SQLHSTMT !SQLUSMALLINT !SQLSMALLINT !SQLPOINTER !SQLINTEGER !SQLINTEGER !*SqlState -> (!SQLRETURN,!*SqlState);
SQLBindCol statementHandle columnNumber targetType targetValue bufferLength strLen_or_Ind sql_state
	= (short_to_int (SQLBindCol_ statementHandle columnNumber targetType targetValue bufferLength strLen_or_Ind),sql_state);

SQLBindCol_ :: !SQLHSTMT !SQLUSMALLINT !SQLSMALLINT !SQLPOINTER !SQLINTEGER !SQLINTEGER -> SQLRETURN;
SQLBindCol_ statementHandle columnNumber targetType targetValue bufferLength strLen_or_Ind = code inline {
	ccall SQLBindCol@24 "PIIIIII:I"
}

SQLFetch :: !SQLHSTMT !*SqlState -> (!SQLRETURN,!*SqlState);
SQLFetch statementHandle sql_state
	= (short_to_int (SQLFetch_ statementHandle),sql_state);

SQLFetch_ :: !SQLHSTMT -> SQLRETURN;
SQLFetch_ statementHandle = code inline {
	ccall SQLFetch@4 "PI:I"
}

SQLDisconnect :: !SQLHDBC !*SqlState -> (!SQLRETURN,!*SqlState);
SQLDisconnect connectionHandle sql_state
	= (short_to_int (SQLDisconnect_ connectionHandle),sql_state);

SQLDisconnect_ :: !SQLHDBC -> SQLRETURN;
SQLDisconnect_ connectionHandle = code inline {
	ccall SQLDisconnect@4 "PI:I"
}

SQLCancel :: !SQLHSTMT !*SqlState -> (!SQLRETURN,!*SqlState);
SQLCancel statementHandle sql_state
	= (short_to_int (SQLCancel_ statementHandle),sql_state);

SQLCancel_ :: !SQLHSTMT -> SQLRETURN;
SQLCancel_ statementHandle = code inline {
	ccall SQLCancel@4 "PI:I"
}

SQLCloseCursor :: !SQLHSTMT !*SqlState -> (!SQLRETURN,!*SqlState);
SQLCloseCursor statementHandle sql_state
	= (short_to_int (SQLCloseCursor_ statementHandle),sql_state);

SQLCloseCursor_ :: !SQLHSTMT -> SQLRETURN;
SQLCloseCursor_ statementHandle = code inline {
	ccall SQLCloseCursor@4 "PI:I"
}

SQLColumns :: !SQLHSTMT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !*SqlState -> (!SQLRETURN,!*SqlState);
SQLColumns statementHandle catalogName nameLength1 schemaName nameLength2 tableName nameLength3 columnName nameLength4 sql_state
	= (short_to_int (SQLColumns_ statementHandle catalogName nameLength1 schemaName nameLength2 tableName nameLength3 columnName nameLength4),sql_state);

SQLColumns_ :: !SQLHSTMT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT -> SQLRETURN;
SQLColumns_ statementHandle catalogName nameLength1 schemaName nameLength2 tableName nameLength3 columnName nameLength4 = code inline {
	ccall SQLColumns@36 "PIsIsIsIsI:I"
}

SQLConnect :: !SQLHDBC !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !*SqlState -> (!SQLRETURN,!*SqlState);
SQLConnect connectionHandle serverName nameLength1 userName nameLength2 authentication nameLength3 sql_state
	= (short_to_int (SQLConnect_ connectionHandle serverName nameLength1 userName nameLength2 authentication nameLength3),sql_state);

SQLConnect_ :: !SQLHDBC !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT -> SQLRETURN;
SQLConnect_ connectionHandle serverName nameLength1 userName nameLength2 authentication nameLength3 = code inline {
	ccall SQLConnect@28 "PIsIsIsI:I"
}

SQLCopyDesc :: !SQLHDESC !SQLHDESC !*SqlState -> (!SQLRETURN,!*SqlState);
SQLCopyDesc sourceDescHandle targetDescHandle sql_state
	= (short_to_int (SQLCopyDesc_ sourceDescHandle targetDescHandle),sql_state);

SQLCopyDesc_ :: !SQLHDESC !SQLHDESC -> SQLRETURN;
SQLCopyDesc_ sourceDescHandle targetDescHandle = code inline {
	ccall SQLCopyDesc@8 "PII:I"
}

SQLDataSources :: !SQLHENV !SQLUSMALLINT !SQLSMALLINT !SQLSMALLINT !*SqlState -> (!SQLRETURN,!{#Char},!SQLSMALLINT,!{#Char},!SQLSMALLINT,!*SqlState);
SQLDataSources environmentHandle direction bufferLength1 bufferLength2 sql_state
	# serverName = createArray bufferLength1 '\0';
	  nameLength1a = createArray 1 0;
	  description = createArray bufferLength2 '\0';
	  nameLength2a = createArray 1 0;
	  r = SQLDataSources_ environmentHandle direction serverName bufferLength1 nameLength1a description bufferLength2 nameLength2a;
	  nameLength1 = short_to_int nameLength1a.[0];
	  nameLength2 = short_to_int nameLength2a.[0];
	= (short_to_int r,resize_string serverName nameLength1,nameLength1,resize_string description nameLength2,nameLength2,sql_state);

SQLDataSources_ :: !SQLHENV !SQLUSMALLINT !{#Char} !SQLSMALLINT !{#Int} !{#Char} !SQLSMALLINT !{#Int} -> SQLRETURN;
SQLDataSources_ environmentHandle direction serverName bufferLength1 nameLength1 description bufferLength2 nameLength2 = code inline {
	ccall SQLDataSources@32 "PIIsIAsIA:I"
}

SQLDescribeCol :: !SQLHSTMT !SQLUSMALLINT !SQLSMALLINT !*SqlState -> (!SQLRETURN,!{#Char},!SQLSMALLINT,!SQLSMALLINT,!SQLUINTEGER,!SQLSMALLINT,!SQLSMALLINT,!*SqlState);
SQLDescribeCol statementHandle columnNumber bufferLength sql_state
	# columnName = createArray bufferLength '\0';
	  (r,nameLength,dataType,columnSize,decimalDigits,nullable) = SQLDescribeCol_ statementHandle columnNumber columnName bufferLength;
	  nameLength = short_to_int nameLength;
	  columnName = resize_string columnName nameLength;
	= (short_to_int r,columnName,nameLength,short_to_int dataType,columnSize,short_to_int decimalDigits,short_to_int nullable,sql_state);

SQLDescribeCol_ :: !SQLHSTMT !SQLUSMALLINT !{#Char} !SQLSMALLINT -> (!SQLRETURN,!SQLSMALLINT,!SQLSMALLINT,!SQLUINTEGER,!SQLSMALLINT,!SQLSMALLINT);
SQLDescribeCol_ statementHandle columnNumber columnName bufferLength = code inline {
	ccall SQLDescribeCol@36 "PIIsI:IIIIII"
}

SQLEndTran :: !SQLSMALLINT !SQLHANDLE !SQLSMALLINT !*SqlState -> (!SQLRETURN,!*SqlState);
SQLEndTran handleType handle completionType sql_state
	= (short_to_int (SQLEndTran_ handleType handle completionType),sql_state);

SQLEndTran_ :: !SQLSMALLINT !SQLHANDLE !SQLSMALLINT -> SQLRETURN;
SQLEndTran_ handleType handle completionType = code inline {
	ccall SQLEndTran@12 "PIII:I"
}

SQLExecute :: !SQLHSTMT !*SqlState -> (!SQLRETURN,!*SqlState);
SQLExecute statementHandle sql_state
	= (short_to_int (SQLExecute_ statementHandle),sql_state);

SQLExecute_ :: !SQLHSTMT -> SQLRETURN;
SQLExecute_ statementHandle = code inline {
	ccall SQLExecute@4 "PI:I"
}

SQLFetchScroll :: !SQLHSTMT !SQLSMALLINT !SQLINTEGER !*SqlState -> (!SQLRETURN,!*SqlState);
SQLFetchScroll statementHandle fetchOrientation fetchOffset sql_state
	= (short_to_int (SQLFetchScroll_ statementHandle fetchOrientation fetchOffset),sql_state);

SQLFetchScroll_ :: !SQLHSTMT !SQLSMALLINT !SQLINTEGER -> SQLRETURN;
SQLFetchScroll_ statementHandle fetchOrientation fetchOffset = code inline {
	ccall SQLFetchScroll@12 "PIII:I"
}

SQLFreeHandle :: !SQLSMALLINT !SQLHANDLE !*SqlState -> (!SQLRETURN,!*SqlState);
SQLFreeHandle handleType handle sql_state
	= (short_to_int (SQLFreeHandle_ handleType handle),sql_state);

SQLFreeHandle_ :: !SQLSMALLINT !SQLHANDLE -> SQLRETURN;
SQLFreeHandle_ handleType handle = code inline {
	ccall SQLFreeHandle@8 "PII:I"
}

SQLFreeStmt :: !SQLHSTMT !SQLUSMALLINT !*SqlState -> (!SQLRETURN,!*SqlState);
SQLFreeStmt statementHandle option sql_state
	= (short_to_int (SQLFreeStmt_ statementHandle option),sql_state);

SQLFreeStmt_ :: !SQLHSTMT !SQLUSMALLINT -> SQLRETURN;
SQLFreeStmt_ statementHandle option = code inline {
	ccall SQLFreeStmt@8 "PII:I"
}

SQLGetConnectAttr :: !SQLHDBC !SQLINTEGER !SQLINTEGER !*SqlState -> (!SQLRETURN,!{#Char},!SQLINTEGER,!*SqlState);
SQLGetConnectAttr connectionHandle attribute bufferLength sql_state
	# value = createArray bufferLength '\0';
	  (r,stringLength) = SQLGetConnectAttr_ connectionHandle attribute value bufferLength;
	= (short_to_int r,resize_string value stringLength,stringLength,sql_state);

SQLGetConnectAttr_ :: !SQLHDBC !SQLINTEGER !{#Char} !SQLINTEGER -> (!SQLRETURN,!SQLINTEGER);
SQLGetConnectAttr_ connectionHandle attribute value bufferLength = code inline {
	ccall SQLGetConnectAttr@20 "PIIsI:II"
}

SQLGetCursorName :: !SQLHSTMT !SQLSMALLINT !*SqlState -> (!SQLRETURN,!{#Char},!SQLSMALLINT,!*SqlState);
SQLGetCursorName statementHandle bufferLength sql_state
	# cursorName = createArray bufferLength '\0';
	  (r,nameLength) = SQLGetCursorName_ statementHandle cursorName bufferLength;
	  nameLength = short_to_int nameLength;
	= (short_to_int r,resize_string cursorName nameLength,nameLength,sql_state);

SQLGetCursorName_ :: !SQLHSTMT !{#Char} !SQLSMALLINT -> (!SQLRETURN,!SQLSMALLINT);
SQLGetCursorName_ statementHandle cursorName bufferLength = code inline {
	ccall SQLGetCursorName@20 "PIsI:II"
}

SQLGetData :: !SQLHSTMT !SQLUSMALLINT !SQLSMALLINT !SQLINTEGER !*SqlState -> (!SQLRETURN,!{#Char},!SQLINTEGER,!*SqlState);
SQLGetData statementHandle columnNumber targetType bufferLength sql_state
	# targetValue = createArray bufferLength '\0';
	  (r,strLen_or_Ind) = SQLGetData_ statementHandle columnNumber targetType targetValue bufferLength;
	  targetValue = resize_string targetValue strLen_or_Ind;
	= (short_to_int r,targetValue,strLen_or_Ind,sql_state);

SQLGetData_ :: !SQLHSTMT !SQLUSMALLINT !SQLSMALLINT !{#Char} !SQLINTEGER -> (!SQLRETURN,!SQLINTEGER);
SQLGetData_ statementHandle columnNumber targetType targetValue bufferLength = code inline {
	ccall SQLGetData@24 "PIIIsI:II"
}

SQLGetDescField :: !SQLHDESC !SQLSMALLINT !SQLSMALLINT !SQLINTEGER !*SqlState -> (!SQLRETURN,!{#Char},!SQLINTEGER,!*SqlState);
SQLGetDescField descriptorHandle recNumber fieldIdentifier bufferLength sql_state 
	# value = createArray bufferLength '\0';
	 (r,stringLength) = SQLGetDescField_ descriptorHandle recNumber fieldIdentifier value bufferLength;
	= (short_to_int r,resize_string value stringLength,stringLength,sql_state);

SQLGetDescField_  :: !SQLHDESC !SQLSMALLINT !SQLSMALLINT !{#Char} !SQLINTEGER -> (!SQLRETURN,!SQLINTEGER);
SQLGetDescField_ descriptorHandle recNumber fieldIdentifier value bufferLength = code inline {
	ccall SQLGetDescField@24 "PIIIsI:II"
}

SQLGetDescRec :: !SQLHDESC !SQLSMALLINT !SQLSMALLINT !*SqlState
				-> (!SQLRETURN,!{#Char},!SQLSMALLINT,!SQLSMALLINT,!SQLSMALLINT,!SQLINTEGER,!SQLSMALLINT,!SQLSMALLINT,!SQLSMALLINT,!*SqlState);
SQLGetDescRec descriptorHandle recNumber bufferLength sql_state
	# name = createArray bufferLength '\0';
	  (r,stringLength,type,subType,length,precision,scale,nullable)
		= SQLGetDescRec_ descriptorHandle recNumber name bufferLength;
	  stringLength=short_to_int stringLength;
	= (short_to_int r,resize_string name stringLength,stringLength,short_to_int type,short_to_int subType,
		length,short_to_int precision,short_to_int scale,short_to_int nullable,sql_state);

SQLGetDescRec_ :: !SQLHDESC !SQLSMALLINT !{#Char} !SQLSMALLINT
	-> (!SQLRETURN,!SQLSMALLINT,!SQLSMALLINT,!SQLSMALLINT,!SQLINTEGER,!SQLSMALLINT,!SQLSMALLINT,!SQLSMALLINT);
SQLGetDescRec_ descriptorHandle recNumber name bufferLength = code inline {
	ccall SQLGetDescRec@44 "PIIsI:IIIIIIII"
}

SQLGetDiagField :: !SQLSMALLINT !SQLHANDLE !SQLSMALLINT !SQLSMALLINT !SQLSMALLINT !*SqlState -> (!SQLRETURN,!{#Char},!SQLSMALLINT,!*SqlState);
SQLGetDiagField handleType handle recNumber diagIdentifier bufferLength sql_state
	# diagInfo = createArray bufferLength '\0';
	  (r,stringLength) = SQLGetDiagField_ handleType handle recNumber diagIdentifier diagInfo bufferLength;
	  stringLength = short_to_int stringLength;
	= (short_to_int r,resize_string diagInfo stringLength,stringLength,sql_state);

SQLGetDiagField_ :: !SQLSMALLINT !SQLHANDLE !SQLSMALLINT !SQLSMALLINT !{#Char} !SQLSMALLINT -> (!SQLRETURN,!SQLSMALLINT);
SQLGetDiagField_ handleType handle recNumber diagIdentifier diagInfo bufferLength = code inline {
	ccall SQLGetDiagField@28 "PIIIIsI:II"
}

SQLGetDiagRec :: !SQLSMALLINT !SQLHANDLE !SQLSMALLINT !SQLSMALLINT !*SqlState -> (!SQLRETURN,!{#Char},!Int,!{#Char},!SQLSMALLINT,!*SqlState);
SQLGetDiagRec handleType handle recNumber bufferLength sql_state
	# sqlstate = createArray 5 '\0';
	  nativeError = createArray 1 0;
	  messageText = createArray bufferLength '\0';
	  (r,textLength) = SQLGetDiagRec_ handleType handle recNumber sqlstate nativeError messageText bufferLength;
	  textLength = short_to_int textLength;
	= (short_to_int r,sqlstate,nativeError.[0],resize_string messageText textLength,textLength,sql_state);

SQLGetDiagRec_ :: !SQLSMALLINT !SQLHANDLE !SQLSMALLINT !{#Char} !{#Int} !{#Char} !SQLSMALLINT -> (!SQLRETURN,!SQLSMALLINT);
SQLGetDiagRec_ handleType handle recNumber sqlstate nativeError messageText bufferLength = code inline {
	ccall SQLGetDiagRec@32 "PIIIsAsI:II"
}

SQLGetEnvAttr :: !SQLHENV !SQLINTEGER !SQLINTEGER !*SqlState -> (!SQLRETURN,!{#Char},!SQLINTEGER,!*SqlState);
SQLGetEnvAttr environmentHandle attribute bufferLength sql_state
	# value = createArray bufferLength '\0';
	  (r,stringLength) = SQLGetEnvAttr_ environmentHandle attribute value bufferLength;
	= (short_to_int r,resize_string value stringLength,stringLength,sql_state);

SQLGetEnvAttr_ :: !SQLHENV !SQLINTEGER !{#Char} !SQLINTEGER -> (!SQLRETURN,!SQLINTEGER);
SQLGetEnvAttr_ environmentHandle attribute value bufferLength = code inline {
	ccall SQLGetEnvAttr@20 "PIIsI:II"
}

SQLGetFunctions :: !SQLHDBC !SQLUSMALLINT !*SqlState -> (!SQLRETURN,!SQLUSMALLINT,!*SqlState);
SQLGetFunctions connectionHandle functionId sql_state
	# (r,supported) = SQLGetFunctions_ connectionHandle functionId;
	= (short_to_int r,short_to_int supported,sql_state);

SQLGetFunctions_ :: !SQLHDBC !SQLUSMALLINT -> (!SQLRETURN,!SQLUSMALLINT);
SQLGetFunctions_ connectionHandle functionId = code inline {
	ccall SQLGetFunctions@12 "PII:II"
}

SQLGetInfo :: !SQLHDBC !SQLUSMALLINT !SQLSMALLINT !*SqlState -> (!SQLRETURN,!{#Char},!SQLSMALLINT,!*SqlState);
SQLGetInfo connectionHandle infoType bufferLength sql_state
	# infoValue = createArray bufferLength '\0';
	  (r,stringLength) = SQLGetInfo_ connectionHandle infoType infoValue bufferLength;
	  bufferLength = short_to_int bufferLength;
	= (short_to_int r,resize_string infoValue bufferLength,bufferLength,sql_state);

SQLGetInfo_ :: !SQLHDBC !SQLUSMALLINT !{#Char} !SQLSMALLINT -> (!SQLRETURN,!SQLSMALLINT);
SQLGetInfo_ connectionHandle infoType infoValue bufferLength = code inline {
	ccall SQLGetInfo@20 "PIIsI:II"
}

SQLGetStmtAttr :: !SQLHSTMT !SQLINTEGER !SQLINTEGER !*SqlState -> (!SQLRETURN,!{#Char},!SQLINTEGER,!*SqlState);
SQLGetStmtAttr statementHandle attribute bufferLength sql_state
	# value = createArray bufferLength '\0';
	  (r,stringLength) = SQLGetStmtAttr_ statementHandle attribute value bufferLength;
	  stringLength = short_to_int stringLength;
	= (short_to_int r,resize_string value stringLength,stringLength,sql_state);

SQLGetStmtAttr_ :: !SQLHSTMT !SQLINTEGER !{#Char} !SQLINTEGER -> (!SQLRETURN,!SQLINTEGER);
SQLGetStmtAttr_ statementHandle attribute value bufferLength = code inline {
	ccall SQLGetStmtAttr@20 "PIIsI:II"
}

SQLGetTypeInfo :: !SQLHSTMT !SQLSMALLINT !*SqlState -> (!SQLRETURN,!*SqlState);
SQLGetTypeInfo statementHandle dataType sql_state
	= (short_to_int (SQLGetTypeInfo_ statementHandle dataType),sql_state);

SQLGetTypeInfo_ :: !SQLHSTMT !SQLSMALLINT -> SQLRETURN;
SQLGetTypeInfo_ statementHandle dataType = code inline {
	ccall SQLGetTypeInfo@8 "PII:I"
}

SQLParamData :: !SQLHSTMT !*SqlState -> (!SQLRETURN,!SQLPOINTER,!*SqlState);
SQLParamData statementHandle sql_state
	# (r,p) = SQLParamData_ statementHandle;
	= (short_to_int r,p,sql_state);

SQLParamData_ :: !SQLHSTMT -> (!SQLRETURN,!SQLPOINTER);
SQLParamData_ statementHandle = code inline {
	ccall SQLParamData@8 "PI:II"
}

SQLPrepare :: !SQLHSTMT !{#Char} !SQLINTEGER !*SqlState -> (!SQLRETURN,!*SqlState);
SQLPrepare statementHandle statementText textLength sql_state
	= (short_to_int (SQLPrepare_ statementHandle statementText textLength),sql_state);

SQLPrepare_ :: !SQLHSTMT !{#Char} !SQLINTEGER -> SQLRETURN;
SQLPrepare_ statementHandle statementText textLength = code inline {
	ccall SQLPrepare@12 "PIsI:I"
}

SQLPutData :: !SQLHSTMT !{#Char} !SQLINTEGER !*SqlState -> (!SQLRETURN,!*SqlState);
SQLPutData statementHandle data strLen_or_Ind sql_state
	= (short_to_int (SQLPutData_ statementHandle data strLen_or_Ind),sql_state);

SQLPutData_ :: !SQLHSTMT !{#Char} !SQLINTEGER -> SQLRETURN;
SQLPutData_ statementHandle data strLen_or_Ind = code inline {
	ccall SQLPutData@12 "PIsI:I"
}

SQLRowCount :: !SQLHSTMT !*SqlState -> (!SQLRETURN,!SQLINTEGER,!*SqlState);
SQLRowCount statementHandle sql_state
	# (r,rowCount) = SQLRowCount_ statementHandle;
	= (short_to_int r,rowCount,sql_state);

SQLRowCount_ :: !SQLHSTMT -> (!SQLRETURN,!SQLINTEGER);
SQLRowCount_ statementHandle = code inline {
	ccall SQLRowCount@8 "PI:II"
}

SQLSetConnectAttr :: !SQLHDBC !SQLINTEGER !{#Char} !SQLINTEGER !*SqlState -> (!SQLRETURN,!*SqlState);
SQLSetConnectAttr connectionHandle attribute value stringLength sql_state
	= (short_to_int (SQLSetConnectAttr_ connectionHandle attribute value stringLength),sql_state);

SQLSetConnectAttr_ :: !SQLHDBC !SQLINTEGER !{#Char} !SQLINTEGER -> SQLRETURN;
SQLSetConnectAttr_ connectionHandle attribute value stringLength = code inline {
	ccall SQLSetConnectAttr@16 "PIIsI:I"
}

SQLSetCursorName :: !SQLHSTMT !{#Char} !SQLSMALLINT !*SqlState -> (!SQLRETURN,!*SqlState);
SQLSetCursorName statementHandle cursorName nameLength sql_state
	= (short_to_int (SQLSetCursorName_ statementHandle cursorName nameLength),sql_state);

SQLSetCursorName_ :: !SQLHSTMT !{#Char} !SQLSMALLINT -> SQLRETURN;
SQLSetCursorName_ statementHandle cursorName nameLength = code inline {
	ccall SQLSetCursorName@12 "PIsI:I"
}

SQLSetDescField :: !SQLHDESC !SQLSMALLINT !SQLSMALLINT !{#Char} !SQLINTEGER !*SqlState -> (!SQLRETURN,!*SqlState);
SQLSetDescField descriptorHandle recNumber fieldIdentifier value bufferLength sql_state
	= (short_to_int (SQLSetDescField_ descriptorHandle recNumber fieldIdentifier value bufferLength),sql_state);

SQLSetDescField_ :: !SQLHDESC !SQLSMALLINT !SQLSMALLINT !{#Char} !SQLINTEGER -> SQLRETURN;
SQLSetDescField_ descriptorHandle recNumber fieldIdentifier value bufferLength = code inline {
	ccall SQLSetDescField@20 "PIIIsI:I"
}

SQLSetDescRec :: !SQLHDESC !SQLSMALLINT !SQLSMALLINT !SQLSMALLINT !SQLINTEGER !SQLSMALLINT !SQLSMALLINT 
					!SQLPOINTER !Int !Int !*SqlState -> (!SQLRETURN,!Int,!Int,!*SqlState);
SQLSetDescRec descriptorHandle recNumber type subType length precision scale data stringLength indicator sql_state
	# stringLength = {stringLength};
	  indicator = {indicator};
	  r = SQLSetDescRec_ descriptorHandle recNumber type subType length precision scale data stringLength indicator;
	| r==r
		= (short_to_int r,stringLength.[0],indicator.[0],sql_state);

SQLSetDescRec_ :: !SQLHDESC !SQLSMALLINT !SQLSMALLINT !SQLSMALLINT !SQLINTEGER !SQLSMALLINT !SQLSMALLINT 
					!SQLPOINTER !{#Int} !{#Int} -> SQLRETURN;
SQLSetDescRec_ descriptorHandle recNumber type subType length precision scale data stringLength indicator = code inline {
	ccall SQLSetDescRec@40 "PIIIIIIIIAA:I"
}

SQLSetStmtAttr :: !SQLHSTMT !SQLINTEGER !{#Char} !SQLINTEGER !*SqlState -> (!SQLRETURN,!*SqlState);
SQLSetStmtAttr statementHandle attribute value stringLength sql_state
	= (short_to_int (SQLSetStmtAttr_ statementHandle attribute value stringLength),sql_state);

SQLSetStmtAttr_ :: !SQLHSTMT !SQLINTEGER !{#Char} !SQLINTEGER -> SQLRETURN;
SQLSetStmtAttr_ statementHandle attribute value stringLength = code inline {
	ccall SQLSetStmtAttr@16 "PIIsI:I"
}

SQLSpecialColumns :: !SQLHSTMT !SQLUSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT 
						!SQLUSMALLINT !SQLUSMALLINT !*SqlState -> (!SQLRETURN,!*SqlState);
SQLSpecialColumns statementHandle identifierType catalogName nameLength1 schemaName nameLength2 tableName nameLength3
					scope nullable sql_state
	= (short_to_int (SQLSpecialColumns_ statementHandle identifierType catalogName nameLength1 schemaName nameLength2
										tableName nameLength3 scope nullable),sql_state);

SQLSpecialColumns_ :: !SQLHSTMT !SQLUSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT 
						!SQLUSMALLINT !SQLUSMALLINT -> SQLRETURN;
SQLSpecialColumns_ statementHandle identifierType catalogName nameLength1 schemaName nameLength2 tableName nameLength3
					scope nullable = code inline {
	ccall SQLSpecialColumns@40 "PIIsIsIsIII:I"
}

SQLStatistics :: !SQLHSTMT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !SQLUSMALLINT !SQLUSMALLINT !*SqlState -> (!SQLRETURN,!*SqlState);
SQLStatistics statementHandle catalogName nameLength1 schemaName nameLength2 tableName nameLength3 unique reserved sql_state
	= (short_to_int (SQLStatistics_ statementHandle catalogName nameLength1 schemaName nameLength2 tableName nameLength3 unique reserved),sql_state);

SQLStatistics_ :: !SQLHSTMT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !SQLUSMALLINT !SQLUSMALLINT -> SQLRETURN;
SQLStatistics_ statementHandle catalogName nameLength1 schemaName nameLength2 tableName nameLength3 unique reserved = code inline {
	ccall SQLStatistics@36 "PIsIsIsIII:I"
}

SQLTables :: !SQLHSTMT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !*SqlState -> (!SQLRETURN,!*SqlState);
SQLTables statementHandle catalogName nameLength1 schemaName nameLength2 tableName nameLength3 tableType nameLength4 sql_state
	= (short_to_int (SQLTables_ statementHandle catalogName nameLength1 schemaName nameLength2 tableName nameLength3 tableType nameLength4),sql_state);

SQLTables_ :: !SQLHSTMT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT -> SQLRETURN;
SQLTables_ statementHandle catalogName nameLength1 schemaName nameLength2 tableName nameLength3 tableType nameLength4 = code inline {
	ccall SQLTables@36 "PIsIsIsIsI:I"
}

resize_string :: !{#Char} !Int -> {#Char};
resize_string string new_size
	= if (new_size>=0 && new_size<size string) (string % (0,new_size-1)) string;

// SQLAllocHandleStd is implemented to make SQLAllocHandle compatible with X/Open standard.
// An application should not call SQLAllocHandleStd directly.

SQLAllocHandleStd :: !SQLSMALLINT !SQLHANDLE -> (!SQLRETURN,!SQLHANDLE);
SQLAllocHandleStd fHandleType hInput
	# (r,hOutput)=SQLAllocHandleStd_ fHandleType hInput;
	= (short_to_int r,hOutput);

SQLAllocHandleStd_ :: !SQLSMALLINT !SQLHANDLE -> (!SQLRETURN,!SQLHANDLE);
SQLAllocHandleStd_ fHandleType hInput = code inline {
	ccall SQLAllocHandleStd@12 "PII:II"
}

SQLBindParameter :: !SQLHSTMT !SQLUSMALLINT !SQLSMALLINT !SQLSMALLINT !SQLSMALLINT !SQLUINTEGER !SQLSMALLINT !SQLPOINTER !SQLINTEGER !SQLPOINTER !*SqlState
					-> (!SQLRETURN,!*SqlState);
SQLBindParameter hstmt ipar fParamType fCType fSqlType cbColDef ibScale rgbValue cbValueMax pcbValue sql_state
	#!r = SQLBindParameter_ hstmt ipar fParamType fCType fSqlType cbColDef ibScale rgbValue cbValueMax pcbValue;
	= (short_to_int r,sql_state);

SQLBindParameter_ :: !SQLHSTMT !SQLUSMALLINT !SQLSMALLINT !SQLSMALLINT !SQLSMALLINT !SQLUINTEGER !SQLSMALLINT !SQLPOINTER !SQLINTEGER !SQLPOINTER
					-> SQLRETURN;
SQLBindParameter_ hstmt ipar fParamType fCType fSqlType cbColDef ibScale rgbValue cbValueMax pcbValue = code inline {
	ccall SQLBindParameter@40 "PIIIIIIIIII:I"
}

SQLBrowseConnect :: !SQLHDBC !{#Char} !SQLSMALLINT !SQLSMALLINT !*SqlState -> (!SQLRETURN,!{#Char},!SQLSMALLINT,!*SqlState);
SQLBrowseConnect hdbc connStrIn cbConnStrIn cbConnStrOutMax sql_state
	# connStrOut = createArray cbConnStrOutMax '\0';
	#! (r,cbConnStrOut) = SQLBrowseConnect_ hdbc connStrIn cbConnStrIn connStrOut cbConnStrOutMax;
	# cbConnStrOut=short_to_int cbConnStrOut;
	= (short_to_int r,resize_string connStrOut cbConnStrOut,cbConnStrOut,sql_state);

SQLBrowseConnect_ :: !SQLHDBC !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT -> (!SQLRETURN,!SQLSMALLINT);
SQLBrowseConnect_ hdbc connStrIn cbConnStrIn connStrOut cbConnStrOutMax = code inline {
	ccall SQLBrowseConnect@24 "PIsIsI:II"
}

SQLBulkOperations :: !SQLHSTMT !SQLSMALLINT !*SqlState -> (!SQLRETURN,!*SqlState);
SQLBulkOperations statementHandle operation sql_state
	= (short_to_int (SQLBulkOperations_ statementHandle operation),sql_state);

SQLBulkOperations_ :: !SQLHSTMT !SQLSMALLINT -> SQLRETURN;
SQLBulkOperations_ statementHandle operation = code inline {
	ccall SQLBulkOperations@8 "PII:I"
}

SQLColAttributes :: !SQLHSTMT !SQLUSMALLINT !SQLUSMALLINT !SQLSMALLINT !*SqlState -> (!SQLRETURN,!{#Char},!SQLSMALLINT,!SQLINTEGER,!*SqlState);
SQLColAttributes hstmt icol fDescType cbDescMax sql_state
	# rgbDesc = createArray cbDescMax '\0';
	#! (r,pcbDesc,pfDesc) = SQLColAttributes_ hstmt icol fDescType rgbDesc cbDescMax;
	# pcbDesc=short_to_int pcbDesc
	= (short_to_int r,resize_string rgbDesc pcbDesc,pcbDesc,pfDesc,sql_state);

SQLColAttributes_ :: !SQLHSTMT !SQLUSMALLINT !SQLUSMALLINT !{#Char} !SQLSMALLINT -> (!SQLRETURN,!SQLSMALLINT,!SQLINTEGER);
SQLColAttributes_ hstmt icol fDescType rgbDesc cbDescMax = code inline {
	ccall SQLColAttributes@28 "PIIIsI:III"
}

SQLColumnPrivileges :: !SQLHSTMT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !*SqlState -> (!SQLRETURN,!*SqlState);
SQLColumnPrivileges hstmt szCatalogName cbCatalogName szSchemaName cbSchemaName szTableName cbTableName szColumnName cbColumnName sql_state
	= (short_to_int (SQLColumnPrivileges_ hstmt szCatalogName cbCatalogName szSchemaName cbSchemaName szTableName cbTableName szColumnName cbColumnName),sql_state);

SQLColumnPrivileges_ :: !SQLHSTMT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT -> SQLRETURN;
SQLColumnPrivileges_ hstmt szCatalogName cbCatalogName szSchemaName cbSchemaName szTableName cbTableName szColumnName cbColumnName = code inline {
	ccall SQLColumnPrivileges@36 "PIsIsIsIsI:I"
}

SQLDescribeParam :: !SQLHSTMT !SQLUSMALLINT !*SqlState -> (!SQLRETURN,!SQLSMALLINT,!SQLUINTEGER,!SQLSMALLINT,!SQLSMALLINT,!*SqlState);
SQLDescribeParam hstmt ipar sql_state
	# (r,pfSqlType,pcbParamDef,pibScale,pfNullable) = SQLDescribeParam_ hstmt ipar;
	= (short_to_int r,short_to_int pfSqlType,pcbParamDef,short_to_int pibScale,short_to_int pfNullable,sql_state);

SQLDescribeParam_ :: !SQLHSTMT !SQLUSMALLINT -> (!SQLRETURN,!SQLSMALLINT,!SQLUINTEGER,!SQLSMALLINT,!SQLSMALLINT);
SQLDescribeParam_ hstmt ipar = code inline {
	ccall SQLDescribeParam@24 "PII:IIIII"
}

SQLDriverConnect :: !SQLHDBC !SQLHWND !{#Char} !SQLSMALLINT !SQLSMALLINT !SQLSMALLINT !*SqlState -> (!SQLRETURN,!{#Char},SQLSMALLINT,!*SqlState);
SQLDriverConnect hdbc hwnd connStrIn cbConnStrIn sizeConnStrOutBuffer fDriverCompletion sql_state
	# connStrOut = createArray sizeConnStrOutBuffer '\0';
	# connStrOutSize = createArray 1 0;
	#! r=SQLDriverConnect_ hdbc hwnd connStrIn cbConnStrIn connStrOut sizeConnStrOutBuffer connStrOutSize fDriverCompletion;
	# connStrOutSize = short_to_int connStrOutSize.[0];
	= (short_to_int r,resize_string connStrOut connStrOutSize,connStrOutSize,sql_state);

SQLDriverConnect_ :: !SQLHDBC !SQLHWND !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Int} !SQLSMALLINT -> SQLRETURN;
SQLDriverConnect_ hdbc hwnd szConnStrIn cbConnStrIn szConnStrOut cbConnStrOutMax pcbConnStrOut fDriverCompletion = code inline {
	ccall SQLDriverConnect@32 "PIIsIsIAI:I"
}

SQLDrivers :: !SQLHENV !SQLUSMALLINT !SQLSMALLINT !SQLSMALLINT !*SqlState -> (!SQLRETURN,!{#Char},!SQLSMALLINT,!{#Char},!SQLSMALLINT,!*SqlState);
SQLDrivers henv fDirection cbDriverDescMax cbDrvrAttrMax sql_state
	# szDriverDesc = createArray cbDriverDescMax '\0';
	# szDriverAttributes = createArray cbDrvrAttrMax '\0';
	# pcbDriverDesc = createArray 1 0;
	#! (r,pcbDrvrAttr)
		= SQLDrivers_ henv fDirection szDriverDesc cbDriverDescMax pcbDriverDesc szDriverAttributes cbDrvrAttrMax;
	# pcbDriverDesc = short_to_int pcbDriverDesc.[0];
	# pcbDrvrAttr = short_to_int pcbDrvrAttr;
	= (short_to_int r,resize_string szDriverDesc pcbDriverDesc,pcbDriverDesc,resize_string szDriverAttributes pcbDrvrAttr,pcbDrvrAttr,sql_state);

SQLDrivers_ :: !SQLHENV !SQLUSMALLINT !{#Char} !SQLSMALLINT !{#Int} !{#Char} !SQLSMALLINT -> (!SQLRETURN,!SQLSMALLINT);
SQLDrivers_ henv fDirection szDriverDesc cbDriverDescMax pcbDriverDesc szDriverAttributes cbDrvrAttrMax = code inline {
	ccall SQLDrivers@32 "PIIsIAsI:II"
}

SQLExtendedFetch :: !SQLHSTMT !SQLUSMALLINT !SQLINTEGER !*SqlState -> (!SQLRETURN,!SQLUINTEGER,!SQLUSMALLINT,!*SqlState);
SQLExtendedFetch hstmt fFetchType irow sql_state
	# (r,pcrow,rgfRowStatus) = SQLExtendedFetch_ hstmt fFetchType irow;
	= (short_to_int r,pcrow,short_to_int rgfRowStatus,sql_state);

SQLExtendedFetch_ :: !SQLHSTMT !SQLUSMALLINT !SQLINTEGER -> (!SQLRETURN,!SQLUINTEGER,!SQLUSMALLINT);
SQLExtendedFetch_ hstmt fFetchType irow = code inline {
	ccall SQLExtendedFetch@20 "PIII:III"
};

SQLForeignKeys :: !SQLHSTMT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char}!SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !*SqlState -> (!SQLRETURN,!*SqlState);
SQLForeignKeys hstmt szPkCatalogName cbPkCatalogName szPkSchemaName cbPkSchemaName szPkTableName cbPkTableName szFkCatalogName cbFkCatalogName szFkSchemaName cbFkSchemaName szFkTableName cbFkTableName sql_state
	= (short_to_int (SQLForeignKeys_ hstmt szPkCatalogName cbPkCatalogName szPkSchemaName cbPkSchemaName szPkTableName cbPkTableName szFkCatalogName cbFkCatalogName szFkSchemaName cbFkSchemaName szFkTableName cbFkTableName),sql_state);

SQLForeignKeys_ :: !SQLHSTMT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char}!SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT -> SQLRETURN;
SQLForeignKeys_ hstmt szPkCatalogName cbPkCatalogName szPkSchemaName cbPkSchemaName szPkTableName cbPkTableName szFkCatalogName cbFkCatalogName szFkSchemaName cbFkSchemaName szFkTableName cbFkTableName = code inline {
	ccall SQLForeignKeys@52 "PIsIsIsIsIsIsI:I"
}

SQLMoreResults :: !SQLHSTMT !*SqlState -> (!SQLRETURN,!*SqlState);
SQLMoreResults hstmt sql_state
	= (short_to_int (SQLMoreResults_ hstmt),sql_state);

SQLMoreResults_ :: !SQLHSTMT -> SQLRETURN;
SQLMoreResults_ hstmt = code inline {
	ccall SQLMoreResults@4 "PI:I"
}

SQLNativeSql :: !SQLHDBC !{#Char} !SQLINTEGER !SQLINTEGER !*SqlState -> (!SQLRETURN,!{#Char},!SQLINTEGER,!*SqlState);
SQLNativeSql hdbc szSqlStrIn cbSqlStrIn cbSqlStrMax sql_state
	# szSqlStr = createArray cbSqlStrMax '\0';
	#! (r,pcbSqlStr) = SQLNativeSql_ hdbc szSqlStrIn cbSqlStrIn szSqlStr cbSqlStrMax;
	= (short_to_int r,resize_string szSqlStr pcbSqlStr,pcbSqlStr,sql_state);

SQLNativeSql_ :: !SQLHDBC !{#Char} !SQLINTEGER !{#Char} !SQLINTEGER -> (!SQLRETURN,!SQLINTEGER);
SQLNativeSql_ hdbc szSqlStrIn cbSqlStrIn szSqlStr cbSqlStrMax = code inline {
	ccall SQLNativeSql@24 "PIsIsI:II"
}

SQLNumParams :: !SQLHSTMT !*SqlState -> (!SQLRETURN,!SQLSMALLINT,!*SqlState);
SQLNumParams hstmt sql_state
	# (r,pcpar) = SQLNumParams_ hstmt;
	= (short_to_int r,short_to_int pcpar,sql_state);

SQLNumParams_ :: !SQLHSTMT -> (!SQLRETURN,!SQLSMALLINT);
SQLNumParams_ hstmt = code inline {
	ccall SQLNumParams@8 "PI:II"
};

SQLPrimaryKeys :: !SQLHSTMT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !*SqlState -> (!SQLRETURN,!*SqlState);
SQLPrimaryKeys hstmt szCatalogName cbCatalogName szSchemaName cbSchemaName szTableName cbTableName sql_state
	= (short_to_int (SQLPrimaryKeys_ hstmt szCatalogName cbCatalogName szSchemaName cbSchemaName szTableName cbTableName),sql_state);

SQLPrimaryKeys_ :: !SQLHSTMT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT -> SQLRETURN;
SQLPrimaryKeys_ hstmt szCatalogName cbCatalogName szSchemaName cbSchemaName szTableName cbTableName = code inline {
	ccall SQLPrimaryKeys@28 "PIsIsIsI:I"
};

SQLProcedureColumns :: !SQLHSTMT !{#Char}!SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !*SqlState -> (!SQLRETURN,!*SqlState);
SQLProcedureColumns hstmt szCatalogName cbCatalogName szSchemaName cbSchemaName szProcName cbProcName szColumnName cbColumnName sql_state
	= (short_to_int (SQLProcedureColumns_ hstmt szCatalogName cbCatalogName szSchemaName cbSchemaName szProcName cbProcName szColumnName cbColumnName),sql_state);

SQLProcedureColumns_ :: !SQLHSTMT !{#Char}!SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT -> SQLRETURN;
SQLProcedureColumns_ hstmt szCatalogName cbCatalogName szSchemaName cbSchemaName szProcName cbProcName szColumnName cbColumnName = code inline {
	ccall SQLProcedureColumns@36 "PIsIsIsIsI:I"
}

SQLProcedures :: !SQLHSTMT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !*SqlState -> (!SQLRETURN,!*SqlState);
SQLProcedures hstmt szCatalogName cbCatalogName szSchemaName cbSchemaName szProcName cbProcName sql_state
	= (short_to_int (SQLProcedures_ hstmt szCatalogName cbCatalogName szSchemaName cbSchemaName szProcName cbProcName),sql_state);

SQLProcedures_ :: !SQLHSTMT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT -> SQLRETURN;
SQLProcedures_ hstmt szCatalogName cbCatalogName szSchemaName cbSchemaName szProcName cbProcName = code inline {
	ccall SQLProcedures@28 "PIsIsIsI:I"
}

SQLSetPos :: !SQLHSTMT !SQLUSMALLINT !SQLUSMALLINT !SQLUSMALLINT !*SqlState -> (!SQLRETURN,!*SqlState);
SQLSetPos hstmt irow fOption fLock sql_state
	= (short_to_int (SQLSetPos_ hstmt irow fOption fLock),sql_state);

SQLSetPos_ :: !SQLHSTMT !SQLUSMALLINT !SQLUSMALLINT !SQLUSMALLINT -> SQLRETURN;
SQLSetPos_ hstmt irow fOption fLock = code inline {
	ccall SQLSetPos@16 "PIIII:I"
}

SQLTablePrivileges :: !SQLHSTMT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !*SqlState -> (!SQLRETURN,!*SqlState);
SQLTablePrivileges hstmt szCatalogName cbCatalogName szSchemaName cbSchemaName szTableName cbTableName sql_state
	= (short_to_int (SQLTablePrivileges_ hstmt szCatalogName cbCatalogName szSchemaName cbSchemaName szTableName cbTableName),sql_state);

SQLTablePrivileges_ :: !SQLHSTMT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT !{#Char} !SQLSMALLINT -> SQLRETURN;
SQLTablePrivileges_ hstmt szCatalogName cbCatalogName szSchemaName cbSchemaName szTableName cbTableName = code inline {
	ccall SQLTablePrivileges@28 "PIsIsIsI:I"
}
