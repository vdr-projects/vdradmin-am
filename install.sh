#!/bin/sh
# Copyright (c) 2005 Andreas Mair
#
#
# Download and patchscript for VDRAdmin-AM
# (based on install.sh Copyright (c) 2003 Frank (xpix) Herrmann)

PATH=$PATH:/sbin:/bin:/usr/sbin:/usr/bin
DESTDIR=${DESTDIR}
LIBDIR=${LIBDIR:-$DESTDIR/usr/share/vdradmin}
ETCDIR=${ETCDIR:-$DESTDIR/etc/vdradmin}
DOCDIR=${DOCDIR:-$DESTDIR/usr/share/doc/vdradmin}
BINDIR=${BINDIR:-$DESTDIR/usr/bin}
LOCDIR=${LOCDIR:-$DESTDIR/usr/share/locale}
MANDIR=${MANDIR:-$DESTDIR/usr/share/man/man1}
LOGDIR=${LOGDIR:-$DESTDIR/var/log}
PIDFILE=${PIDFILE:-$DESTDIR/var/run/vdradmind.pid}
VIDEODIR=${VIDEODIR:-/video}
VDRCONF=${VDRCONF:-$VIDEODIR}
EPGDATA=${EPGDATA:-$VIDEODIR/epg.data}

LANGS="de es fr fi"

function usage()
{
	echo ""
	echo "usage: $(basename $0) [-c | -u | -p | -h]"
	echo ""
	echo -e "\t-c : Run \"vdradmind.pl -c\" after installation (=configure)."
	echo -e "\t-u : Perform uninstall."
	echo -e "\t-p : Only install needed Perl modules (NOT YET FINISHED!!!)."
	echo -e "\t-h : This message."
	echo ""
	exit 0
}

function killRunningVDRAdmin()
{
	local KILLED=0
	ps a | grep vdradmind.pl | grep perl | grep -v grep | while read PID UNWANTED
	do
		KILLED=1
		kill $PID
	done

	return $KILLED
}

# $1 - the Perl module to check for.
function checkPerlModule()
{
	[ -z "$1" ] && return 1

	local MODULE=$1

	echo -n "Checking for Perl module $MODULE... "
	perl -ce 'BEGIN{$0 =~ /(^.*\/)/; $BASENAME = $1; unshift(@INC, $BASENAME . "lib/");} use '$MODULE >/dev/null 2>&1
	if [ $? -eq 2 ]; then
		echo "MISSING"
		read -p "Do you want to install it? [y/N]"
		[ $REPLY = "y" -o $REPLY = "Y" ] && su -c "perl -MCPAN -e 'install Locale::gettext'"
	else
		echo "found"
	fi

}

function perlModules()
{
	checkPerlModule Template
	checkPerlModule Compress::Zlib
	checkPerlModule CGI
	checkPerlModule IO::Socket
	checkPerlModule Time::Local
	checkPerlModule MIME::Base64
	checkPerlModule File::Temp
	checkPerlModule Locale::gettext
}

function makeDir()
{
	[ -z "$1" ] && return 1
	local DIR=$1
	if [ ! -e "$DIR" ]; then
		mkdir -p "$DIR"
		if [ $? -ne 0 ]; then
			echo "Failed to create directory $DIR!"
			echo "Aborting..."
			return 1
		fi
	fi
	if [ ! -d "$DIR" ]; then
		echo "$DIR exists but is no directory!"
		echo "Aborting..."
		return 1
	fi

	return 0
}

function doInstall()
{
	echo ""
	echo "********* Installing VDRAdmin-AM *************"
	echo ""

	perlModules

	makeDir $LIBDIR && cp -r template lib $LIBDIR || exit 1
  makeDir $DOCDIR && cp -r contrib COPYING CREDITS HISTORY INSTALL README $DOCDIR || exit 1
	makeDir $MANDIR && cp vdradmind.pl.1 $MANDIR || exit 1
	makeDir $ETCDIR || exit 1

	for lang in $LANGS
	do
		makeDir $LOCDIR/$lang/LC_MESSAGES/ && install -m 644 locale/$lang/LC_MESSAGES/vdradmin.mo $LOCDIR/$lang/LC_MESSAGES/vdradmin.mo || exit 1
	done

	local RESTART=
	[ ! -e $BINDIR ] && mkdir -p $BINDIR
	if [ -d $BINDIR ]; then
		killRunningVDRAdmin
		if [ $? -ne 0 ] ; then
			RESTART=1
  		echo "Killed running VDRAdmin-AM..."
  	fi
  	sed <vdradmind.pl >$BINDIR/vdradmind.pl \
  	    -e "s/^my \$SEARCH_FILES_IN_SYSTEM = 0;/my \$SEARCH_FILES_IN_SYSTEM = 1;/" \
  	    -e "s:/usr/share/vdradmin/lib:${LIBDIR}/lib:" \
  	    -e "s:/usr/share/vdradmin/template:${LIBDIR}/template:" \
  	    -e "s:/var/log/\$CONFIG{LOGFILE}:${LOGDIR}/\$CONFIG{LOGFILE}:" \
  	    -e "s:/var/run/vdradmind.pid:${PIDFILE}:" \
  	    -e "s:\(\$ETCDIR *= \)\"/etc/vdradmin\";:\1\"${ETCDIR}\";:" \
  	    -e "s:/usr/share/locale:${LOCDIR}:" \
  	    -e "s:\(\$CONFIG{VIDEODIR} *= \)\"/video\";:\1\"${VIDEODIR}\";:" \
				-e "s:\(\$CONFIG{VDRCONFDIR} *= \)\"\$CONFIG{VIDEODIR}\";:\1\"${VDRCONF}\";:" \
				-e "s:\(\$CONFIG{EPG_FILENAME} *= \)\"\$CONFIG{VIDEODIR}/epg.data\";:\1\"${EPGDATA}\";:"

		chmod a+x  $BINDIR/vdradmind.pl

  	if [ "$CONFIG" ]; then
    	echo "Configuring VDRAdmin-AM..."
    	$BINDIR/vdradmind.pl -c
  	fi

  	if [ "$RESTART" ]; then
  		echo "Restarting VDRAdmin-AM..."
  		$BINDIR/vdradmind.pl
  	fi
	else
		echo "$BINDIR exists but is no directory!"
		echo "Aborting..."
		exit 1
	fi

	echo ""
	echo ""
	echo "VDRAdmin-AM has been installed!"
	echo ""
	if [ -z "$RESTART" ]; then
		echo "Run \"$BINDIR/vdradmind.pl\" to start VDRAdmin-AM."
		echo ""
	fi
	echo "NOTE:"
	echo "If you would like VDRAdmin-AM to start at system's boot, please modify your system's init scripts."
	exit 0
}

function doUninstall()
{
	echo ""
	echo "********* Uninstalling VDRAdmin-AM *************"
	echo ""

	killRunningVDRAdmin
	if [ -d $DOCDIR ]; then
		rm -rf $DOCDIR
	fi
	if [ -d $LIBDIR ]; then
		rm -rf $LIBDIR
	fi
	if [ -e $MANDIR/vdradmind.pl.1 ]; then
		rm -f $MANDIR/vdradmind.pl.1
	fi
	if [ -e $BINDIR/vdradmind.pl ]; then
		rm -f $BINDIR/vdradmind.pl
	fi
	for lang in $LANGS
	do
		[ -e $LOCDIR/$lang/LC_MESSAGES/vdradmin.mo ] && rm -f $LOCDIR/$lang/LC_MESSAGES/vdradmin.mo
	done

	echo ""
	echo "VDRAdmin-AM has been uninstalled!"
	echo ""
	if [ -d $ETCDIR ]; then
		echo "Your configuration files located in $ETCDIR have NOT been deleted!"
		echo "If you want to get rid of them, please delete them manually!"
		echo ""
	fi
}

UNINSTALL=
CONFIG=
PERL=
while [ "$1" ]
do
	case $1 in
		-u) UNINSTALL=1;;
		-c) CONFIG=1;;
		-p) PERL=1;;
		-h) usage;;
		*) echo "Ignoring param \"$1\$.";;
	esac
	shift
done

if [ $(basename $0) = "uninstall.sh" -o "$UNINSTALL" ]; then
	doUninstall
elif [ "$PERL" ]; then
	echo ""
	echo "Only LISTING needed Perl modules..."
	perlModules
	echo "...done."
else
	doInstall
fi
