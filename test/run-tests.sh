#!/bin/sh
#
# Perform testing of automatic print queue generation and removal by
# cups-browsed
#
# Copyright © 2020-2023 by OpenPrinting
# Copyright © 2007-2021 by Apple Inc.
# Copyright © 1997-2007 by Easy Software Products, all rights reserved.
#
# Licensed under Apache License v2.0.  See the file "LICENSE" for more
# information.
#

#
# Clean up after the tests, and preserve logs for failed "make check"
# Shut down daemons, remove test bed if we have created one
#

clean_up()
{
    #
    # Only clean up when we do an actual automatic test and do not start
    # daemons for manual testing
    #

    if test $testtype = 0 -o $testtype = 1; then
	return
    fi

    #
    # Shut down all the daemons
    #

    kill_sent=0

    if (test "x$ipp_eve_pid1" != "x"); then
	kill -TERM $ipp_eve_pid1 2>/dev/null
	kill_sent=1
    fi

    if (test "x$ipp_eve_pid2" != "x"); then
	kill -TERM $ipp_eve_pid2 2>/dev/null
	kill_sent=1
    fi

    if (test "x$cups_browsed" != "x"); then
	kill -TERM $cups_browsed 2>/dev/null
	kill_sent=1
    fi

    if (test "x$cupsd" != "x"); then
	kill -TERM $cupsd 2>/dev/null
	kill_sent=1
    fi

    if test $kill_sent = 1; then
	sleep 5
    fi

    #
    # Hard-kill any remaining daemon
    #

    if (test "x$ipp_eve_pid1" != "x"); then
	kill -KILL $ipp_eve_pid1 2>/dev/null
    fi

    if (test "x$ipp_eve_pid2" != "x"); then
	kill -KILL $ipp_eve_pid2 2>/dev/null
    fi

    if (test "x$cups_browsed" != "x"); then
	kill -KILL $cups_browsed 2>/dev/null
    fi

    if (test "x$cupsd" != "x"); then
	kill -KILL $cupsd 2>/dev/null
    fi

    #
    # Preserve logs in case of failure
    #

    if test "$1" != "0"; then
	if test -n "$BASE"; then
	    echo "============================"
	    echo "CUPS ERROR_LOG"
	    echo "============================"
	    echo ""
	    cat $BASE/log/error_log
	    echo ""
	    echo ""
	    echo "============================"
	    echo "CUPS ACCESS_LOG"
	    echo "============================"
	    echo ""
	    cat $BASE/log/access_log
	    echo ""
	    echo ""
	    echo "============================"
	    echo "CUPSD DEBUG LOG"
	    echo "============================"
	    echo ""
	    cat $BASE/log/cupsd_debug_log
	    echo ""
	    echo ""
	    echo "============================"
	    echo "CUPS-BROWSED DEBUG LOG"
	    echo "============================"
	    echo ""
	    cat $BASE/log/cups-browsed_debug_log
	    echo ""
	    echo ""
	fi

	if test -n "$IPPEVEBASE"; then
	    echo "============================"
	    echo "IPPEVEPRINTER 1 LOG"
	    echo "============================"
	    echo ""
	    cat $IPPEVEBASE/log/ippeve1_log
	    echo ""
	    echo ""
	    echo "============================"
	    echo "IPPEVEPRINTER 2 LOG"
	    echo "============================"
	    echo ""
	    cat $IPPEVEBASE/log/ippeve2_log
	    echo ""
	    echo ""
	fi
    fi

    #
    # Remove test bed directories
    #

    if test -n "$IPPEVEBASE"; then
	rm -rf $IPPEVEBASE
    fi

    if test -n "$BASE"; then
	rm -rf $BASE
    fi
}


argcount=$#

#
# Force the permissions of the files we create...
#

umask 022

#
# Solaris has a non-POSIX grep in /bin...
#

if test -x /usr/xpg4/bin/grep; then
    GREP=/usr/xpg4/bin/grep
else
    GREP=grep
fi

#
# Figure out the proper echo options...
#

if (echo "testing\c"; echo 1,2,3) | $GREP c >/dev/null; then
    ac_n=-n
    ac_c=
else
    ac_n=
    ac_c='\c'
fi

if test "${MAKELEVEL+x}" -o "${MAKEFLAGS+x}"; then
    makecheck=1
    testtype=2
    usevalgrind=no
    cd test
    pwd 1>&2
else
    makecheck=0
fi

#
# Greet the tester...
#

echo "Welcome to the cups-browsed Automated Test Script."
echo ""

if test $makecheck = 0; then
    echo "Please choose the type of test you wish to perform:"
    echo ""
    echo "0 - No testing, keep cups-browsed running for me"
    echo "1 - No testing, keep cups-browsed and ippeveprinter running for me"
    echo "2 - Basic functionality test"
    echo "3 - Basic functionality test, system's cups-browsed"
    echo ""
    echo $ac_n "Enter the number of the test you wish to perform: [2] $ac_c"

    if test $# -gt 0; then
	testtype=$1
	shift
    else
	read testtype
    fi
    echo ""
fi

case "$testtype" in
    0)
	echo "Running only cups-browsed (0)"
	nprinters=0
	pjobs=0
	pprinters=0
	loglevel="debug2"
	;;
    1)
	echo "Running only cups-browsed and ippeveprinter (1)"
	nprinters=3
	pjobs=0
	pprinters=0
	loglevel="debug2"
	;;
    2)
	echo "Running the standard tests (2)"
	nprinters=3
	pjobs=1
	pprinters=0
	loglevel="debug2"
	testtype="2"
	;;
    *)
	echo "Running the standard tests (3)"
	nprinters=3
	pjobs=1
	pprinters=0
	loglevel="debug2"
	testtype="3"
	;;
esac

#
# CUPS resource directories of the system
#
# For non-root ("make check") testing we copy/link our testbed CUPS
# components from there
#

sys_datadir=`pkg-config --variable=cups_datadir cups`
sys_serverbin=`pkg-config --variable=cups_serverbin cups`
sys_serverroot=`pkg-config --variable=cups_serverroot cups`

#
# Pseudo-random number (nanoseconds of "date") as prefix for
# all queue names, to avoid clash with existing queues. This
# also identifies "our" test queues
#

queue_prefix=`date +%N`

#
# Information for the server/tests...
#

user="$USER"
if test -z "$user"; then
    if test -x /usr/ucb/whoami; then
	user=`/usr/ucb/whoami`
    else
	user=`whoami`
    fi

    if test -z "$user"; then
	user="unknown"
    fi
fi

if test "x`id -u`" = x0 -o "$testtype" = "3"; then
    echo "Running as root or test type 3, using system's CUPS/cups-browsed setup"
    echo ""
    echo "Make sure that CUPS and cups-browsed are already running."
    echo "It is recommended to do the test in a dedicated virtual machine or container."
    echo "This test mode is for autopkgtests in Debian/Ubuntu or for GitHub actions."
    echo ""
else
    echo "Running as non-root user, using 'make test' mode"
    echo ""
    echo "Running own CUPS instance on alternative port"
    echo "Using cups-browsed from source tree"
    port="${CUPS_TESTPORT:=8631}"
    cwd=`pwd`
    root=`dirname $cwd`
    CUPS_TESTROOT="$root"; export CUPS_TESTROOT

    BASE="${CUPS_TESTBASE:=}"
    if test -z "$BASE"; then
	if test -d /private/tmp; then
	    BASE=/private/tmp/cups-browsed-$user
	else
	    BASE=/tmp/cups-browsed-$user
	fi
    fi
    export BASE
fi

#
# Make sure that the LPDEST and PRINTER environment variables are
# not included in the environment that is passed to the tests.  These
# will usually cause tests to fail erroneously...
#

unset LPDEST
unset PRINTER

#
# See if we want to use valgrind...
#

if test $makecheck = 0; then
    echo ""
    echo "This test script can use the Valgrind software from:"
    echo ""
    echo "    http://developer.kde.org/~sewardj/"
    echo ""
    echo "on cups-browsed."
    echo ""
    echo $ac_n "Enter Y to use Valgrind or N to not use Valgrind: [N] $ac_c"

    if test $# -gt 0; then
	usevalgrind=$1
	shift
    else
	read usevalgrind
    fi
    echo ""
fi

case "$usevalgrind" in
    Y* | y*)
	VALGRIND="valgrind --tool=memcheck --log-file=$BASE/log/valgrind.%p --error-limit=no --leak-check=yes --trace-children=yes"
	if test `uname` = Darwin; then
	    VALGRIND="$VALGRIND --dsymutil=yes"
	fi
	export VALGRIND
	echo "Using Valgrind; log files can be found in $BASE/log..."
	;;

    *)
	VALGRIND=""
	export VALGRIND
	;;
esac

#
# Start by creating temporary directories for the tests...
#

echo "Creating directories for test..."

if test -n "$BASE"; then
    rm -rf $BASE
    mkdir $BASE
    mkdir $BASE/bin
    mkdir $BASE/bin/backend
    mkdir $BASE/bin/driver
    mkdir $BASE/bin/filter
    mkdir $BASE/cache
    mkdir $BASE/certs
    mkdir $BASE/share
    mkdir $BASE/share/banners
    mkdir $BASE/share/drv
    mkdir $BASE/share/locale
    for file in $sys_datadir/locale/*/cups_*.po; do
	loc=`basename $file .po | cut -c 6-`
	mkdir $BASE/share/locale/$loc
	ln -s $file $BASE/share/locale/$loc
    done
    mkdir $BASE/share/data
    mkdir $BASE/share/mime
    mkdir $BASE/share/model
    mkdir $BASE/share/ppdc
    mkdir $BASE/interfaces
    mkdir $BASE/log
    mkdir $BASE/ppd
    mkdir $BASE/spool
    mkdir $BASE/spool/temp
    mkdir $BASE/ssl

    #
    # We copy the cupsd executable to break it off from the Debian/Ubuntu
    # package's AppArmor shell, so that it can work with our test bed
    # directories
    #

    cp /usr/sbin/cupsd $BASE/bin/

    ln -s $sys_serverbin/backend/dnssd $BASE/bin/backend
    ln -s $sys_serverbin/backend/http $BASE/bin/backend
    ln -s $sys_serverbin/backend/ipp $BASE/bin/backend
    ln -s ipp $BASE/bin/backend/ipps
    ln -s $sys_serverbin/backend/lpd $BASE/bin/backend
    ln -s $sys_serverbin/backend/mdns $BASE/bin/backend
    ln -s $sys_serverbin/backend/snmp $BASE/bin/backend
    ln -s $sys_serverbin/backend/socket $BASE/bin/backend
    ln -s $sys_serverbin/backend/usb $BASE/bin/backend
    ln -s $root/implicitclass $BASE/bin/backend
    ln -s $sys_serverbin/cgi-bin $BASE/bin
    ln -s $sys_serverbin/monitor $BASE/bin
    ln -s $sys_serverbin/notifier $BASE/bin
    ln -s $sys_serverbin/daemon $BASE/bin
    ln -s $sys_serverbin/filter/commandtops $BASE/bin/filter
    ln -s $sys_serverbin/filter/gziptoany $BASE/bin/filter
    ln -s $sys_serverbin/filter/pstops $BASE/bin/filter
    ln -s $sys_serverbin/filter/rastertoepson $BASE/bin/filter
    ln -s $sys_serverbin/filter/rastertohp $BASE/bin/filter
    ln -s $sys_serverbin/filter/rastertolabel $BASE/bin/filter
    ln -s $sys_serverbin/filter/rastertopwg $BASE/bin/filter
    cat >$BASE/share/banners/standard <<EOF
           ==== Cover Page ====


      Job: {?printer-name}-{?job-id}
    Owner: {?job-originating-user-name}
     Name: {?job-name}
    Pages: {?job-impressions}


           ==== Cover Page ====
EOF
    cat >$BASE/share/banners/classified <<EOF
           ==== Classified - Do Not Disclose ====


      Job: {?printer-name}-{?job-id}
    Owner: {?job-originating-user-name}
     Name: {?job-name}
    Pages: {?job-impressions}


           ==== Classified - Do Not Disclose ====
EOF
    ln -s $sys_datadir/drv/sample.drv $BASE/share/drv
    ln -s $sys_datadir/mime/mime.types $BASE/share/mime
    ln -s $sys_datadir/mime/mime.convs $BASE/share/mime
    ln -s $sys_datadir/ppdc/*.h $BASE/share/ppdc
    ln -s $sys_datadir/ppdc/*.defs $BASE/share/ppdc
    ln -s $sys_datadir/templates $BASE/share
    ln -s $sys_datadir/ipptool $BASE/share

    #
    # pdftopdf filter of cups-filters 1.x or 2.x, cgpdftopdf of Mac/Darwin,
    # or gziptoany as dummy filter if nothing better installed
    #
	
    ln -s $root/test/test.convs $BASE/share/mime

    if test -x "$sys_serverbin/filter/pdftopdf"; then
	ln -s "$sys_serverbin/filter/pdftopdf" "$BASE/bin/filter/pdftopdf"
    elif test -x "$sys_serverbin/filter/cgpdftopdf"; then
	ln -s "$sys_serverbin/filter/cgpdftopdf" "$BASE/bin/filter/pdftopdf"
    else
	ln -s "gziptoany" "$BASE/bin/filter/pdftopdf"
    fi

    #
    # Then create the necessary config files...
    #

    echo "Creating cupsd.conf for test..."

    if test $testtype = 0; then
	jobhistory="30m"
	jobfiles="5m"
    else
	jobhistory="30"
	jobfiles="Off"
    fi

    cat >$BASE/cupsd.conf <<EOF
StrictConformance Yes
Browsing Off
Listen localhost:$port
Listen $BASE/sock
MaxSubscriptions 3
MaxLogSize 0
AccessLogLevel actions
LogLevel $loglevel
LogTimeFormat usecs
PreserveJobHistory $jobhistory
PreserveJobFiles $jobfiles
<Policy default>
<Limit All>
Order Allow,Deny
</Limit>
</Policy>
EOF

    if test $testtype = 0; then
	echo WebInterface yes >>$BASE/cupsd.conf
    fi

    cat >$BASE/cups-files.conf <<EOF
FileDevice yes
Printcap
User $user
ServerRoot $BASE
StateDir $BASE
ServerBin $BASE/bin
CacheDir $BASE/cache
DataDir $BASE/share
DocumentRoot $root/doc
RequestRoot $BASE/spool
TempDir $BASE/spool/temp
AccessLog $BASE/log/access_log
ErrorLog $BASE/log/error_log
PageLog $BASE/log/page_log

PassEnv DYLD_INSERT_LIBRARIES
PassEnv DYLD_LIBRARY_PATH
PassEnv LD_LIBRARY_PATH
PassEnv LD_PRELOAD
PassEnv LOCALEDIR
PassEnv ASAN_OPTIONS

Sandboxing Off
EOF

    #
    # Set up some test queues with PPD files...
    #

    echo "Creating printers.conf for test..."

    i=1
    while test $i -le 2; do
	cat >>$BASE/printers.conf <<EOF
<Printer $queue_prefix-cups-$i>
Accepting Yes
DeviceURI file:/dev/null
Info Test PS printer $i
JobSheets none none
Location CUPS test suite
State Idle
StateMessage Printer $1 is idle.
</Printer>
EOF

	cp testps.ppd $BASE/ppd/$queue_prefix-cups-$i.ppd

	i=`expr $i + 1`
    done

    if test -f $BASE/printers.conf; then
	cp $BASE/printers.conf $BASE/printers.conf.orig
    else
	touch $BASE/printers.conf.orig
    fi

    #
    # Create a helper script to run programs with...
    #

    echo "Setting up environment variables for test..."

    if test "x$ASAN_OPTIONS" = x; then
	# AddressSanitizer on Linux reports memory leaks from the main function
	# which is basically useless - in general, programs do not need to free
	# every object before exit since the OS will recover the process's
	# memory.
	ASAN_OPTIONS="detect_leaks=false"
	export ASAN_OPTIONS
    fi

    # These get exported because they don't have side-effects...
    CUPS_DISABLE_APPLE_DEFAULT=yes; export CUPS_DISABLE_APPLE_DEFAULT
    CUPS_SERVER=localhost:$port; export CUPS_SERVER
    CUPS_SERVERROOT=$BASE; export CUPS_SERVERROOT
    CUPS_STATEDIR=$BASE; export CUPS_STATEDIR
    CUPS_DATADIR=$BASE/share; export CUPS_DATADIR
    IPP_PORT=$port; export IPP_PORT
    LOCALEDIR=$BASE/share/locale; export LOCALEDIR

    echo "Creating wrapper script..."

    runcups="$BASE/runcups"; export runcups

    echo "#!/bin/sh" >$runcups
    echo "# Helper script for running CUPS test instance." >>$runcups
    echo "" >>$runcups
    echo "# Set required environment variables..." >>$runcups
    echo "CUPS_DATADIR=\"$CUPS_DATADIR\"; export CUPS_DATADIR" >>$runcups
    echo "CUPS_SERVER=\"$CUPS_SERVER\"; export CUPS_SERVER" >>$runcups
    echo "CUPS_SERVERROOT=\"$CUPS_SERVERROOT\"; export CUPS_SERVERROOT" >>$runcups
    echo "CUPS_STATEDIR=\"$CUPS_STATEDIR\"; export CUPS_STATEDIR" >>$runcups
    echo "DYLD_INSERT_LIBRARIES=\"$DYLD_INSERT_LIBRARIES\"; export DYLD_INSERT_LIBRARIES" >>$runcups
    echo "DYLD_LIBRARY_PATH=\"$DYLD_LIBRARY_PATH\"; export DYLD_LIBRARY_PATH" >>$runcups
    # IPP_PORT=$port; export IPP_PORT
    echo "LD_LIBRARY_PATH=\"$LD_LIBRARY_PATH\"; export LD_LIBRARY_PATH" >>$runcups
    echo "LD_PRELOAD=\"$LD_PRELOAD\"; export LD_PRELOAD" >>$runcups
    echo "LOCALEDIR=\"$LOCALEDIR\"; export LOCALEDIR" >>$runcups
    if test "x$CUPS_DEBUG_LEVEL" != x; then
	echo "CUPS_DEBUG_FILTER='$CUPS_DEBUG_FILTER'; export CUPS_DEBUG_FILTER" >>$runcups
	echo "CUPS_DEBUG_LEVEL=$CUPS_DEBUG_LEVEL; export CUPS_DEBUG_LEVEL" >>$runcups
	echo "CUPS_DEBUG_LOG='$CUPS_DEBUG_LOG'; export CUPS_DEBUG_LOG" >>$runcups
    fi
    echo "" >>$runcups
    echo "# Run command..." >>$runcups
    echo "exec \"\$@\"" >>$runcups

    chmod +x $runcups

    #
    # Create config file for cups-browsed...
    #

    echo "Creating cups-browsed.conf for test..."
    echo "The 'BrowseFilter service $queue_prefix' lets cups-browsed"
    echo "only craete queues for 'our' ippeveprinter printers"

    cat >$BASE/cups-browsed.conf <<EOF
CacheDir $BASE/cache
BrowseRemoteProtocols dnssd cups
CreateIPPPrinterQueues Driverless
BrowseFilter service $queue_prefix
KeepGeneratedQueuesOnShutdown No
EOF

    #
    # Set a new home directory to avoid getting user options mixed in...
    #

    HOME=$BASE
    export HOME

    #
    # Force POSIX locale for tests...
    #

    LANG=C
    export LANG

    LC_MESSAGES=C
    export LC_MESSAGES

    #
    # Start the CUPS server; run as foreground daemon in the background...
    #

    echo "Starting cupsd:"
    echo "    $runcups $VALGRIND $BASE/bin/cupsd -c $BASE/cupsd.conf -f >$BASE/log/cupsd_debug_log 2>&1 &"
    echo ""

    $runcups $VALGRIND $BASE/bin/cupsd -c $BASE/cupsd.conf -f >$BASE/log/cupsd_debug_log 2>&1 &

    cupsd=$!

    #
    # Start cups-browsed; run as foreground daemon in the background...
    #

    echo "Starting cups-browsed:"
    echo "    $runcups $VALGRIND ../cups-browsed --debug -c $BASE/cups-browsed.conf >$BASE/log/cups-browsed_debug_log 2>&1 &"
    echo ""

    nohup $runcups $VALGRIND ../cups-browsed --debug -c $BASE/cups-browsed.conf >$BASE/log/cups-browsed_debug_log 2>&1 &

    cups_browsed=$!

fi

if test "x$testtype" = x0; then
    # Not running tests...
    if (test "x$cupsd" != "x"); then
	echo "cupsd is PID $cupsd and is listening on port $port."
    fi
    if (test "x$cups_browsed" != "x"); then
	echo "cups-browsed is PID $cups_browsed."
    fi
    echo ""

    echo "The $runcups helper script can be used to test programs"
    echo "with the server."
    exit 0
fi

if test $argcount -eq 0 -a $makecheck = 0; then
    if (test "x$cupsd" != "x"); then
	echo "cupsd is PID $cupsd."
    fi
    if (test "x$cups_browsed" != "x"); then
	echo "cups-browsed is PID $cups_browsed."
    fi
    if (test "x$cups_browsed" != "x" -o "x$cupsd" != "x"); then
	echo "Run debugger now if you need to."
	echo ""
	echo $ac_n "Press ENTER to continue... $ac_c"
	read junk
    fi
else
    if (test "x$cupsd" != "x"); then
	echo "cupsd is PID $cupsd."
    fi
    if (test "x$cups_browsed" != "x"); then
	echo "cups-browsed is PID $cups_browsed."
    fi
    sleep 2
fi

#
# Start some instances of ippeveprinter to emulate some IPP printers
# to be discovered
#
# The $queue_prefix in the service name is to make the service names unique
# to this test, to not clash with other printers and to tell cups-browsed
# what "our" test printers are.
#

if test -n "$BASE"; then
    IPPEVEBASE=$BASE/ippeve
else
    IPPEVEBASE=/tmp/cups-browsed-${user}/ippeve
fi

rm -rf $IPPEVEBASE
mkdir -p $IPPEVEBASE/spool/1
mkdir -p $IPPEVEBASE/spool/2
mkdir -p $IPPEVEBASE/log

echo "Color duplex printer $queue_prefix-ippeve-1._ipps._tcp.local, accepting JPEG, Apple Raster/URF, PWG Raster, and PDF"

while true; do
    nohup ippeveprinter -vvvv -s 10,10 -2 -f "image/jpeg,image/pwg-raster,image/urf,application/pdf" -d "$IPPEVEBASE/spool/1" -k "$queue_prefix-ippeve-1" > $IPPEVEBASE/log/ippeve1_log 2>&1 &
    ipp_eve_pid1=$!
    sleep 2
    if ipptool -tv `driverless | grep "$queue_prefix-ippeve-1"` get-printer-attributes.test >/dev/null; then
	break;
    else
	echo "ippeveprinter not responding, re-launching ..."
	kill -TERM $ipp_eve_pid1 2>/dev/null
	sleep 2
	kill -KILL $ipp_eve_pid1 2>/dev/null
    fi
done

echo "   ippeveprinter PID: $ipp_eve_pid1"
echo ""

echo "Monochrome printer $queue_prefix-ippeve-2._ipps._tcp.local, accepting Apple Raster/URF, PWG Raster, and PDF"

nohup ippeveprinter -vvvv -s 10,0 -f "image/pwg-raster,image/urf,application/pdf" -d "$IPPEVEBASE/spool/2" -k "$queue_prefix-ippeve-2" > $IPPEVEBASE/log/ippeve2_log 2>&1 &
ipp_eve_pid2=$!

echo "   ippeveprinter PID: $ipp_eve_pid2"
echo ""

if test "x$testtype" = x1; then
    # Not running tests...
    exit 0
fi

if test $argcount -eq 0 -a $makecheck = 0; then
    echo "Run debugger now if you need to."
    echo ""
    echo $ac_n "Press ENTER to continue... $ac_c"
    read junk
else
    sleep 2
fi

# Basic functionality tests, more to be added later

#
# Wait for cups-browsed creating queues, check queues, there are 2 of CUPS
# (only non-root), 2 of cups-browsed
#

echo ""
echo "\$ driverless | grep $queue_prefix"
driverless | grep $queue_prefix
echo ""

echo "\$ lpstat -v"
$runcups lpstat -v
echo ""

tries=1
timeout=301
while test $tries -lt $timeout; do
    lpstatv=`$runcups lpstat -v 2>/dev/null | grep implicitclass: 2>/dev/null`
    if `echo $lpstatv | grep -q "${queue_prefix}_ippeve_1"` && `echo $lpstatv | grep -q "${queue_prefix}_ippeve_2"`; then
	break
    fi

    echo "Waiting for print queues getting created by cups-browsed ($tries sec)..."
    sleep 1

    tries=`expr $tries + 1`
done

echo ""
echo "\$ lpstat -v"
$runcups lpstat -v
echo ""

if test $tries -ge $timeout; then
    echo "FAIL: cups-browsed did not create CUPS queues for the 2 test printers!"
    clean_up 1
    exit 1
fi

#
# Send job(s) wait for job(s) getting printed, spool file(s) in URF/Apple Raster
# format
#

testfile=default-testpage.pdf
testfile_=`echo $testfile | sed -e 's/\./_/'`

echo "\$ lp -d ${queue_prefix}_ippeve_1 $sys_datadir/data/$testfile"
$runcups lp -d ${queue_prefix}_ippeve_1 $sys_datadir/data/$testfile
echo ""
echo "\$ lpstat -o"
$runcups lpstat -o
echo ""

tries=1
timeout=301
while test $tries -lt $timeout; do
    lpstato=`$runcups lpstat -o 2>/dev/null`
    if ! `echo $lpstato | grep -q "${queue_prefix}_ippeve_1-"`; then
	break
    fi

    echo "Waiting for print job to complete ($tries sec)..."
    sleep 1

    tries=`expr $tries + 1`
done

echo ""
echo "\$ lpstat -o"
$runcups lpstat -o
echo ""

echo ""
echo "\$ ls -l $IPPEVEBASE/spool/1"
ls -l $IPPEVEBASE/spool/1
echo ""

if test $tries -ge $timeout; then
    echo "FAIL: Test print job did not complete!"
    clean_up 1
    exit 1
fi

if ! ls -l $IPPEVEBASE/spool/1/1-${testfile_}.urf > /dev/null 2>&1; then
    echo "FAIL: Test printer did not receive job file (1-{$testfile_}.urf)!"
    clean_up 1
    exit 1
fi

if ! grep -q '^UNIRAST' $IPPEVEBASE/spool/1/1-${testfile_}.urf; then
    echo "FAIL: Job file (1-{$testfile_}.urf) is not Apple Raster/URF (URF should be preferred against the also supported PDF)!"
    clean_up 1
    exit 1
fi

#
# Kill first test printer and see whether cups-browsed removes its CUPS
# queue but keeps the queue of the other test printer
#

echo "\$ ps au | grep ippeveprinter"
ps au | grep ippeveprinter | grep -v grep
echo ""
echo "\$ lpstat -v"
$runcups lpstat -v
echo ""

echo "\$ kill -TERM $ipp_eve_pid1"
kill -TERM $ipp_eve_pid1
echo ""

echo "\$ ps au | grep ippeveprinter"
ps au | grep ippeveprinter | grep -v grep
echo ""

tries=1
timeout=61
while test $tries -lt $timeout; do
    if ! `ps | grep '^ *'"${ipp_eve_pid1}"' ' 2>/dev/null`; then
	break
    fi

    echo "Waiting for first test printer (cups-browsed's queue ${queue_prefix}_ippeve_1) to shut down ..."
    sleep 1

    tries=`expr $tries + 1`
done

echo "\$ ps au | grep ippeveprinter"
ps au | grep ippeveprinter | grep -v grep
echo ""

if test $tries -ge $timeout; then
    echo "FAIL: First test printer (cups-browsed's queue ${queue_prefix}_ippeve_1) did not shut down!"
    clean_up 1
    exit 1
fi

ipp_eve_pid1=

#
# cups-browsed queue 1 goes away and queue 2 stays
#

echo "\$ lpstat -v"
$runcups lpstat -v
echo ""

tries=1
timeout=301
while test $tries -lt $timeout; do
    lpstatv=`$runcups lpstat -v 2>/dev/null | grep implicitclass: 2>/dev/null`
    if ! `echo $lpstatv | grep -q "${queue_prefix}_ippeve_1"`; then
	break
    fi

    echo "Waiting for cups-browsed to remove the queue for the first test printer ($tries sec)..."
    sleep 1

    tries=`expr $tries + 1`
done

if test $tries -ge $timeout; then
    echo "FAIL: cups-browsed did not remove CUPS queue ${queue_prefix}_ippeve_1 for first test printer!"
    clean_up 1
    exit 1
fi

if ! `echo $lpstatv | grep -q "${queue_prefix}_ippeve_2"`; then
    echo "FAIL: Print queue of second test printer ${queue_prefix}_ippeve_2 disappeared when we shut down the first test printer!"
    clean_up 1
    exit 1
fi

#
# Kill second test printer and see whether cups-browsed removes its CUPS
# queue
#

echo "\$ ps au | grep ippeveprinter"
ps au | grep ippeveprinter | grep -v grep
echo ""
echo "\$ lpstat -v"
$runcups lpstat -v
echo ""

echo "\$ kill -TERM $ipp_eve_pid2"
kill -TERM $ipp_eve_pid2
echo ""

echo "\$ ps au | grep ippeveprinter"
ps au | grep ippeveprinter | grep -v grep
echo ""

tries=1
timeout=61
while test $tries -lt $timeout; do
    if ! `ps | grep '^ *'"${ipp_eve_pid2}"' ' 2>/dev/null`; then
	break
    fi

    echo "Waiting for second test printer (cups-browsed's queue ${queue_prefix}_ippeve_2) to shut down ..."
    sleep 1

    tries=`expr $tries + 1`
done

echo "\$ ps au | grep ippeveprinter"
ps au | grep ippeveprinter | grep -v grep
echo ""

if test $tries -ge $timeout; then
    echo "FAIL: Second test printer (cups-browsed's queue ${queue_prefix}_ippeve_2) did not shut down!"
    clean_up 1
    exit 1
fi

ipp_eve_pid2=

#
# cups-browsed queue 2 goes away
#

echo "\$ lpstat -v"
$runcups lpstat -v
echo ""

tries=1
timeout=301
while test $tries -lt $timeout; do
    lpstatv=`$runcups lpstat -v 2>/dev/null | grep implicitclass: 2>/dev/null`
    if ! `echo $lpstatv | grep -q "${queue_prefix}_ippeve_2"`; then
	break
    fi

    echo "Waiting for cups-browsed to remove the queue for the second test printer ($tries sec)..."
    sleep 1

    tries=`expr $tries + 1`
done

echo "\$ lpstat -v"
$runcups lpstat -v
echo ""

if test $tries -ge $timeout; then
    echo "FAIL: cups-browsed did not remove CUPS queue ${queue_prefix}_ippeve_2 for second test printer!"
    clean_up 1
    exit 1
fi

#
# Kill cups-browsed (if we had started it)
#

if (test "x$cups_browsed" != "x"); then
    echo "\$ ps au | grep cups-browsed"
    ps au | grep cups-browsed | grep -v grep
    echo ""

    echo "\$ kill -TERM $cups_browsed"
    kill -TERM $cups_browsed
    echo ""

    echo "\$ ps au | grep cups-browsed"
    ps au | grep cups-browsed | grep -v grep
    echo ""

    tries=1
    timeout=61
    while test $tries -lt $timeout; do
	if ! `ps | grep '^ *'"${cups_browsed}"' ' 2>/dev/null`; then
	    break
	fi

	echo "Waiting for cups-browsed to shut down ..."
	sleep 1

	tries=`expr $tries + 1`
    done

    echo "\$ ps au | grep cups-browsed"
    ps au | grep cups-browsed | grep -v grep
    echo ""

    if test $tries -ge $timeout; then
	echo "FAIL: cups-browsed did not shut down!"
	clean_up 1
	exit 1
    fi

    cups_browsed=
fi

echo "SUCCESS: All tests were successful."
echo ""

clean_up 0
exit 0
