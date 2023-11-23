This is the Clean iTask and iData library.


(c) 2006 / 2007 Rinus Plasmeijer


DO READ THIS READ ME !!!!!!



First of all: the iTask / iData library is still under development!
If you spot errors or have special wishes, please let me know: rinus@cs.ru.nl


Is has only been tested under windows, but in might work on any other machine Clean 2.2 
and the libraries I use is available on.



I. *** Install as follows:


1. You need the latest Clean system (version 2.2 or higher) for windows which can be downloaded
from our site (www.cs.ru.nl/~clean).
Install this system. It will generate a Clean 2.2 folder.
Put it anywhere, e.g. on your desktop.
Read the ReadMe that comes with the installation.
In particular, you have to launch the Clean IDE once. 
It will associate files with Clean extensions to the Clean IDE. That is all.

You can now work with Clean, but the iData library is not yet included in the latest version,
so you have to add this library yourself (points 3 - 5)


2. Move the htmlGEC library (containing the iData and iTask modules)
and the Gerda library (containing generic fynctions to store and retrieve Clean data into a relational database) 
into the folder Clean 2.2/Libraries.
You should now have all the required libraries.


3. In the Clean IDE menubar, choose Environment/import.
Now import the file htmlGEC/htmlExamples/Web Applications.env.
Make sure that hereafter in the Clean IDE Environment/Web Applications is selected.
The Clean IDE now knows which libraries to use for generating web applications.


4. Click on one of the .prj files of the html Examples, in the htmlExamples folder, e.g. Simple Workflows/coffeemachine.prj
Update the project: Project/Bring up to date.
Everything should compile without errrors, an application is generated.




Installation is now completed succesfully.



II *** Running a Clean web application.

To run a Clean webapplication you need a server on your machine.
There is an easy way to do it, and a hard way.
In the easy setting an http server will be linked with the Clean application.
In the other setting the Clean application will have to talk with an existing web server,
or one can use a Clean web server which is included in the software.
The software assumes that you hace an ODCB interface on your machine, which will be the case if you have installed Microsofts Access.
If this is not the case, see point 4.


Anyhow, you better start with the easy way:



*** Easy way


This mode is great for testing and playing.
A server which is written in Clean (of course) is included in the html library.
The server software has been written by Paul de Mast from the Polytechnical University,
Breda, The Netherlands. Thank you very much Paul!


1. Open one of the html examples in the htmlExample folder,
just by clicking on the .prj file, take e.g. Simple Workflows/coffeemachine.prj
The Clean IDE will be launched.
Make sure that the Environment/Web Applications is selected.


Make sure that the project Start rule looks like:

Start world = doHtmlServer .... world

If it says

Start world = doHtmlSubServer ... world

simply change doHtmlSubServer into doHtmlServer.

Now you are in the easy mode.


2. Choose from the menubar Project/Update and Run (Ctrl+r)

Everyting will be compiled, and the executable will be started showing a black command line window.

The application is both the server and it includes the generator of the html pages.
You can stop it as usual by closing the command line window.


3. Start your browser (e.g. Explorer) and choose:

http://localhost/clean

You will see the effect of the chosen example.

The browser might warn for all kinds of things, but you don't have to worry. It is quite safe.


4.In case it does not work:

The default settings of the system assume that you have installed a ODCB interface on your machine.
This is the case for instance when you have installed Microsoft Access or any other database system.
If you don't have this installed, you will get a run-time error in the black command line window complaining about missing ODCB stuf.
Without such standard database installed, the iData system cannot be used with the database option on.

You can switch the database option off:

In the file htmlSettings.dcl you find the following definitions:

class iSpecialStore a
				// OPTION: Comment out the next line if you do not have access to an ODCB database on your machine !!!!
	| gerda {|*|} , 	// To store and retrieve a value in a database
	  TC a			// To be able to store values in a dynamic

So, comment out the gerda line as follows:

//	| gerda {|*|} , 	// To store and retrieve a value in a database


Furthermore, changes the following lines:


// OPTION: Comment out the next line if you do not have access to an ODCB database on your machine !!!!
IF_GERDA gerda no_gerda :== gerda		// If database option is used

// OPTION: Remove the comment from the next line if you do not have access to an ODCB database on your machine !!!!
//IF_GERDA gerda no_gerda :== no_gerda	// otherwise, BUT manually flag of ", gerda{|*|}" in the class definition above


into

// OPTION: Comment out the next line if you do not have access to an ODCB database on your machine !!!!
//IF_GERDA gerda no_gerda :== gerda		// If database option is used

// OPTION: Remove the comment from the next line if you do not have access to an ODCB database on your machine !!!!
IF_GERDA gerda no_gerda :== no_gerda	// otherwise, BUT manually flag of ", gerda{|*|}" in the class definition above


Now the database option is switched off, and you can recompile by pressing Run (ctrl+r).
Make sure that you first close the black command window.


5. Now it should work.

There are some important things to be aware of.

- Depending on the options chosen for an iTask or iData, information is stored either on the Client side (Session or Page),
in a file (TxtFile(RO)), or in a relational database.

The files are stored in a directory "clean" created in the directory where the application is stored.
The database information is stored in "iDataDatabase.mdb" created in the directory where the application is stored.








*** Hard way

We are working on this variant.


There will be two options:

a. Install your own server and run the Clean application as a CGI script.

b. Install a special Clean server.
This special server can have several Clean applications running as CGI subservers.
This method has as advantage that you don't need big servers running on your machine and
you don't need to be afraid of virus attacks.


We are currently testing the system.



