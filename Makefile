# $Id: Makefile,v 1.1 2008-03-07 10:03:02 paumard Exp $
# these values filled in by    yorick -batch make.i
Y_MAKEDIR=
Y_EXE=
Y_EXE_PKGS=
Y_EXE_HOME=
Y_EXE_SITE=
Y_HOME_PKG=

# ----------------------------------------------------- optimization flags

# options for make command line, e.g.-   make COPT=-g TGT=exe
COPT=$(COPT_DEFAULT)
TGT=$(DEFAULT_TGT)

# ------------------------------------------------ macros for this package

PKG_NAME=cubeview
PKG_I=

OBJS=

# change to give the executable a name other than yorick
PKG_EXENAME=yorick

# PKG_DEPLIBS=-Lsomedir -lsomelib   for dependencies of this package
PKG_DEPLIBS=
# set compiler (or rarely loader) flags specific to this package
PKG_CFLAGS=
PKG_LDFLAGS=

# list of additional package names you want in PKG_EXENAME
# (typically Y_EXE_PKGS should be first here)
EXTRA_PKGS=$(Y_EXE_PKGS)

# list of additional files for clean
PKG_CLEAN=*test*.fits

# autoload file for this package, if any
PKG_I_START=cubeview_start.i
# non-pkg.i include files for this package, if any
PKG_I_EXTRA=cubeview.i bear.i

# -------------------------------- standard targets and rules (in Makepkg)

# set macros Makepkg uses in target and dependency names
# DLL_TARGETS, LIB_TARGETS, EXE_TARGETS
# are any additional targets (defined below) prerequisite to
# the plugin library, archive library, and executable, respectively
PKG_I_DEPS=$(PKG_I)
Y_DISTMAKE=distmake

include $(Y_MAKEDIR)/Make.cfg
include $(Y_MAKEDIR)/Makepkg
include $(Y_MAKEDIR)/Make$(TGT)

# override macros Makepkg sets for rules and other macros
# Y_HOME and Y_SITE in Make.cfg may not be correct (e.g.- relocatable)
Y_HOME=$(Y_EXE_HOME)
Y_SITE=$(Y_EXE_SITE)

# reduce chance of yorick-1.5 corrupting this Makefile
MAKE_TEMPLATE = protect-against-1.5

# ------------------------------------- targets and rules for this package

ywrap.c:
	touch ywrap.c

BIN_DIR=$(Y_HOME)/bin
MAN_DIR=$(Y_SITE)/man
DEST_BIN_DIR=$(DESTDIR)/$(BIN_DIR)
DEST_MAN_DIR=$(DESTDIR)/$(MAN_DIR)
DEST_PYTHON_DIR=$(DEST_Y_SITE)/python
DEST_GLADE_DIR=$(DEST_Y_SITE)/glade
DEST_PKG_INSTALLED_DIR=$(DEST_Y_SITE)/packages/installed

install::
	rm $(DEST_Y_HOME)/lib/cubeview.so
	-rmdir $(DEST_Y_HOME)/lib
	-rmdir $(DEST_Y_SITE)/i0
	mkdir -p $(DEST_BIN_DIR)
	cp cubeview $(DEST_BIN_DIR)
	chmod a+x $(DEST_BIN_DIR)/cubeview	
	mkdir -p $(DEST_PYTHON_DIR)
	cp cubeview.py $(DEST_PYTHON_DIR)
	chmod a+x $(DEST_PYTHON_DIR)/cubeview.py
	mkdir -p $(DEST_GLADE_DIR)
	cp cubeview.glade $(DEST_GLADE_DIR)
	mkdir -p $(DEST_MAN_DIR)/man1
	cp cubeview.1 $(DEST_MAN_DIR)/man1
	gzip -9 $(DEST_MAN_DIR)/man1/cubeview.1
	mkdir -p $(DEST_PKG_INSTALLED_DIR)
	cp cubeview.info $(DEST_PKG_INSTALLED_DIR)

# simple example:
#myfunc.o: myapi.h
# more complex example (also consider using PKG_CFLAGS above):
#myfunc.o: myapi.h myfunc.c
#	$(CC) $(CPPFLAGS) $(CFLAGS) -DMY_SWITCH -o $@ -c myfunc.c

# -------------------------------------------------------- end of Makefile
