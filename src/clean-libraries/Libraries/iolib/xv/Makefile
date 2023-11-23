CC = cc

CFLAGS =  -O $(CINCLUDES) -D_BSD_SOURCE -DSOLARIS -DOWTOOLKIT_WARNING_DISABLED 
# -Kpic
#CFLAGS = -O -fpic -fdelayed-branch -fno-function-cse 

# -W -Wreturn-type -Wcomments
CINCLUDES = -I${OPENWINHOME}/include -I${OPENWINHOME}/include/Xol \
#            -I${OPENWINHOME}/include/X11
# Linux:
#CINCLUDES = -I${OPENWINHOME}/include

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

DYNAMICLIBRARY = ../libCleanxv.so.1

$(DYNAMICLIBRARY) : $(OBJECTS)
	$(LD) $(LDSHARED) -o $@ $(OBJECTS)

STATICLIBRARY = ../libCleanxv.a

$(STATICLIBRARY): $(OBJECTS)
	$(AR) r $@ $?
	$(RANLIB) $@

#
# Clean up section
#
cleanup:
	$(RM) $(CMODULES:%=%.o)

#
# Commands
#
RANLIB = ranlib
# RANLIB = /bin/true
# LDSHARED = -G
.SUFFIXES = .o .c

.c.o:
	echo Compiling $<
	$(CC) ${CFLAGS} -c $<

# DO NOT DELETE

cdialog.o: interface.h clean_types.h windowdata.h ckernel.h clean_devices.h
cdialog.o: cwindow.h cpicture.h
cfileselect.o: interface.h clean_types.h ckernel.h clean_devices.h ctimer.h
cfileselect.o: cfileselect.h
ckernel.o: interface.h clean_types.h clean_devices.h ckernel.h ctimer.h
ckernel.o: cpicture.h windowdata.h cwindow.h cmenu.h cfileselect.h cdialog.h
cmenu.o: interface.h clean_types.h clean_devices.h windowdata.h cmenu.h
cmenu.o: ckernel.h cfileselect.h
cpath.o: interface.h clean_types.h ckernel.h clean_devices.h
cpicture.o: interface.h clean_types.h windowdata.h ckernel.h clean_devices.h
cpicture.o: cwindow.h
ctimer.o: interface.h clean_types.h clean_devices.h ctimer.h ckernel.h
cwindow.o: interface.h clean_types.h clean_devices.h mackeys.h windowdata.h
cwindow.o: ckernel.h cpicture.h cwindow.h cdialog.h cmenu.h
