CC = gcc
CFLAGS = -O -fpic -fdelayed-branch -fno-function-cse \
			$(CINCLUDES) \
			-DSOLARIS
# -W -Wreturn-type -Wcomments
CINCLUDES = -I${OPENWINHOME}/include -I${OPENWINHOME}/include/Xol \
            -I${OPENWINHOME}/include/X11

OPENWINHOME = /usr/openwin

CMODULES = ckernel cdialog cfileselect cmenu cpicture ctimer cwindow cpath

OBJECTS = $(CMODULES:%=%.o)

#
# Default entry
#
default : $(OBJECTS)

#
# Compile section
#

$(DYNAMICLIBRARY) : $(OBJECTS)
	$(LD) $(LDSHARED) -o $@ $(OBJECTS)

$(STATICLIBRARY): $(OBJECTS)
	$(AR) r $@ $?
	$(RANLIB) $@

#
# Dependencies
#
ckernel.o : ckernel.c clean_devices.h
cdialog.o : cdialog.c clean_devices.h windowdata.h
cfileselect.o : cfileselect.c clean_devices.h
cmenu.o : cmenu.c clean_devices.h
cpicture.o : cpicture.c clean_devices.h windowdata.h
ctimer.o : ctimer.c clean_devices.h
cwindow.o: cwindow.c clean_devices.h windowdata.h mackeys.h
cpath.o: cpath.c clean_devices.h windowdata.h mackeys.h

#
# Clean up section
#
cleanup:
	$(RM) $(CMODULES:%=%.o)

#
# Commands
#
#RANLIB=ranlib
# Solaris:
RANLIB=/bin/true
# Solaris:
LDSHARED= -G
.SUFFIXES = .o .c

.c.o:
	echo Compiling $<
	$(CC) ${CFLAGS} -c $<
