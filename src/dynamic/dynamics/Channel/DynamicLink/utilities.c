#include "utilities.h"
#include "..\Utilities\Util.h"

void error() {
	LPVOID lpMsgBuf;
		
	FormatMessage( 
		FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM,    NULL,
		GetLastError(),
		MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), // Default language
		(LPTSTR) &lpMsgBuf,    0,    NULL );// Display the string.

	MessageBox( NULL, lpMsgBuf, "GetLastError", MB_OK|MB_ICONINFORMATION );
	LocalFree( lpMsgBuf );
}


void msg(char *lpMsgBuf)
{
	MessageBox( NULL, lpMsgBuf, "wwGetLastError", MB_OK|MB_ICONINFORMATION );
}

char *Reverse( char *s ) {

	int s_length;
	int even;
	int i;
	char swap;

	s_length = rstrlen(s);

	even = (s_length % 2 == 1) ? (s_length - 1) : s_length;

	for( i = 0; i < ((even / 2)); i++) {
		swap = s[i];
		s[i] = s[s_length-1-i];
		s[s_length-1-i] = swap;
	}

	return s;
}

int toString( DWORD v, char *s) {

	int i;
	//char *s1;

	//s1 = s;
	i = 0;
	while( v != 0 ) {
		s[i++] =  ((char) (v % 10)) + '0';
		v = v / 10;
	}

	if( i == 0 ) {
		rscopy(s, "0");
		return( 1 );
	}
	else { 
		s[i] = '\0';
		Reverse( s );
	}

	return( i );
}

int rsprintf( char *buffer, char *format, char *first) {

	va_list marker;
	int i;
	int j;
	char *s;
	DWORD d;

	// build string 
	va_start(marker,format);
	i = 0; j = 0;
	while( format[i] != '\0' ) {
		if( format[i] == '%' ) {
			switch( format[++i] ) {
			case 's':
				s = va_arg(marker,char *);
				rscopy(&buffer[j],s);
				j += rstrlen(s);
				break;

			case 'd':
				d = va_arg(marker,DWORD);
				j += toString(d, &buffer[j]);
				break;
				
			default:
				msg( "rsprintf: unknown escape seq" );
				return( 0 );
			}
			i++;
		}
		else {
			buffer[j++] = format[i++];
		}	
	}
	va_end(marker);

	buffer[j] = format[i];

	return( j );
}
