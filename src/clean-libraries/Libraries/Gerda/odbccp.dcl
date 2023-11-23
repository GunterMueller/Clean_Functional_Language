definition module odbccp;

import odbc;

ODBC_ADD_DSN:==1;
ODBC_CONFIG_DSN:==2;
ODBC_REMOVE_DSN:==3;
ODBC_ADD_SYS_DSN:==4;
ODBC_CONFIG_SYS_DSN:==5;
ODBC_REMOVE_SYS_DSN:==6;
ODBC_REMOVE_DEFAULT_DSN:==7;

SQLConfigDataSource :: !Int !Int !{#Char} !{#Char} !*SqlState -> (!Int, !*SqlState);
