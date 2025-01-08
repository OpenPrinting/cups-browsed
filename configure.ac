# Process this file with autoconf to create configure.

AC_PREREQ([2.65])

# ====================
# Version informations
# ====================
AC_INIT([cups-browsed], [2.1.1], [https://github.com/OpenPrinting/cups-browsed/issues], [cups-browsed], [https://github.com/OpenPrinting/cups-browsed/])
cups_browsed_version="AC_PACKAGE_VERSION"
cups_browsed_version_major="`echo AC_PACKAGE_VERSION | awk -F. '{print $1}'`"
cups_browsed_version_major="`echo AC_PACKAGE_VERSION | awk -F. '{printf("%d\n",$2);}'`"

# =============
# Automake init
# =============
AC_CONFIG_MACRO_DIR([m4])
m4_include([m4/ac_define_dir.m4])
m4_include([m4/ax_compare_version.m4])
m4_include([m4/basic-directories.m4])
AM_INIT_AUTOMAKE([1.11 gnu dist-xz dist-bzip2 subdir-objects foreign])
AM_SILENT_RULES([yes])
AC_LANG([C])
AC_CONFIG_HEADERS([config.h])
# Extra defines for the config.h
AH_BOTTOM([
#ifdef HAVE_LONG_LONG
#  define CUPS_LLFMT   "%lld"
#  define CUPS_LLCAST  (long long)
#else
#  define CUPS_LLFMT   "%ld"
#  define CUPS_LLCAST  (long)
#endif /* HAVE_LONG_LONG */

#ifdef HAVE_ARC4RANDOM
#  define CUPS_RAND() arc4random()
#  define CUPS_SRAND(v) arc4random_stir()
#elif defined(HAVE_RANDOM)
#  define CUPS_RAND() random()
#  define CUPS_SRAND(v) srandom(v)
#elif defined(HAVE_LRAND48)
#  define CUPS_RAND() lrand48()
#  define CUPS_SRAND(v) srand48(v)
#else
#  define CUPS_RAND() rand()
#  define CUPS_SRAND(v) srand(v)
#endif /* HAVE_ARC4RANDOM */
])

# ===========================
# Find required base packages
# ===========================
AC_PROG_CC
AM_PROG_CC_C_O
AM_ICONV
AC_PROG_INSTALL
AC_PROG_LN_S
AC_PROG_MAKE_SET
LT_INIT
PKG_PROG_PKG_CONFIG([0.20])

AM_GNU_GETTEXT_VERSION([0.18.3])
AM_GNU_GETTEXT([external])

# ================================
# Find CUPS internals (no pc file)
# ================================
AC_ARG_WITH([cups-config],
	[AS_HELP_STRING([--with-cups-config=path], [Specify path to cups-config executable.])],
	[with_cups_config="$withval"],
	[with_cups_config=system]
)

AS_IF([test "x$with_cups_config" != "xsystem"], [
	CUPSCONFIG=$with_cups_config
], [
	AC_PATH_TOOL(CUPSCONFIG, [cups-config])
	AS_IF([test -z "$CUPSCONFIG"], [
		AC_MSG_ERROR([Required cups-config is missing. Please install CUPS developer packages.])
	])
])
CUPS_CFLAGS=`$CUPSCONFIG --cflags`
CUPS_LIBS=`$CUPSCONFIG --image --libs`
CUPS_VERSION=`$CUPSCONFIG --version`
AC_SUBST(CUPS_CFLAGS)
AC_SUBST(CUPS_LIBS)

CUPS_DATADIR="`$CUPSCONFIG --datadir`"
AC_DEFINE_UNQUOTED(CUPS_DATADIR, "$CUPS_DATADIR", [CUPS datadir])
AC_SUBST(CUPS_DATADIR)

CUPS_SERVERROOT="`$CUPSCONFIG --serverroot`"
AC_DEFINE_UNQUOTED(CUPS_SERVERROOT, "$CUPS_SERVERROOT", [CUPS serverroot])
AC_SUBST(CUPS_SERVERROOT)

CUPS_FONTPATH="$CUPS_DATADIR/fonts"
AC_DEFINE_UNQUOTED(CUPS_FONTPATH, "$CUPS_FONTPATH", [Path to CUPS fonts dir])
AC_SUBST(CUPS_FONTPATH)

CUPS_SERVERBIN="`$CUPSCONFIG --serverbin`"
AC_DEFINE_UNQUOTED(CUPS_SERVERBIN, "$CUPS_SERVERBIN", [Path to CUPS binaries dir])
AC_SUBST(CUPS_SERVERBIN)

# Transient run-time state dir of CUPS
CUPS_STATEDIR=""
AC_ARG_WITH(cups-rundir, [  --with-cups-rundir           set transient run-time state directory of CUPS],CUPS_STATEDIR="$withval",[
        case "$uname" in
                Darwin*)
                        # Darwin (OS X)
                        CUPS_STATEDIR="$CUPS_SERVERROOT"
                        ;;
                *)
                        # All others
                        CUPS_STATEDIR="$localstatedir/run/cups"
                        ;;
        esac])
AC_DEFINE_UNQUOTED(CUPS_STATEDIR, "$CUPS_STATEDIR", [Transient run-time state dir of CUPS])
AC_SUBST(CUPS_STATEDIR)

# Domain socket of CUPS...
CUPS_DEFAULT_DOMAINSOCKET=""
AC_ARG_WITH(cups-domainsocket, [  --with-cups-domainsocket     set unix domain socket name used by CUPS
],
        default_domainsocket="$withval",
        default_domainsocket="")

if test x$enable_domainsocket != xno -a x$default_domainsocket != xno; then
        if test "x$default_domainsocket" = x; then
                case "$uname" in
                        Darwin*)
                                # Darwin and MaxOS X do their own thing...
                                CUPS_DEFAULT_DOMAINSOCKET="$localstatedir/run/cupsd"
                                ;;
                        *)
                                # All others use FHS standard...
                                CUPS_DEFAULT_DOMAINSOCKET="$CUPS_STATEDIR/cups.sock"
                                ;;
                esac
        else
                CUPS_DEFAULT_DOMAINSOCKET="$default_domainsocket"
        fi
fi
AC_DEFINE_UNQUOTED(CUPS_DEFAULT_DOMAINSOCKET, "$CUPS_DEFAULT_DOMAINSOCKET", "Domain socket of CUPS")
AC_SUBST(CUPS_DEFAULT_DOMAINSOCKET)

# ========================
# Check for libcupsfilters
# ========================
PKG_CHECK_MODULES([LIBCUPSFILTERS], [libcupsfilters])

# ================
# Check for libppd
# ================
PKG_CHECK_MODULES([LIBPPD], [libppd])

# ==========================
# cups-browsed configuration
# ==========================
AC_ARG_ENABLE([auto-setup-local-only], [AS_HELP_STRING([--enable-auto-setup-local-only], [enable automatic setup of only local IPP printers.])],
        [enable_auto_setup_local_only="$enableval"],
        [enable_auto_setup_local_only=no]
)
if test "x$enable_auto_setup_local_only" != "xno"; then
	AC_DEFINE([ONLY_LOCAL_IPP_PRINTERS_AUTO_SETUP], [], [Auto-setup only local IPP network printers?])
fi

AC_ARG_ENABLE([auto-setup-driverless-only], [AS_HELP_STRING([--enable-auto-setup-driverless-only], [enable automatic setup of only IPP network printers with driverless printing support.])],
        [enable_auto_setup_driverless_only="$enableval"],
        [enable_auto_setup_driverless_only=no]
)
if test "x$enable_auto_setup_driverless_only" != "xno"; then
	AC_DEFINE([ONLY_DRIVERLESS_IPP_PRINTERS_AUTO_SETUP], [], [Auto-setup only driverless IPP network printers?])
fi

if test "x$enable_auto_setup_local_only" != "xno"; then
	enable_auto_setup_driverless_only=no
	enable_auto_setup_all=no
else
	if test "x$enable_auto_setup_driverless_only" != "xno"; then
		enable_auto_setup_all=no
	else
		enable_auto_setup_all=yes
	fi
fi

AC_ARG_WITH([browseremoteprotocols],
	[AS_HELP_STRING([--with-browseremoteprotocols=value], [Set which protocols to listen for in cups-browsed (default: dnssd)])],
	[with_browseremoteprotocols="$withval"],
	[with_browseremoteprotocols="dnssd"]
)
BROWSEREMOTEPROTOCOLS="$with_browseremoteprotocols"
AC_SUBST(BROWSEREMOTEPROTOCOLS)

# ===============================================
# Should we keep generated queues after shutdown?
# ===============================================
AC_ARG_ENABLE(saving-created-queues, AS_HELP_STRING([--enable-saving-created-queues], [enable saving created queues during shutdown]),
	      [SAVING_CREATED_QUEUES=$enableval],[SAVING_CREATED_QUEUES="no"])

AS_IF([test "x$SAVING_CREATED_QUEUES" != "xno"],
      [AC_DEFINE([SAVING_CREATED_QUEUES], [1], [Define whether we save queues during shutdown])]
)

# =========================================
# Local queue naming for remote CUPS queues
# =========================================
AC_ARG_WITH([remote-cups-local-queue-naming],
	[AS_HELP_STRING([--with-remote-cups-local-queue-naming=DNS-SD|MakeModel|RemoteName], [Choose the origin of local queue naming for remote CUPS queues, default based on DNS-SD ID])],
	[case "x$withval" in
		"xMakeModel")
			REMOTE_CUPS_LOCAL_QUEUE_NAMING="MakeModel"
	                AC_DEFINE([NAMING_MAKE_MODEL], [1], [Define that we create local queues for remote CUPS queues based on printer Make-Model])
			;;
		"xRemoteName")
			REMOTE_CUPS_LOCAL_QUEUE_NAMING="RemoteName"
	                AC_DEFINE([NAMING_REMOTE_NAME], [1], [Define that we create local queues for remote CUPS queues based on their print queue name on the server])
			;;
		*)
			REMOTE_CUPS_LOCAL_QUEUE_NAMING="DNS-SD"
	                AC_DEFINE([NAMING_DNSSD], [1], [Define that we create local queues for remote CUPS queues based on DNS-SD name])
			;;
	esac],
	[REMOTE_CUPS_LOCAL_QUEUE_NAMING="DNS-SD"
	 AC_DEFINE([NAMING_DNSSD], [1], [Define that we create local queues for remote CUPS queues based on DNS-SD name])]
)

# =========================================================
# Turn on/off network interface updates for each found entry
# ==========================================================
AC_ARG_ENABLE([frequent_netif_update],
              [AS_HELP_STRING([--enable-frequent-netif-update], [Enable network interface update after each found entry to prevent network issues])],
              [FREQUENT_NETIF_UPDATE=$enableval],
              [FREQUENT_NETIF_UPDATE=yes]
)

AS_IF([test "x$FREQUENT_NETIF_UPDATE" != "xno"],
      [AC_DEFINE([FREQUENT_NETIF_UPDATE], [1], [Define whether we want network interface update after each found entry])]
)

# ======================
# Check system functions
# ======================
AC_CHECK_FUNCS(sigaction)
AC_CHECK_FUNCS(waitpid wait3)
AC_CHECK_FUNCS(strtoll)
AC_CHECK_FUNCS(open_memstream)
AC_CHECK_FUNCS(getline,[],AC_SUBST([GETLINE],['bannertopdf-getline.$(OBJEXT)']))
AC_CHECK_FUNCS(strcasestr,[],AC_SUBST([STRCASESTR],['pdftops-strcasestr.$(OBJEXT)']))
AC_SEARCH_LIBS(pow, m)
dnl Checks for string functions.
AC_CHECK_FUNCS(strdup strlcat strlcpy)
if test "$host_os_name" = "hp-ux" -a "$host_os_version" = "1020"; then
        echo Forcing snprintf emulation for HP-UX.
else
        AC_CHECK_FUNCS(snprintf vsnprintf)
fi

# ========================
# Check for system headers
# ========================
AC_CHECK_HEADERS([stdlib.h])
AC_CHECK_HEADERS([sys/stat.h])
AC_CHECK_HEADERS([sys/types.h])
AC_CHECK_HEADERS([unistd.h])
AC_CHECK_HEADERS([zlib.h])
AC_CHECK_HEADERS([endian.h])
AC_CHECK_HEADERS([dirent.h])
AC_CHECK_HEADERS([sys/ioctl.h])
AC_CHECK_HEADER(string.h,AC_DEFINE(HAVE_STRING_H))
AC_CHECK_HEADER(strings.h,AC_DEFINE(HAVE_STRINGS_H))

# ========================================
# Check for modules needed by cups-browsed
# ========================================

dnl Avahi for cups-browsed
AVAHI_LIBS=""
AVAHI_CFLAGS=""
AVAHI_GLIB_CFLAGS=""
AVAHI_GLIB_LIBS=""

AC_ARG_ENABLE([avahi],
	[AS_HELP_STRING([--disable-avahi], [Disable DNS Service Discovery support using Avahi.])],
	[enable_avahi="$enableval"],
	[enable_avahi=yes]
)
AM_CONDITIONAL([ENABLE_AVAHI], [test "x$enable_avahi" != "xno"])

AC_ARG_WITH(avahi-libs,
	[AS_HELP_STRING([--with-avahi-libs], [Set directory for Avahi library.])],
	AVAHI_LIBS="-L$withval $AVAHI_LIBS",)
AC_ARG_WITH(avahi-includes,
	[AS_HELP_STRING([--with-avahi-includes], [Set directory for Avahi includes])],
	AVAHI_CFLAGS="-I$withval $AVAHI_CFLAGS",)

if test "x$enable_avahi" != xno; then
	PKG_CHECK_MODULES(AVAHI, avahi-client,
		[AC_DEFINE(HAVE_AVAHI, [], [Define if you have the avahi library])])
fi

AC_SUBST(AVAHI_LIBS)
AC_SUBST(AVAHI_CFLAGS)

PKG_CHECK_MODULES(GLIB, [glib-2.0 >= 2.30.2])
AC_SUBST(GLIB_CFLAGS)
AC_SUBST(GLIB_LIBS)

if test x$enable_avahi != xno; then
	PKG_CHECK_MODULES(AVAHI_GLIB, [avahi-glib])
fi

AC_SUBST(AVAHI_GLIB_CFLAGS)
AC_SUBST(AVAHI_GLIB_LIBS)

PKG_CHECK_MODULES(GIO, [gio-2.0])
AC_SUBST(GIO_CFLAGS)
AC_SUBST(GIO_LIBS)

PKG_CHECK_MODULES(GIO_UNIX, [gio-unix-2.0])
AC_SUBST(GIO_UNIX_CFLAGS)
AC_SUBST(GIO_UNIX_LIBS)

dnl Setup init.d locations...
AC_ARG_WITH(rcdir, [AS_HELP_STRING([--with-rcdir], [Set path for rc scripts])],rcdir="$withval",rcdir="")
AC_ARG_WITH(rclevels, [AS_HELP_STRING([--with-rclevels], [Set run levels for rc scripts])],rclevels="$withval",rclevels="2 3 5")
AC_ARG_WITH(rcstart, [AS_HELP_STRING([--with-rcstart], [Set start number for rc scripts])],rcstart="$withval",rcstart="99")
AC_ARG_WITH(rcstop, [AS_HELP_STRING([--with-rcstop], [Set stop number for rc scripts])],rcstop="$withval",rcstop="00")

INITDIR=""
INITDDIR=""
RCLEVELS="$rclevels"
RCSTART="$rcstart"
RCSTOP="$rcstop"

if test x$rcdir = x; then
	case "`uname`" in
		FreeBSD* | OpenBSD* | MirBSD* | ekkoBSD*)
			# FreeBSD and OpenBSD
			;;

		Linux | GNU | GNU/k*BSD*)
			# Linux/HURD seems to choose an init.d directory at random...
			if test -d /sbin/init.d; then
				# SuSE
				INITDIR="/sbin/init.d"
			else
				if test -d /etc/init.d; then
					# Others
					INITDIR="/etc"
				else
					# RedHat
					INITDIR="/etc/rc.d"
				fi
			fi
			RCSTART="82"
			RCSTOP="35"
			;;

		NetBSD*)
			# NetBSD
			INITDDIR="/etc/rc.d"
			;;

		*)
			INITDIR="/etc"
			;;

	esac
elif test "x$rcdir" != xno; then
	if test "x$rclevels" = x; then
		INITDDIR="$rcdir"
	else
		INITDIR="$rcdir"
	fi
fi

AM_CONDITIONAL([RCLINKS], [test "x$INITDIR" != "x"])

if test "x${INITDIR}" != "x" -a "x${INITDDIR}" = "x"; then
   INITDDIR="${INITDIR}/init.d"
fi

AC_SUBST(INITDIR)
AC_SUBST(INITDDIR)
AC_SUBST(RCLEVELS)
AC_SUBST(RCSTART)
AC_SUBST(RCSTOP)

# ===================================
# Check for large files and long long
# ===================================
AC_SYS_LARGEFILE
LARGEFILE=""
AS_IF([test x"$enable_largefile" != "xno"], [
	LARGEFILE="-D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE"
	AS_IF([test x"$ac_cv_sys_large_files" = "x1"], [LARGEFILE="$LARGEFILE -D_LARGE_FILES"])
	AS_IF([test x"$ac_cv_sys_file_offset_bits" = "x64"], [LARGEFILE="$LARGEFILE -D_FILE_OFFSET_BITS=64"])
])
AC_SUBST(LARGEFILE)

AC_CHECK_TYPE(long long, [long_long_found=yes], [long_long_found=no])
AS_IF([test x"$long_long_found" = "xyes"], [
	AC_DEFINE([HAVE_LONG_LONG], [], [Platform supports long long type])
])

# ================
# Check for cflags
# ================
AC_ARG_ENABLE([werror],
	[AS_HELP_STRING([--enable-werror], [Treat all warnings as errors, useful for development.])],
	[enable_werror="$enableval"],
	[enable_werror=no]
)
AS_IF([test x"$enable_werror" = "xyes"], [
	CFLAGS="$CFLAGS -Werror"
])
AS_IF([test x"$GCC" = "xyes"], [
	# Be tough with warnings and produce less careless code
	CFLAGS="$CFLAGS -Wall -std=gnu11"
	CXXFLAGS="$CXXFLAGS -Wall " # -Weffc++" # TODO: enable when it does not print 1MB of warnings
])
CFLAGS="$CFLAGS -D_GNU_SOURCE"
CXXFLAGS="$CXXFLAGS -D_GNU_SOURCE"

# =====================
# Prepare all .in files
# =====================
AC_CONFIG_FILES([
	Makefile
	daemon/cups-browsed
	daemon/cups-browsed.conf
])
AC_OUTPUT

# ==============================================
# Display final informations about configuration
# ==============================================
AC_MSG_NOTICE([
==============================================================================
Environment settings:
	CFLAGS:                                    ${CFLAGS}
	CXXFLAGS:                                  ${CXXFLAGS}
	LDFLAGS:                                   ${LDFLAGS}
Build configuration:
	cups-config:                               ${with_cups_config}
	init directory:                            ${INITDDIR}
	cups domain socket:                        ${CUPS_DEFAULT_DOMAINSOCKET}
	avahi:                                     ${enable_avahi}
	browsing:                                  ${with_browseremoteprotocols}
	local queue naming for remote CUPS queues: ${REMOTE_CUPS_LOCAL_QUEUE_NAMING}
	keep generated queues during shutdown:     ${SAVING_CREATED_QUEUES}
	update network interfaces after each found entry: ${FREQUENT_NETIF_UPDATE}
	all ipp printer auto-setup:                ${enable_auto_setup_all}
	only driverless auto-setup:                ${enable_auto_setup_driverless_only}
	only local auto-setup:                     ${enable_auto_setup_local_only}
	werror:                                    ${enable_werror}
==============================================================================
])
