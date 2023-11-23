OPENWINHOME=/usr/openwin
DEFAULT_TOOLKIT = xv

# Sun:
# TOOLKITS = olit xv
# Linux:
TOOLKITS = xv

INTERFACE_MODULES = \
	xcursor xfileselect xpath xdialog \
	xkernel xpicture xwindow xmenu xtimer

CLEAN_MODULES = \
	deltaControls deltaFont deltaPicture \
	deltaDialog deltaIOState deltaSystem \
	deltaEventIO deltaIOSystem deltaTimer \
	deltaFileSelect deltaMenu deltaWindow \
	commonDef dialogDef menuDef timerDef \
	windowDef dialogDevice menuDevice timerDevice \
	windowDevice cursorInternal ioState scrollList scrollList sliderBar misc \
	picture xevent xtypes

XV_OBJECT_FILES = \
	xv/cdialog.o \
	xv/cpath.o \
	xv/cfileselect.o \
  	xv/cpicture.o \
	xv/ckernel.o \
	xv/ctimer.o \
	xv/cmenu.o \
	xv/cwindow.o

# Link options files
LO_FILES = \
	x.lo \
	$(TOOLKITS:%=%.lo)

LIBRARY_MODULES = \
	libCleanIO \
	$(TOOLKITS:%=libClean%)

# Static and Dynamic Libraries
LIBRARIES = \
	$(LIBRARY_MODULES:%=%.a)
#	$(LIBRARY_MODULES:%=%.so.1.0) \

# Links to versions of shared libraries
# SHARED_LIB_LINKS = 
#	$(LIBRARY_MODULES:%=%.so)

IOLIB_FILES = \
	$(CLEAN_MODULES:%=%.dcl) \
	$(INTERFACE_MODULES:%=%.dcl) \
	$(CLEAN_MODULES:%=%.icl) \
	$(INTERFACE_MODULES:%=%.icl) \
	$(LO_FILES) \
	$(SHARED_LIB_LINKS) \
	$(LIBRARIES) \
	$(XV_OBJECT_FILES)

#
# Install section
#

# INSTALL_IOLIB_DIR = $(CURRENTDIR)
INSTALL_IOLIB_FILES = $(IOLIB_FILES:%=$(INSTALL_IOLIB_DIR)/%)
INSTALL_SHARED_LIB_LINKS = $(SHARED_LIB_LINKS:%=$(INSTALL_IOLIB_DIR)/%)

install: compile $(INSTALL_IOLIB_DIR) $(INSTALL_IOLIB_DIR)/xv $(INSTALL_IOLIB_FILES) \
											$(INSTALL_SHARED_LIB_LINKS)

$(INSTALL_IOLIB_DIR) :
	mkdir -p $@

$(INSTALL_IOLIB_DIR)/xv :
	mkdir -p $@

$(INSTALL_IOLIB_DIR)/% : %
	cp $< $@
	chmod 644 $@


CURRENTDIR = $(MAKECURRENTDIR)$(GMAKECURRENTDIR)
MAKECURRENTDIR : sh=pwd
GMAKECURRENTDIR = ${shell echo `pwd`}

#
# Compile section
#
compile: $(LIBRARIES)

CLEAN_MODULES_O = $(CLEAN_MODULES:%=Clean\ System\ Files/%.o)
CLEAN_MODULES_O_ = $(CLEAN_MODULES:%=%.o)
INTERFACE_MODULES_O = $(INTERFACE_MODULES:%=Clean\ System\ Files/%.o)
INTERFACE_MODULES_O_ = $(INTERFACE_MODULES:%=%.o)

CLEAN_MODULES_ABC = $(CLEAN_MODULES:%=Clean\ System\ Files/%.abc)
INTERFACE_MODULES_ABC = $(INTERFACE_MODULES:%=Clean\ System\ Files/%.abc)

libCleanIO.so.1.0: $(INTERFACE_MODULES_O) $(CLEAN_MODULES_O)
	$(LD) $(LDSHARED) -o $@ $(INTERFACE_MODULES_O) $(CLEAN_MODULES_O)

libCleanIO.a: $(INTERFACE_MODULES_O) $(CLEAN_MODULES_O)
	(cd "Clean System Files" ; $(AR) r ../$@ $(INTERFACE_MODULES_O_) $(CLEAN_MODULES_O_) ; cd ..)
	$(RANLIB) $@

$(TOOLKITS:%=libClean%.a): 
	cd $(@:libClean%.a=%); $(MAKE) ../$@ STATICLIBRARY=../$@ 

$(TOOLKITS:%=libClean%.so.1.0): 
	cd $(@:libClean%.so.1.0=%); $(MAKE) ../$@ DYNAMICLIBRARY=../$@ 

#
# Clean up section
#
cleanup:
	$(RM) $(INTERFACE_MODULES:%=%.icl) $(INTERFACE_MODULES:%=%.dcl) \
			$(INTERFACE_MODULES_ABC) $(INTERFACE_MODULES:%=%.o)
	$(RM) $(CLEAN_MODULES_ABC) $(CLEAN_MODULES_O)
	$(RM) $(LIBRARIES)
	$(RM) $(LO_FILES) $(SHARED_LIB_LINKS)
	for dir in $(TOOLKITS); do cd $$dir; $(MAKE) $@; cd ..; done; exit 0

#
#
# Generate the *.lo files
#
#	delimiter used in the sed patterns, this character may *not*
#	appear in the expansions of $(IOLIB) and $(OPENWINLIB)
DEL = %

OPENWINLIB = $(OPENWINHOME)/lib
IOLIB = $(INSTALL_IOLIB_DIR)

$(INSTALL_IOLIB_DIR)/olit.lo: olit/x.lo.in
	sed -e s\$(DEL)'$$CLEANIOLIB'$(DEL)$(IOLIB)$(DEL)g $? | \
	sed -e s\$(DEL)'$$OPENWINLIB'$(DEL)$(OPENWINLIB)$(DEL)g > $@

$(INSTALL_IOLIB_DIR)/olits.lo: olit/xs.lo.in
	sed -e s\$(DEL)'$$CLEANIOLIB'$(DEL)$(IOLIB)$(DEL)g $? | \
	sed -e s\$(DEL)'$$OPENWINLIB'$(DEL)$(OPENWINLIB)$(DEL)g > $@

$(INSTALL_IOLIB_DIR)/xv.lo: xv/x.lo.in
	sed -e s\$(DEL)'$$CLEANIOLIB'$(DEL)$(IOLIB)$(DEL)g $? | \
	sed -e s\$(DEL)'$$OPENWINLIB'$(DEL)$(OPENWINLIB)$(DEL)g > $@

$(INSTALL_IOLIB_DIR)/xvs.lo: xv/xs.lo.in
	sed -e s\$(DEL)'$$CLEANIOLIB'$(DEL)$(IOLIB)$(DEL)g $? | \
	sed -e s\$(DEL)'$$OPENWINLIB'$(DEL)$(OPENWINLIB)$(DEL)g > $@

$(INSTALL_IOLIB_DIR)/libCleanIO.so: $(INSTALL_IOLIB_DIR)/libCleanIO.so.1.0
	$(RM) $@ ; ln -s $? $@
$(INSTALL_IOLIB_DIR)/libCleanxv.so: $(INSTALL_IOLIB_DIR)/libCleanxv.so.1.0
	$(RM) $@ ; ln -s $? $@
$(INSTALL_IOLIB_DIR)/libCleanolit.so: $(INSTALL_IOLIB_DIR)/libCleanolit.so.1.0
	$(RM) $@ ; ln -s $? $@

$(INSTALL_IOLIB_DIR)/x.lo: $(INSTALL_IOLIB_DIR)/$(DEFAULT_TOOLKIT).lo
	$(RM) $@ ; ln -s $? $@
$(INSTALL_IOLIB_DIR)/xs.lo: $(INSTALL_IOLIB_DIR)/$(DEFAULT_TOOLKIT)s.lo
	$(RM) $@ ; ln -s $? $@

#
# Commands
#

.SUFFIXES: .fcl .h .icl .dcl .abc .o

RANLIB = ranlib
# RANLIB = /bin/true
FCLC = fclc
HTOCLEAN = htoclean 
CLM = clm
CLMFLAGS = -nw

# Solaris:
# LDSHARED = -G

.h.dcl:
	$(HTOCLEAN) $<

.h.icl:
	$(HTOCLEAN) $<

.fcl.o:
	$(FCLC) $<
	$(CLM) $(CLMFLAGS) -O $*

.fcl.dcl:
	$(FCLC) $<

.fcl.icl:
	$(FCLC) $<

.icl.abc:
	$(CLM) $(CLMFLAGS) -ABC $*

.icl.o:
	$(CLM) $(CLMFLAGS) -O $*

.abc.o:
	$(CLM) $(CLMFLAGS) -O $*


xcursor.icl : xcursor.h

xcursor.dcl : xcursor.h

Clean\ System\ Files/xcursor.o : xcursor.icl xcursor.dcl
	$(RM) Clean\ System\ Files/xcursor.abc
	$(CLM) -nw -O xcursor

xfileselect.icl : xfileselect.h

xfileselect.dcl : xfileselect.h

Clean\ System\ Files/xfileselect.o : xfileselect.icl xfileselect.dcl
	$(RM) Clean\ System\ Files/xfileselect.abc
	$(CLM) -nw -O xfileselect

xpath.icl : xpath.h

xpath.dcl : xpath.h

Clean\ System\ Files/xpath.o : xpath.icl xpath.dcl
	$(RM) Clean\ System\ Files/xpath.abc
	$(CLM) -nw -O xpath

xdialog.icl : xdialog.h

xdialog.dcl : xdialog.h

Clean\ System\ Files/xdialog.o : xdialog.icl xdialog.dcl
	$(RM) Clean\ System\ Files/xdialog.abc
	$(CLM) -nw -O xdialog

xkernel.icl : xkernel.h

xkernel.dcl : xkernel.h

Clean\ System\ Files/xkernel.o : xkernel.icl xkernel.dcl
	$(RM) Clean\ System\ Files/xkernel.abc
	$(CLM) -nw -O xkernel

xpicture.icl : xpicture.h

xpicture.dcl : xpicture.h

Clean\ System\ Files/xpicture.o : xpicture.icl xpicture.dcl
	$(RM) Clean\ System\ Files/xpicture.abc
	$(CLM) -nw -O xpicture

xwindow.icl : xwindow.h

xwindow.dcl : xwindow.h

Clean\ System\ Files/xwindow.o : xwindow.icl xwindow.dcl
	$(RM) Clean\ System\ Files/xwindow.abc
	$(CLM) -nw -O xwindow

xmenu.icl : xmenu.h

xmenu.dcl : xmenu.h

Clean\ System\ Files/xmenu.o : xmenu.icl xmenu.dcl
	$(RM) Clean\ System\ Files/xmenu.abc
	$(CLM) -nw -O xmenu

xtimer.icl : xtimer.h

xtimer.dcl : xtimer.h

Clean\ System\ Files/xtimer.o : xtimer.icl xtimer.dcl
	$(RM) Clean\ System\ Files/xtimer.abc
	$(CLM) -nw -O xtimer

Clean\ System\ Files/deltaControls.o : deltaControls.icl deltaControls.dcl
	$(CLM) -nw -O deltaControls

Clean\ System\ Files/deltaFont.o : deltaFont.icl deltaFont.dcl
	$(CLM) -nw -O deltaFont

Clean\ System\ Files/deltaPicture.o : deltaPicture.icl deltaPicture.dcl
	$(CLM) -nw -O deltaPicture

Clean\ System\ Files/deltaDialog.o : deltaDialog.icl deltaDialog.dcl
	$(CLM) -nw -O deltaDialog

Clean\ System\ Files/deltaIOState.o : deltaIOState.icl deltaIOState.dcl
	$(CLM) -nw -O deltaIOState

Clean\ System\ Files/deltaSystem.o : deltaSystem.icl deltaSystem.dcl
	$(CLM) -nw -O deltaSystem

Clean\ System\ Files/deltaEventIO.o : deltaEventIO.icl deltaEventIO.dcl
	$(CLM) -nw -O deltaEventIO

Clean\ System\ Files/deltaIOSystem.o : deltaIOSystem.icl deltaIOSystem.dcl
	$(CLM) -nw -O deltaIOSystem

Clean\ System\ Files/deltaTimer.o : deltaTimer.icl deltaTimer.dcl
	$(CLM) -nw -O deltaTimer

Clean\ System\ Files/deltaFileSelect.o : deltaFileSelect.icl deltaFileSelect.dcl
	$(CLM) -nw -O deltaFileSelect

Clean\ System\ Files/deltaMenu.o : deltaMenu.icl deltaMenu.dcl
	$(CLM) -nw -O deltaMenu

Clean\ System\ Files/deltaWindow.o : deltaWindow.icl deltaWindow.dcl
	$(CLM) -nw -O deltaWindow

Clean\ System\ Files/commonDef.o : commonDef.icl commonDef.dcl
	$(CLM) -nw -O commonDef

Clean\ System\ Files/dialogDef.o : dialogDef.icl dialogDef.dcl
	$(CLM) -nw -O dialogDef

Clean\ System\ Files/menuDef.o : menuDef.icl menuDef.dcl
	$(CLM) -nw -O menuDef

Clean\ System\ Files/timerDef.o : timerDef.icl timerDef.dcl
	$(CLM) -nw -O timerDef

Clean\ System\ Files/windowDef.o : windowDef.icl windowDef.dcl
	$(CLM) -nw -O windowDef

Clean\ System\ Files/dialogDevice.o : dialogDevice.icl dialogDevice.dcl
	$(CLM) -nw -O dialogDevice

Clean\ System\ Files/menuDevice.o : menuDevice.icl menuDevice.dcl
	$(CLM) -nw -O menuDevice

Clean\ System\ Files/timerDevice.o : timerDevice.icl timerDevice.dcl
	$(CLM) -nw -O timerDevice

Clean\ System\ Files/windowDevice.o : windowDevice.icl windowDevice.dcl
	$(CLM) -nw -O windowDevice

Clean\ System\ Files/cursorInternal.o : cursorInternal.icl cursorInternal.dcl
	$(CLM) -nw -O cursorInternal

Clean\ System\ Files/ioState.o : ioState.icl ioState.dcl
	$(CLM) -nw -O ioState

Clean\ System\ Files/scrollList.o : scrollList.icl scrollList.dcl
	$(CLM) -nw -O scrollList

Clean\ System\ Files/sliderBar.o : sliderBar.icl sliderBar.dcl
	$(CLM) -nw -O sliderBar

Clean\ System\ Files/misc.o : misc.icl misc.dcl
	$(CLM) -nw -O misc

Clean\ System\ Files/picture.o : picture.icl picture.dcl
	$(CLM) -nw -O picture

Clean\ System\ Files/xevent.o : xevent.icl xevent.dcl
	$(CLM) -nw -O xevent

Clean\ System\ Files/xtypes.o : xtypes.icl xtypes.dcl
	$(CLM) -nw -O xtypes
