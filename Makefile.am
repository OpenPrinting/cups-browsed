ACLOCAL_AMFLAGS = -I m4

doc_DATA = \
	ABOUT-NLS \
	AUTHORS \
	COPYING \
	CHANGES.md \
	CHANGES-1.x.md \
	INSTALL \
	README.md \
	DEVELOPING.md \
	CONTRIBUTING.md

EXTRA_DIST = \
	$(doc_DATA) \
	autogen.sh \
	config.rpath \
	utils/cups-browsed.service \
	utils/cups-browsed-upstart.conf

# =========
# utilities
# =========

pkgutilsdir = $(bindir)
pkgutils_PROGRAMS =

# ========
# Backends
# ========
pkgbackenddir = $(CUPS_SERVERBIN)/backend
pkgbackend_PROGRAMS = implicitclass

implicitclass_SOURCES = \
	backend/implicitclass.c
implicitclass_LDADD = \
	$(LIBCUPSFILTERS_LIBS) \
	$(LIBPPD_LIBS) \
	$(CUPS_LIBS)
implicitclass_CFLAGS = \
	$(LIBCUPSFILTERS_CFLAGS) \
	$(LIBPPD_CFLAGS) \
	$(CUPS_CFLAGS)

# ===========
# CUPS Config
# ===========
pkgcupsserverrootdir = $(CUPS_SERVERROOT)
pkgcupsserverroot_DATA = \
	utils/cups-browsed.conf

# =====
# UTILS
# =====

cups_notifier_sources = \
	cups-notifier.c \
	cups-notifier.h

$(cups_notifier_sources): utils/org.cups.cupsd.Notifier.xml
	gdbus-codegen \
	    --interface-prefix org.cups.cupsd \
	    --c-namespace Cups \
	    --generate-c-code cups-notifier \
	    utils/org.cups.cupsd.Notifier.xml

sbin_PROGRAMS = \
	cups-browsed
cups_browsed_SOURCES = \
	utils/cups-browsed.c
nodist_cups_browsed_SOURCES = \
	$(cups_notifier_sources)
cups_browsed_CFLAGS = \
	$(LIBCUPSFILTERS_CFLAGS) \
	$(LIBPPD_CFLAGS) \
	$(CUPS_CFLAGS) \
	$(AVAHI_CFLAGS) \
	$(AVAHI_GLIB_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GIO_UNIX_CFLAGS)
cups_browsed_CXXFLAGS = $(cups_browsed_CFLAGS)
cups_browsed_LDADD = \
	$(LIBCUPSFILTERS_LIBS) \
	$(LIBPPD_LIBS) \
	$(CUPS_LIBS) \
	$(AVAHI_LIBS) \
	$(AVAHI_GLIB_LIBS) \
	$(GLIB_LIBS) \
	$(GIO_LIBS) \
	$(GIO_UNIX_LIBS)
initrcdir = $(INITDDIR)
initrc_SCRIPTS = utils/cups-browsed

cupsbrowsedmanpages = \
	utils/cups-browsed.8 \
	utils/cups-browsed.conf.5
man_MANS = $(cupsbrowsedmanpages)

EXTRA_DIST += utils/cups-browsed.in \
	$(cupsbrowsedmanpages) \
	utils/org.cups.cupsd.Notifier.xml
BUILT_SOURCES = $(cups_notifier_sources)
CLEANFILES = $(BUILT_SOURCES) $(GENERATED_DEFS)

distclean-local:
	rm -rf *.cache *~

install-exec-hook:
	$(INSTALL) -d -m 755 $(DESTDIR)$(pkgbackenddir)

install-data-hook:
if RCLINKS
	for level in $(RCLEVELS); do \
		$(INSTALL) -d -m 755 $(DESTDIR)$(INITDIR)/rc$${level}.d; \
		$(LN_S) -f ../init.d/cups-browsed $(DESTDIR)$(INITDIR)/rc$${level}.d/S$(RCSTART)cups-browsed; \
		$(LN_S) -f ../init.d/cups-browsed $(DESTDIR)$(INITDIR)/rc$${level}.d/K$(RCSTOP)cups-browsed; \
	done; \
	$(INSTALL) -d -m 755 $(DESTDIR)$(INITDIR)/rc0.d; \
	$(LN_S) -f ../init.d/cups-browsed $(DESTDIR)$(INITDIR)/rc0.d/K$(RCSTOP)cups-browsed;
endif
	chmod 700 $(DESTDIR)/$(pkgbackenddir)/implicitclass

uninstall-hook:
if RCLINKS
	if test "x$(INITDIR)" != x; then \
		$(RM) $(DESTDIR)$(BUILDROOT)$(INITDIR)/rc?.d/[SK]??cups-browsed || :; \
		rmdir $(DESTDIR)$(BUILDROOT)$(INITDIR)/rc?.d || :;\
	fi
endif

SUBDIRS =
