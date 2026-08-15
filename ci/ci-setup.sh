#!/bin/sh
# ci/ci-setup.sh
#
# CI helper for building and testing cups-browsed against several CUPS releases
# on both native and QEMU-emulated runners.
#
# cups-browsed sits at the top of the OpenPrinting build stack: it needs libcups
# AND libcupsfilters AND libppd.  For the source-CUPS leg the distro
# libcupsfilters-dev / libppd-dev are built against CUPS 2.4 (wrong ABI), so this
# script builds the whole chain (pdfio -> libcupsfilters -> libppd) from source
# against the active CUPS before building cups-browsed on top.
#
# cups-browsed does NOT make sense on CUPS 3.x, so - unlike the other repos -
# the matrix is only 2 CUPS releases (2.4.x and 2.5.x), never libcups3.
#
# Subcommands:
#   deps                 install build dependencies
#   cups <kind>          provide libcups; <kind> is one of:
#                          system-2x    distro libcups2-dev  (CUPS 2.4.x)
#                          source-2.5.x OpenPrinting/cups@master    (CUPS 2.5.x)
#   pdfio                build/install pdfio (required by libcupsfilters)
#   libcupsfilters <kind> provide libcupsfilters matching the active CUPS:
#                          system-2x    distro libcupsfilters-dev
#                          source-*     OpenPrinting/libcupsfilters@master
#   libppd <kind>        provide libppd matching the active CUPS:
#                          system-2x    distro libppd-dev
#                          source-*     OpenPrinting/libppd@master
#   build-cups-browsed   autogen + configure + make (build/link only)
#
# Environment knobs honoured by build-cups-browsed:
#   CUPS_KIND   the <kind> above (controls the cups-config shim)
#   EMULATED    "1" when running under QEMU emulation
#
# Override knobs (optional):
#   LIBCUPSFILTERS_URL / LIBCUPSFILTERS_REF   source libcupsfilters build
#   LIBPPD_URL / LIBPPD_REF                   source libppd build
#
# The script runs as root inside emulation containers and via sudo on native
# runners; it detects which automatically.
set -eu

# Classify a failure so CI (and humans) can tell an upstream-dependency breakage
# apart from a real cups-browsed failure.  Each invocation handles exactly one
# subcommand, so $1 identifies which side failed: providing the
# CUPS / libcupsfilters / libppd stack (built from @master on the source leg, an
# unpinned moving target) vs building/testing cups-browsed itself.  The source
# leg is non-blocking precisely because of the former class of transient
# breakage; this label makes the distinction explicit.
_subcmd="${1:-}"
_classify_failure() {
	rc=$?
	[ "$rc" -eq 0 ] && exit 0
	case "$_subcmd" in
		cups|pdfio|libcupsfilters|libppd)
			echo "::error::UPSTREAM-DEP-FAILED: '$_subcmd' failed while building the CUPS/libcupsfilters/libppd stack (from @master on the source leg). This is an upstream-dependency breakage, not a cups-browsed bug." ;;
		build-cups-browsed)
			echo "::error::CUPS-BROWSED-FAILED: cups-browsed $_subcmd failed." ;;
	esac
	exit "$rc"
}
trap _classify_failure EXIT

PDFIO_VER=1.6.4
LIBCUPSFILTERS_URL="${LIBCUPSFILTERS_URL:-https://github.com/OpenPrinting/libcupsfilters.git}"
LIBCUPSFILTERS_REF="${LIBCUPSFILTERS_REF:-master}"
LIBPPD_URL="${LIBPPD_URL:-https://github.com/OpenPrinting/libppd.git}"
LIBPPD_REF="${LIBPPD_REF:-master}"

SUDO=""
[ "$(id -u)" -eq 0 ] || SUDO="sudo"

# Make apt completely non-interactive.  Native GitHub runners ship needrestart,
# whose service-restart prompt otherwise hangs the job forever; the emulated
# containers do not have it, which is why only the native legs stalled.
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

# Source-built CUPS / libcupsfilters / libppd install their .pc files under
# $prefix/lib[/<multiarch>]/pkgconfig; make sure pkg-config (and cups-browsed's
# configure) can find them.
ma=$(gcc -dumpmachine 2>/dev/null || echo "")
PKG_CONFIG_PATH="/usr/lib/pkgconfig${ma:+:/usr/lib/$ma/pkgconfig}:/usr/local/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_PATH

apt_install() {
	$SUDO apt-get update --fix-missing -y
	$SUDO apt-get install -y "$@"
}

cmd_deps() {
	# Union of cups-browsed's own build deps (glib / gio / avahi-glib) and the
	# deps needed to build pdfio, libcupsfilters and libppd from source on the
	# source-CUPS leg.
	apt_install \
		build-essential autoconf automake libtool libtool-bin pkg-config \
		gettext autopoint autotools-dev cmake git wget tar make gcc g++ \
		file dbus \
		libglib2.0-dev libavahi-client-dev libavahi-common-dev \
		libavahi-glib-dev libssl-dev libpam-dev libusb-1.0-0-dev \
		zlib1g-dev libqpdf-dev libexif-dev liblcms2-dev libfontconfig1-dev \
		libfreetype6-dev libcairo2-dev libjpeg-dev libpng-dev libtiff-dev \
		libjxl-dev libpoppler-dev libpoppler-cpp-dev libdbus-1-dev \
		libopenjp2-7-dev mupdf-tools poppler-utils ghostscript
	# Never let a pre-shipped cups-browsed / libppd / libcupsfilters shadow the
	# builds under test.
	$SUDO apt-get remove -y cups-browsed libppd-dev libcupsfilters-dev || true
}

# Install a thin `cups-config` shim backed by pkg-config.  cups-browsed's
# configure.ac hard-requires `cups-config`, but CUPS 2.5 (OpenPrinting/cups
# master) has dropped it in favour of cups.pc.  --image is vestigial here
# (cups-browsed #includes <cups/raster.h> but calls no cupsRaster* APIs, and
# CUPS 2.5 folds the raster API into libcups), so the shim ignores it.
install_cups_config_shim() {
	shim=/usr/local/bin/cups-config
	$SUDO tee "$shim" >/dev/null <<'SHIM'
#!/bin/sh
# Minimal cups-config shim backed by pkg-config (CUPS 2.5 dropped cups-config).
cflags=$(pkg-config --cflags cups)
libs=$(pkg-config --libs cups)
ver=$(pkg-config --modversion cups)
datadir=$(pkg-config --variable=cups_datadir cups 2>/dev/null)
serverroot=$(pkg-config --variable=cups_serverroot cups 2>/dev/null)
serverbin=$(pkg-config --variable=cups_serverbin cups 2>/dev/null)
[ -n "$datadir" ] || datadir=/usr/share/cups
[ -n "$serverroot" ] || serverroot=/etc/cups
[ -n "$serverbin" ] || serverbin=/usr/lib/cups
out=""
for arg in "$@"; do
	case "$arg" in
		--cflags)     out="$out $cflags" ;;
		--libs)       out="$out $libs" ;;
		--image)      : ;;  # vestigial; folded into libcups on CUPS 2.5
		--ldflags)    : ;;
		--version)    out="$out $ver" ;;
		--datadir)    out="$out $datadir" ;;
		--serverroot) out="$out $serverroot" ;;
		--serverbin)  out="$out $serverbin" ;;
	esac
done
echo "$out"
SHIM
	$SUDO chmod +x "$shim"
	echo "ci-setup: installed cups-config shim at $shim"
}

# build_autoconf <url> <ref> <submodule-flag> [configure-args...]
build_autoconf() {
	url="$1"; ref="$2"; sub="$3"; shift 3
	echo "ci-setup: building $url @ $ref"
	src="$(mktemp -d)"
	git clone --depth 1 --branch "$ref" $sub "$url" "$src"
	( cd "$src"
	  [ -x ./configure ] || ./autogen.sh
	  ./configure --prefix=/usr "$@" || ./configure --prefix=/usr
	  make -j"$(nproc)"
	  $SUDO make install )
	$SUDO ldconfig || true
}

cmd_cups() {
	kind="$1"
	case "$kind" in
		system-2x)
			# Distro CUPS 2.4: libcups2-dev provides cups-config + headers.
			apt_install libcups2-dev
			;;
		source-2.5.x)
			# Force the multiarch libdir: CUPS's configure otherwise installs
			# libcups into /usr/lib64 on 64-bit hosts, which is not on the
			# default linker search path.
			build_autoconf https://github.com/OpenPrinting/cups.git master "" \
				--disable-systemd ${ma:+--libdir=/usr/lib/$ma}
			install_cups_config_shim
			;;
		*)
			echo "ci-setup: unknown/unsupported cups kind: $kind" >&2; exit 2 ;;
	esac
}

cmd_pdfio() {
	echo "ci-setup: building pdfio $PDFIO_VER"
	src="$(mktemp -d)"
	( cd "$src"
	  wget -q "https://github.com/michaelrsweet/pdfio/releases/download/v$PDFIO_VER/pdfio-$PDFIO_VER.tar.gz"
	  tar -xzf "pdfio-$PDFIO_VER.tar.gz"
	  cd "pdfio-$PDFIO_VER"
	  ./configure --prefix=/usr --enable-shared
	  make all
	  $SUDO make install )
	$SUDO ldconfig || true
}

cmd_libcupsfilters() {
	kind="$1"
	case "$kind" in
		system-2x)
			apt_install libcupsfilters-dev
			;;
		source-*)
			# Build libcupsfilters against the CUPS already installed above.
			build_autoconf "$LIBCUPSFILTERS_URL" "$LIBCUPSFILTERS_REF" ""
			;;
		*)
			echo "ci-setup: unknown libcupsfilters kind: $kind" >&2; exit 2 ;;
	esac
}

cmd_libppd() {
	kind="$1"
	case "$kind" in
		system-2x)
			apt_install libppd-dev libppd2
			;;
		source-*)
			# Build libppd against the CUPS + libcupsfilters installed above.
			build_autoconf "$LIBPPD_URL" "$LIBPPD_REF" ""
			;;
		*)
			echo "ci-setup: unknown libppd kind: $kind" >&2; exit 2 ;;
	esac
}

cmd_build() {
	./autogen.sh
	./configure
	make -j"$(nproc)" V=1

	# Report which CUPS the configure step actually selected.
	echo "ci-setup: configured against:"
	grep -E "cups-config:|CUPS_VERSION|checking for cups" config.log 2>/dev/null | head || true
}

case "${1:-}" in
	deps)               cmd_deps ;;
	cups)               shift; cmd_cups "$@" ;;
	pdfio)              cmd_pdfio ;;
	libcupsfilters)     shift; cmd_libcupsfilters "$@" ;;
	libppd)             shift; cmd_libppd "$@" ;;
	build-cups-browsed) cmd_build ;;
	*)
		echo "usage: ci-setup.sh {deps | cups <kind> | pdfio | libcupsfilters <kind> | libppd <kind> | build-cups-browsed}" >&2
		exit 2 ;;
esac
