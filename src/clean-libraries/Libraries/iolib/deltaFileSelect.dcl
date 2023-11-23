definition module deltaFileSelect;

from StdFile    import :: Files;
from deltaEventIO import :: IOState;

//	Version 0.8.3b

/*	With the functions defined in this module standard file selector
	dialogs can be opened, which provide a user-friendly way to select
	input or output files. The lay-out of these dialogs depends on the
	(version of the) operating system.
*/

    

SelectInputFile	:: !*s !(IOState *s)
						-> (!Bool,!String,!*s,!IOState *s);

/*	SelectInputFile opens a dialog in which the user can traverse the
	file system to select an existing file. The boolean result indicates
	whether the user pressed the Open button (TRUE) or the Cancel button
	(FALSE). The STRING result contains the complete pathname of the
	selected file. When Cancel was pressed an empty string will be
	returned. */

SelectOutputFile	:: !String !String !*s !(IOState *s)
						-> (!Bool,!String,!*s,!IOState *s);

/*	SelectOutputFile opens a dialog in which the user can specify the
	name of a file to write to in a certain directory. The first argument
	is the prompt of the dialog (default: "Save As:"), the second
	argument is the default filename. The boolean result indicates
	whether the user pressed the Save button (TRUE) or the Cancel button
	(FALSE). The STRING result contains the complete pathname of the
	selected file. When Cancel was pressed an empty string will be
	returned. When a file with the indicated name already exists in the
	indicated directory a confirm dialog will be opened. */
