# OpenPrinting cups-browsed v2.1.1 - 2025-01-08

Looking for compile instructions?  Read the file "INSTALL"
instead...


## INTRODUCTION

CUPS is a standards-based, open-source printing system used by
Apple's Mac OS® and other UNIX®-like operating systems,
especially also Linux. CUPS uses the Internet Printing Protocol
("IPP") and provides System V and Berkeley command-line
interfaces, a web interface, and a C API to manage printers and
print jobs.

This package contains cups-browsed, a helper daemon to browse the
network for remote CUPS queues and IPP network printers and
automatically create local queues pointing to them.

cups-browsed has the following functionality:

- Auto-discover print services advertised via DNS-SD (network
  printers, IPP-over-USB printers, Printer Applications, remote CUPS
  queues) and create local queues pointing to them. CUPS usually
  automatically creates temporary queues for such print services, but
  several print dialogs use old CUPS APIs and therefore require
  permanent local queues to see such printers.

- Creating printer clusters where jobs are printed to one single queue
  and get automatically passed on to a suitable member printer.
  
  + Manual (via config file) and automatic (equally-named remote CUPS
    printers form local cluster, as in legacy CUPS 1.5.x and older)
    creation of cluster queues

  + If member printers are different models/types, the local queue
    gets the totality of all their features, options, and choices. Job
    goes to printer which actually supports the user-selected job
    settings. So in a cluster of photo printer, fast laser, and large
    format selecting photo paper for example makes the job go to the
    photo printer, duplex makes it go to the laser, A2 paper to the
    large format ... So user has one queue for all printers, they
    select features, not printers for their jobs ...

  + Automatic selection of destination printer depending on job option
    settings

  + Load balancing on equally suitable printers

  + `implicitclass` backend holds the job, waits for instructions
    about the destination printer of cups-browsed, converts the (PDF)
    job to one of the destination's (driverless) input formats, and
    passes on the job.

- Highly configurable: Which printers are considered? For which type
  of printers queues are created? Cluster types and member printers?
  which names auto-created queues should get? DNS-SD and/or
  BrowsePoll? ...

- Multi-threading allows several tasks to be done in parallel and
  assures responsiveness of the daemon when there is a large amount of
  printers available in the network.

For compiling and using this package CUPS (2.2.2 or newer),
libcupsfilters 2.x, libppd, libavahi-common, libavahi-client, libdbus,
and glib are needed.

It also needs gcc (C compiler), automake, autoconf, autopoint, and
libtool. On Debian, Ubuntu, and distributions derived from them you
could also install the "build-essential" package to auto-install most
of these packages.

Report bugs to [GitHub Issues for cups-browsed](https://github.com/OpenPrinting/cups-browsed/issues)

See the "COPYING", "LICENCE", and "NOTICE" files for legal
information. The license is the same as for CUPS, for a maximum of
compatibility.

## LINKS

* [Short history of cups-browsed](https://openprinting.github.io/achievements/#cups-browsed)

## TEST SUITE

The script test/run-tests.sh creates emulations of IPP printers via
"ippeveprinter" (of CUPS 2.x) and checks whether cups-browsed creates
corresponding CUPS queues, whether a job to such a queue gets actually
printed, and whether cups-browsed removes the queues again when the
printers are shut down.

SIDE EFFECT: By developing this script cups-browsed got tested running
as non-root user (only needs to be member of the "lpadmin" group) and
works properly this way. Appropriate distribution packaging is
recommended to improve system security.

REQUIREMENTS:

Most of these are already needed for building or using cups-browsed.

- CUPS 2.x must be installed: cupsd, lpstat, lp, ippevepriner,
  cups-config, and everything needed to run cupsd.

- cups-filters 2.x needs to be installed, providing the filters for
  processing print jobs and the "driverless" utility to discover
  printers via shell script.

- cups-browsed 2.x needs to be installed for test mode 3 or for
  running the script as root.

The script has different modes:

- Run without arguments by "make" it goes into "make check" mode,
  copying the files of the system's CUPS (to pull it out of the
  distro's AppArmor harness of the distro, run it as normal
  user, and modify the configuration) to run an own CUPS instance
  on port 8631, and running the cups-browsed executable built
  by "make", attached to this CUPS instance.

- Run without arguments directly it asks the use for the test mode
  and whether tey want to run the daemons under Valgrind. Modes are

  + 0: Only start cupsd and cups-browsed, for manual testing
    independent of the system's environment
  + 1: As 0, but also run the 2 ippeveprinter instances to emulate
    printers
  + 2: Run the "make check" mode described above.
  + 3: Do the same tests as in "make check" mode, but use the system's
    CUPS and cups-browsed. This mode is for the autopkgtest of Debian
    and Ubuntu, or for CI tests in general.

- Run with a number (0-3) as argument the appropriate mode is selected,
  run with a number (0-3) as first and "yes" or "no" as second argument
  using or not using Valgrind is also selected.

- Running the script as root always uses the system's CUPS and
  cups-browsed.

The test's CUPS instance and all log files are held in
/tmp/cups-browsed${USER}/.

## DOCUMENTATION FROM CUPS-FILTERS 1.x

Most of this is still valid for the current cups-browsed.

### HELPER DAEMON FOR BROWSING REMOTE CUPS PRINTERS AND IPP NETWORK PRINTERS

From version 1.6.0 on in CUPS the CUPS broadcasting/browsing
facility was dropped, in favour of DNS-SD-based broadcasting of
shared printers. This is done as DNS-SD broadcasting of shared
printers is a standard, established by the PWG (Printing Working
Group, http://www.pwg.org/), and most other network services
(shared file systems, shared media files/streams, remote desktop
services, ...) are also broadcasted via DNS-SD.

Problem is that CUPS only broadcasts its shared printers but does
not browse broadcasts of other CUPS servers to make the shared
remote printers available locally without any configuration
efforts. This is a regression compared to the old CUPS
broadcasting/browsing. The intention of CUPS upstream is that the
application's print dialogs browse the DNS-SD broadcasts as an
AirPrint-capable iPhone does, but it will take its time until all
toolkit developers add the needed functionality, and programs
using old toolkits or no toolkits at all, or the command line stay
uncovered.

The solution is cups-browsed, a helper daemon running in parallel to
the CUPS daemon which listens to DNS-SD broadcasts of shared CUPS
printers on remote machines in the local network via Avahi. For each
reported remote printer it creates a local raw queue pointing to the
remote printer so that the printer appears in local print dialogs and
is also available for printing via the command line. As with the
former CUPS broadcasting/browsing with this queue the driver on the
server is used and the local print dialogs give access to all options
of the server-side printer driver.

Also high availability with redundant print servers and load
balancing is supported. If there is more than one server providing
a shared print queue with the same name, cups-browsed forms a
cluster locally with this name as queue name and printing through
the "implicitclass" backend. Each job triggers cups-browsed to
check which remote queue is suitable for the job, meaning that it
is enabled, accepts jobs, and is not currently printing.  If none
of the remote queues fulfills these criteria, we check again in 5
seconds, until a printer gets free to accommodate the job. When we
search for a free printer, we do not start at the first in the
list, but always on the one after the last one used (as CUPS also
does with classes), so that all printer get used, even if the
frequency of jobs is low. This is also what CUPS formerly did with
implicit classes. Optionally, jobs can be sent immediately into
the remote queue with the lowest number of waiting jobs, so that
no local queue of waiting jobs is built up.

For maximum security cups-browsed uses IPPS (encrypted IPP)
whenever possible.

In addition, cups-browsed is also capable of discovering IPP
network printers (native printers, not CUPS queues) with known
page description languages (PWG Raster, Apple Raster, PDF,
PostScript, PCL XL, PCL 5c/e) in the local network and auto-create
print queues with auto-created PPD files. This functionality is
primarily for mobile devices running CUPS to not need a printer
setup tool nor a collection of printer drivers and PPDs.

cups-browsed can also be started on-demand, for example to save
resources on mobile devices. For this, cups-browsed can be set
into an auto shutdown mode so that it stops automatically when it
has no remote printers to take care of any more, especially if an
on-demand running avahi-daemon stops. Note that CUPS must stay
running for cups-browsed removing its queues and so being able to
shut down. Ideal is if CUPS stays running another 30 seconds after
finishing its last job so that cups-browsed can take down the
queue. For how to set up and control this mode via command line,
configuration directives, or sending signals see the man pages
cups-browsed(8) and cups-browsed.conf(5).

The configuration file for cups-browsed is
/etc/cups/cups-browsed.conf.  This file can include limited forms
of the original CUPS BrowseRemoteProtocols, BrowseLocalProtocols,
BrowsePoll, and BrowseAllow directives. It also can contain the
new CreateIPPPrinterQueues to activate discovering of IPP network
printers and creating PPD-less queues for them.

Note that cups-browsed does not work with remote CUPS servers
specified by a client.conf file. It always connects to the local
CUPS daemon by setting the CUPS_SERVER environment variable and so
overriding client.conf. If your local CUPS daemon uses a
non-standard domain socket as only way of access, you need to
specify it via the DomainSocket directive in
/etc/cups/cups-browsed.conf.

The "make install" process installs init scripts which make the
daemon automatically started during boot. You can also manually
start it with (as root):

    /usr/sbin/cups-browsed &

or in debug mode with

    /usr/sbin/cups-browsed --debug

Shut it down by sending signal 2 (SIGINT) or 15 (SIGTERM) to
it. The queues which it has created get removed then (except a
queue set as system default, to not loose its system default
state).

On systems using systemd use a
/usr/lib/systemd/system/cups-browsed.service file like this:

    [Unit]
    Description=Make remote CUPS printers available locally
    After=cups.service avahi-daemon.service
    Wants=cups.service avahi-daemon.service

    [Service]
    ExecStart=/usr/sbin/cups-browsed

    [Install]
    WantedBy=multi-user.target

On systems using Upstart use an /etc/init/cups-browsed.conf file like this:

    start on (filesystem
              and (started cups or runlevel [2345]))
    stop on runlevel [016]

    respawn
    respawn limit 3 240

    pre-start script
        [ -x /usr/sbin/cups-browsed ]
    end script

    exec /usr/sbin/cups-browsed

These files are included in the source distribution as
utils/cups-browsed.service and utils/cups-browsed-upstart.conf.

In the examples we start cups-browsed after starting
avahi-daemon. This is not required. If cups-browsed starts first,
then Bonjour/DNS-SD browsing kicks in as soon as avahi-daemon comes
up. cups-browsed is also robust against any shutdown and restart
of avahi-daemon.

Here is some info on how cups-browsed works internally (first concept of a
daemon which does only DNS-SD browsing):

    - Daemon start
      o Wait for CUPS daemon if it is not running
      o Read out all CUPS queues created by this daemon (in former sessions)
      o Mark them unconfirmed and set timeout 10 sec from now
    - Main loop (use avahi_simple_poll_iterate() to do queue list maintenance
                 regularly)
      o Event: New printer shows up
        + Queue for printer is already created by this daemon -> Mark list
          entry confirmed, if discovered printer is ipps but existing queue ipp,
	  upgrade existing queue by setting URI to ipps. Set status to
	  to-be-created and timeout to now-1 sec to make the CUPS queue be
	  updated.
        + Queue does not yet exist -> Mark as to-be-created and set
	  timeout to now-1 sec.
      o Event: A printer disappears
        + If we have listed a queue for it, mark the entry as disappeared, set
          timeout to now-1 sec
      o On any of the above events and every 2 sec
        + Check through list of our listed queues
          - If queue is unconfirmed and timeout has passed, mark it as
            disappeared, set timeout to now-1 sec
          - If queue is marked disappered and timeout has passed, check whether
	    there are still jobs in it, if yes, set timeout to 10 sec from now,
	    if no, remove the CUPS queue and the queue entry in our list. If
	    removal fails, set timeout to 10 sec.
	  - If queue is to-be-created, create it, if succeeded set to
	    confirmed, if not, set timeout to 10 sec fron now. printer-is-shared
	    must be set to false.
    - Daemon shutdown
      o Remove all CUPS queues in our list, as long as they do not have jobs.

Do not overwrite existing queues which are not created by us If
the simple <remote_printer> name is already taken, try to create a
<remote_printer>@<server> name, if this is also taken, ignore the
remote printer. Do not retry, to avoid polling CUPS all the time.

Do not remove queues which are not created by us. We do this by
listing only our queues and remove only listed queues.

Queue names: Use the name of the remote queue. If a queue with the
same name from another server already exists, mark the new queue
as duplicate and when a queue disappears, check whether it has
duplicates and change the URI of the disappeared queue to the URI
of the first duplicate, mark the queue as to-be-created with
timeout now-1 sec (to update the URI of the CUPS queue) and mark
the duplicate disappeared with timeout now-1 sec. In terms of
high availability we replace the old load balancing of the
implicit class by a failover solution. Alternatively (not
implemented), if queue with same name but from other server
appears, create new queue as <original name>@<server name without
.local>. When queue with simple name is removed, replace the first
of the others by one with simple name (mark old queue disappeared
with timeout now-1 sec and create new queue with simple name).

Fill description of the created CUPS queue with the DNS-SD
service name (= original description) and location with the server
name without .local.

stderr messages only in debug mode (command line options:
"--debug" or "-d" or "-v").

Queue identified as from this daemon by doing the equivalent of
"lpadmin -p printer -o cups-browsed-default", this generates a
"cups-browsed" attribute in printers.conf with value "true".


