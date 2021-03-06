##
##  This is the Makefile for lumail.
##
##  It is a little more complex than it should be because of the main requirement
## that we build both "lumail" and "lumail-debug" with the same sources.
##
##  Because the debug-version of the code requires different CPPFLAGS we cannot
## just compile once.  So instead we must have two object directories; one for each
## set of flags.
##
##  To cut down on manual updates though we look for src/*.cc and compile everything
## en mass.
##
##  If you're running `ccache` then the overhead of double-compilation
## should be insignificant.
##
##  Steve
##  --
##



#
#  Source + Object + Binary directories
#
SRCDIR         = src
RELEASE_OBJDIR = obj.release
DEBUG_OBJDIR   = obj.debug

#
#  Used solely for building a new release tarball.  ("make release").
#
TMP?=/tmp
BASE=lumail
DIST_PREFIX=${TMP}
VERSION=$(shell sh -c 'git describe --abbrev=0 --tags | tr -d "release-"')

#
#  Basics
#
CC=g++
LINKER=$(CC) -o
LVER=lua5.1
CPPFLAGS+=-std=gnu++0x -Wall -Werror $(shell pkg-config --cflags ${LVER}) $(shell pcre-config --cflags) -I/usr/include/ncursesw/
LDLIBS+=$(shell pkg-config --libs ${LVER}) -lncursesw -lpcrecpp

#
#  GMime is used for MIME handling.
#
GMIME_LIBS=$(shell pkg-config --libs  gmime-2.6)
GMIME_INC=$(shell pkg-config --cflags gmime-2.6)

#
# UTF-8-aware string handling.
#
GLIBMM_LIBS=$(shell pkg-config --libs  glibmm-2.4)
GLIBMM_INC=$(shell pkg-config --cflags glibmm-2.4)

#
#  Build both targets by default.
#
default: lumail lumail-debug


#
#  Style-check our code
#
.PHONY: style
style:
	prove --shuffle ./style/

#
#  Make a release
#
release: clean style
	rm -rf $(DIST_PREFIX)/$(BASE)-$(VERSION)
	rm -f $(DIST_PREFIX)/$(BASE)-$(VERSION).tar.gz
	cp -R . $(DIST_PREFIX)/$(BASE)-$(VERSION)
	rm -rf $(DIST_PREFIX)/$(BASE)-$(VERSION)/debian
	rm -rf $(DIST_PREFIX)/$(BASE)-$(VERSION)/.git*
	rm -rf $(DIST_PREFIX)/$(BASE)-$(VERSION)/.depend || true
	perl -pi -e "s/__UNRELEASED__/$(VERSION)/g" $(DIST_PREFIX)/$(BASE)-$(VERSION)/src/version.h
	cd $(DIST_PREFIX) && tar -cvf $(DIST_PREFIX)/$(BASE)-$(VERSION).tar $(BASE)-$(VERSION)/
	gzip $(DIST_PREFIX)/$(BASE)-$(VERSION).tar
	mv $(DIST_PREFIX)/$(BASE)-$(VERSION).tar.gz .
	rm -rf $(DIST_PREFIX)/$(BASE)-$(VERSION)



#
#  Cleanup
#
clean:
	test -d $(RELEASE_OBJDIR)  && rm -rf $(RELEASE_OBJDIR) || true
	test -d $(DEBUG_OBJDIR)    && rm -rf $(DEBUG_OBJDIR)   || true
	rm -f gmon.out lumail lumail-debug core                || true
	@cd util && make clean                                 || true

#
#  Sources + objects.
#
SOURCES         := $(wildcard $(SRCDIR)/*.cc)
RELEASE_OBJECTS := $(SOURCES:$(SRCDIR)/%.cc=$(RELEASE_OBJDIR)/%.o)
DEBUG_OBJECTS   := $(SOURCES:$(SRCDIR)/%.cc=$(DEBUG_OBJDIR)/%.o)


#
#  The release-build.
#
lumail: $(RELEASE_OBJECTS)
	$(LINKER) $@ $(LFLAGS) $(RELEASE_OBJECTS) $(LDLIBS) $(GMIME_LIBS) $(GLIBMM_LIBS)

#
#  The debug-build.
#
lumail-debug: $(DEBUG_OBJECTS)
	$(LINKER) $@ $(LFLAGS) -rdynamic -ggdb -pg $(DEBUG_OBJECTS) $(LDLIBS) $(GMIME_LIBS) $(GLIBMM_LIBS)


#
#  Build the objects for the release build.
#
$(RELEASE_OBJECTS): $(RELEASE_OBJDIR)/%.o : $(SRCDIR)/%.cc
	@mkdir $(RELEASE_OBJDIR) 2>/dev/null || true
	$(CC)  $(CPPFLAGS) $(GMIME_INC) $(GLIBMM_INC) -O2 -c $< -o $@

#
#  Build the objects for the debug build.
#
#  Just define "LUMAIL_DEBUG=1", otherwise share the flags.
#
$(DEBUG_OBJECTS): $(DEBUG_OBJDIR)/%.o : $(SRCDIR)/%.cc
	@mkdir $(DEBUG_OBJDIR) 2>/dev/null || true
	$(CC) -ggdb -DLUMAIL_DEBUG=1 $(CPPFLAGS) $(GMIME_INC) $(GLIBMM_INC) -O2 -c $< -o $@

