#
#	Makefile for the Clean Standard Environment
#

#
#		make (= make stdenv):
#			compiles all modules
#
#		make install:
#			compiles all modules
#			copies files to install directory
#
#		make cleanup:
#			removes all files in this directory that can be recreated
#

CLEAN_MODULES = \
	StdArray StdCharList StdClass StdDebug StdFunc StdList \
	StdOrdList StdOverloaded StdTuple _SystemEnum StdEnum StdEnv

SYSTEM_MODULES = \
	StdBool StdChar StdFile StdInt StdMisc StdReal \
	StdString _SystemArray

ABC_MODULES = \
	_system

OBJECT_MODULES = \
	_startup

SYSTEM_OBJECT_MODULES = \
	_reals crt crti crtn

CLEAN_MODULES_ABC = $(CLEAN_MODULES:%=Clean\ System\ Files/%.abc)

SYSTEM_MODULES_ABC = $(SYSTEM_MODULES:%=Clean\ System\ Files/%.abc)

SYSTEM_MODULES_ICL = $(SYSTEM_MODULES:%=%.icl)

ABC_MODULES_ABC = $(ABC_MODULES:%=Clean\ System\ Files/%.abc)

CLEAN_MODULES_O = $(CLEAN_MODULES:%=Clean\ System\ Files/%.o)

SYSTEM_MODULES_O = $(SYSTEM_MODULES:%=Clean\ System\ Files/%.o)

ABC_MODULES_O = $(ABC_MODULES:%=Clean\ System\ Files/%.o)

OBJECT_MODULES_O = $(OBJECT_MODULES:%=Clean\ System\ Files/%.o)

SYSTEM_OBJECT_MODULES_O = $(SYSTEM_OBJECT_MODULES:%=Clean\ System\ Files/%.o)

STDENV_FILES = \
	$(CLEAN_MODULES:%=%.icl) \
	$(CLEAN_MODULES:%=%.dcl) \
	$(SYSTEM_MODULES:%=%.dcl) \
	$(SYSTEM_MODULES_ABC) \
	$(CLEAN_MODULES_ABC) \
	$(ABC_MODULES_ABC) \
	wait1 \
	$(SYSTEM_MODULES_O) \
	$(CLEAN_MODULES_O) \
	$(ABC_MODULES_O) \
	$(OBJECT_MODULES_O) \
	$(SYSTEM_OBJECT_MODULES_O)

wait1:
	sleep 1

#
# Compile
#

stdenv: $(STDENV_FILES)

#
# Install
#
# the order here is important, because the files will be
# installed in the order given below.

INSTALL_STDENV_FILES = \
	$(CLEAN_MODULES:%=$(INSTALL_STDENV_DIR)/%.icl) \
	$(CLEAN_MODULES:%=$(INSTALL_STDENV_DIR)/%.dcl) \
	$(SYSTEM_MODULES:%=$(INSTALL_STDENV_DIR)/%.dcl) \
	$(ABC_MODULES:%=$(INSTALL_STDENV_DIR)/%.dcl) \
	$(OBJECT_MODULES:%=$(INSTALL_STDENV_DIR)/%.dcl) \
	$(SYSTEM_MODULES:%=$(INSTALL_STDENV_DIR)/Clean\ System\ Files/%.abc) \
	$(CLEAN_MODULES:%=$(INSTALL_STDENV_DIR)/Clean\ System\ Files/%.abc) \
	$(ABC_MODULES:%=$(INSTALL_STDENV_DIR)/Clean\ System\ Files/%.abc) \
	wait2 \
	$(SYSTEM_MODULES:%=$(INSTALL_STDENV_DIR)/Clean\ System\ Files/%.o) \
	$(CLEAN_MODULES:%=$(INSTALL_STDENV_DIR)/Clean\ System\ Files/%.o) \
	$(ABC_MODULES:%=$(INSTALL_STDENV_DIR)/Clean\ System\ Files/%.o) \
	$(OBJECT_MODULES:%=$(INSTALL_STDENV_DIR)/Clean\ System\ Files/%.o) \
	$(SYSTEM_OBJECT_MODULES:%=$(INSTALL_STDENV_DIR)/Clean\ System\ Files/%.o) \
	$(INSTALL_STDENV_DIR)/Clean\ System\ Files/libCleanxv.a

install: stdenv $(INSTALL_STDENV_DIR) $(INSTALL_STDENV_DIR)/Clean\ System\ Files $(INSTALL_STDENV_FILES)

wait2:
	sleep 1

$(INSTALL_STDENV_DIR) : 
	mkdir -p "$@"

$(INSTALL_STDENV_DIR)/Clean\ System\ Files : 
	mkdir -p "$@"

$(INSTALL_STDENV_DIR)/% : %
	cp "$<" "$@"
	chmod 644 "$@"

$(INSTALL_STDENV_DIR)/Clean\ System\ Files/libCleanxv.a :
	$(RM) $(INSTALL_STDENV_DIR)/Clean\ System\ Files/libCleanxv.a; \
	if test -f ../../iolib/libCleanvx.a; \
 	then ln -fs ../../iolib/libCleanxv.a $(INSTALL_STDENV_DIR)/Clean\ System\ Files/libCleanxv.a; \
	else touch ../../libCleanxv.a; ln -fs ../../iolib/libCleanxv.a $(INSTALL_STDENV_DIR)/Clean\ System\ Files/libCleanxv.a; rm ../../libCleanxv.a; \
	fi

#
# Cleanup
#

cleanup:
	$(RM) $(CLEAN_MODULES_ABC) \
	$(RM) $(CLEAN_MODULES_O) \
	$(RM) $(SYSTEM_MODULES_O) \
	$(RM) $(ABC_MODULES_O)

#
# Commands
#

CLM = clm -P .
CLMFLAGS =

.SUFFIXES: .abc .dcl .icl .o

.icl.abc:
	$(CLM) $(CLMFLAGS) -ABC $*

.icl.o:
	$(CLM) $(CLMFLAGS) -O `basename "$*" .icl`

.abc.o:
	$(CLM) $(CLMFLAGS) -O `basename "$*" .icl`


Clean\ System\ Files/StdArray.o : StdArray.icl StdArray.dcl
	$(CLM) -O StdArray

Clean\ System\ Files/StdArray.abc : StdArray.icl StdArray.dcl
	$(CLM) -ABC StdArray

Clean\ System\ Files/StdCharList.o : StdCharList.icl StdCharList.dcl
	$(CLM) -O StdCharList

Clean\ System\ Files/StdCharList.abc : StdCharList.icl StdCharList.dcl
	$(CLM) -ABC StdCharList

Clean\ System\ Files/StdClass.o : StdClass.icl StdClass.dcl
	$(CLM) -O StdClass

Clean\ System\ Files/StdClass.abc : StdClass.icl StdClass.dcl
	$(CLM) -ABC StdClass

Clean\ System\ Files/StdDebug.o : StdDebug.icl StdDebug.dcl
	$(CLM) -O StdDebug

Clean\ System\ Files/StdDebug.abc : StdDebug.icl StdDebug.dcl
	$(CLM) -ABC StdDebug

Clean\ System\ Files/StdEnum.o : StdEnum.icl StdEnum.dcl
	$(CLM) -O StdEnum

Clean\ System\ Files/StdEnum.abc : StdEnum.icl StdEnum.dcl
	$(CLM) -ABC StdEnum

Clean\ System\ Files/StdEnv.o : StdEnv.icl StdEnv.dcl
	$(CLM) -O StdEnv

Clean\ System\ Files/StdEnv.abc : StdEnv.icl StdEnv.dcl
	$(CLM) -ABC StdEnv

Clean\ System\ Files/StdFunc.o : StdFunc.icl StdFunc.dcl
	$(CLM) -O StdFunc

Clean\ System\ Files/StdFunc.abc : StdFunc.icl StdFunc.dcl
	$(CLM) -ABC StdFunc

Clean\ System\ Files/StdList.o : StdList.icl StdList.dcl
	$(CLM) -O StdList

Clean\ System\ Files/StdList.abc : StdList.icl StdList.dcl
	$(CLM) -ABC StdList

Clean\ System\ Files/StdOrdList.o : StdOrdList.icl StdOrdList.dcl
	$(CLM) -O StdOrdList

Clean\ System\ Files/StdOrdList.abc : StdOrdList.icl StdOrdList.dcl
	$(CLM) -ABC StdOrdList

Clean\ System\ Files/StdOverloaded.o : StdOverloaded.icl StdOverloaded.dcl
	$(CLM) -O StdOverloaded

Clean\ System\ Files/StdOverloaded.abc : StdOverloaded.icl StdOverloaded.dcl
	$(CLM) -ABC StdOverloaded

Clean\ System\ Files/StdTuple.o : StdTuple.icl StdTuple.dcl
	$(CLM) -O StdTuple

Clean\ System\ Files/StdTuple.abc : StdTuple.icl StdTuple.dcl
	$(CLM) -ABC StdTuple

Clean\ System\ Files/_SystemEnum.o : _SystemEnum.icl _SystemEnum.dcl
	$(CLM) -O _SystemEnum

Clean\ System\ Files/_SystemEnum.abc : _SystemEnum.icl _SystemEnum.dcl
	$(CLM) -ABC _SystemEnum

Clean\ System\ Files/StdBool.o : StdBool.dcl Clean\ System\ Files/StdBool.abc
	$(CLM) -O StdBool

Clean\ System\ Files/StdBool.abc : StdBool.icl StdBool.dcl
	$(CLM) -ABC StdBool

Clean\ System\ Files/StdChar.o : StdChar.dcl Clean\ System\ Files/StdChar.abc
	$(CLM) -O StdChar

Clean\ System\ Files/StdChar.abc : StdChar.icl StdChar.dcl
	$(CLM) -ABC StdChar

Clean\ System\ Files/StdFile.o : StdFile.dcl Clean\ System\ Files/StdFile.abc
	$(CLM) -O StdFile

Clean\ System\ Files/StdFile.abc : StdFile.icl StdFile.dcl
	$(CLM) -ABC StdFile

Clean\ System\ Files/StdInt.o : StdInt.dcl Clean\ System\ Files/StdInt.abc
	$(CLM) -O StdInt

Clean\ System\ Files/StdInt.abc : StdInt.icl StdInt.dcl
	$(CLM) -ABC StdInt

Clean\ System\ Files/StdMisc.o : StdMisc.dcl Clean\ System\ Files/StdMisc.abc
	$(CLM) -O StdMisc

Clean\ System\ Files/StdMisc.abc : StdMisc.icl StdMisc.dcl
	$(CLM) -ABC StdMisc

Clean\ System\ Files/StdReal.o : StdReal.dcl Clean\ System\ Files/StdReal.abc
	$(CLM) -O StdReal

Clean\ System\ Files/StdReal.abc : StdReal.icl StdReal.dcl
	$(CLM) -ABC StdReal

Clean\ System\ Files/StdString.o : StdString.dcl Clean\ System\ Files/StdString.abc
	$(CLM) -O StdString

Clean\ System\ Files/StdString.abc : StdString.icl StdString.dcl
	$(CLM) -ABC StdString

Clean\ System\ Files/_SystemArray.o : _SystemArray.dcl Clean\ System\ Files/_SystemArray.abc
	$(CLM) -O _SystemArray

Clean\ System\ Files/_SystemArray.abc : _SystemArray.icl _SystemArray.dcl
	$(CLM) -ABC _SystemArray

Clean\ System\ Files/_system.o : Clean\ System\ Files/_system.abc
	$(CLM) -O _system

# compile system modules twice, to make sure all inlining is done
system_abc: $(SYSTEM_MODULES_ABC) system_abc_touch

system_abc_touch:
	touch $(SYSTEM_MODULES_ICL)
	$(MAKE) system_abc_again

system_abc_again: $(SYSTEM_MODULES_ABC)
