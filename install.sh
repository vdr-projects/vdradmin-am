#!/bin/bash
# vim:noet:sw=4:ts=4:
# Copyright (c) 2005-2014 Andreas Mair
#
#
# Download and patchscript for VDRAdmin-AM
# (based on install.sh Copyright (c) 2003 Frank (xpix) Herrmann)

PATH=$PATH:/sbin:/bin:/usr/sbin:/usr/bin
PREFIX=${PREFIX}
LIBDIR=${LIBDIR:-$PREFIX/usr/share/vdradmin}
ETCDIR=${ETCDIR:-$PREFIX/etc/vdradmin}
DOCDIR=${DOCDIR:-$PREFIX/usr/share/doc/vdradmin}
BINDIR=${BINDIR:-$PREFIX/usr/bin}
LOCDIR=${LOCDIR:-$PREFIX/usr/share/locale}
MANDIR=${MANDIR:-$PREFIX/usr/share/man}
LOGDIR=${LOGDIR:-$PREFIX/var/log/vdradmin}
CACHEDIR=${CACHEDIR:-$PREFIX/var/cache/vdradmin}
PIDFILE=${PIDFILE:-$PREFIX/var/run/vdradmin/vdradmind.pid}
VIDEODIR=${VIDEODIR:-/video}
EPGIMAGES=${EPGIMAGES:-$VIDEODIR/epgimages}
VDRCONF=${VDRCONF:-$VIDEODIR}

function usage()
{
	echo ""
	echo "usage: $(basename $0) [-c | -u | -p | -h]"
	echo ""
	echo -e "\t-c : Run \"vdradmind -c\" after installation (=configure)."
	echo -e "\t-u : Perform uninstall."
	echo -e "\t-p : List and optionally install required Perl modules."
	echo -e "\t-h : This message."
	echo ""
	exit 0
}

function killRunningVDRAdmin()
{
	local KILLED=0
	local PID=$(pidof vdradmind)
	[ "$PID" ] || PID=$(ps a | grep vdradmind.pl | grep perl | grep -v grep | cut -d' ' -f1)
	if [ "$PID" ]; then
		KILLED=1
		kill $PID
	fi

	return $KILLED
}

# $1 - the Perl module to check for.
function checkPerlModule()
{
	[ -z "$1" ] && return 1

	local MODULE=$1
	local ALT_MODULE=$2
	local ALT_MESSAGE=
	[ "$ALT_MODULE" ] && ALT_MESSAGE=" or $ALT_MODULE"

	echo -n "Checking for Perl module $MODULE$ALT_MESSAGE... "
	perl -ce 'BEGIN{$0 =~ /(^.*\/)/; $BASENAME = $1; unshift(@INC, $BASENAME . "lib/");} use '$MODULE >/dev/null 2>&1
	if [ $? -eq 2 ]; then
		if [ "$ALT_MODULE" ]; then
			perl -ce 'BEGIN{$0 =~ /(^.*\/)/; $BASENAME = $1; unshift(@INC, $BASENAME . "lib/");} use '$ALT_MODULE >/dev/null 2>&1
			[ $? -eq 0 ] && echo " $ALT_MODULE found" && return 0
		fi
		echo " MISSING"
		read -p "Do you want to install $MODULE? [y/N]"
		[ "$REPLY" = "y" -o "$REPLY" = "Y" ] && su -c "perl -MCPAN -e 'CPAN::install \"$MODULE\"'"
	else
		echo " found"
	fi
}

function perlModules()
{
	echo ""
	echo "*** Required ***"
	checkPerlModule locale
	checkPerlModule Template
	checkPerlModule Template::Plugin::JavaScript
	checkPerlModule CGI
	checkPerlModule HTTP::Date
	checkPerlModule IO::Socket
	checkPerlModule Time::Local
	checkPerlModule MIME::Base64
	checkPerlModule File::Temp
	checkPerlModule File::Find
	checkPerlModule URI
	checkPerlModule URI::Escape
	checkPerlModule HTTP::Tiny


	echo ""
	echo "You need Locale::gettext OR Locale::Messages"
	checkPerlModule Locale::gettext Locale::Messages

	echo ""
	echo "*** Optional ***"
	echo "* Required for AutoTimer email notification"
	checkPerlModule Net::SMTP
	checkPerlModule Authen::SASL
	echo "* Required for AutoTimer email notification and CRAM-MD5 authentication"
	checkPerlModule Digest::HMAC_MD5
	echo "* Required if VDR and VDRAdmin-AM use different character encoding"
	checkPerlModule Encode
	echo "* Required for IPv6 support"
	checkPerlModule IO::Socket::INET6
	echo "* Required for SSL support (https)"
	checkPerlModule IO::Socket::SSL
	echo "* Required if you want to use gzip'ed HTTP responses"
	checkPerlModule Compress::Zlib
	echo "* Required if you want to log to syslog"
	checkPerlModule Sys::Syslog
}

function makeDir()
{
	[ -z "$1" ] && return 1
	local DIR=$1
	local MUST_CREATE=${2:-0}
	if [ -e "$DIR" -a ! -d "$DIR" ]; then
		echo "$DIR exists but is no directory!"
		echo "Aborting..."
		return 1
	elif [ -d $DIR -a $MUST_CREATE = 1 ]; then
		echo "$DIR exists. Please remove it before calling install.sh!"
		echo "Aborting..."
		return 1
	fi
	if [ ! -e "$DIR" ]; then
		mkdir -p "$DIR"
		if [ $? -ne 0 ]; then
			echo "Failed to create directory $DIR!"
			echo "Aborting..."
			return 1
		fi
	fi

	return 0
}

function doInstall()
{
	echo ""
	echo "********* Installing VDRAdmin-AM *************"
	echo ""

	perlModules

	makeDir $LIBDIR 1 && cp -r template lib $LIBDIR || exit 1
	makeDir $BINDIR || exit 1
	makeDir $DOCDIR && cp -r contrib COPYING CREDITS HISTORY INSTALL LGPL.txt README* REQUIREMENTS FAQ $DOCDIR || exit 1
	makeDir $MANDIR/man8 && cp vdradmind.pl.1 $MANDIR/man8/vdradmind.8 || exit 1

	(
		cd locale
		for lang in *
		do
			makeDir $LOCDIR/$lang/LC_MESSAGES/ && install -m 644 $lang/LC_MESSAGES/vdradmin.mo $LOCDIR/$lang/LC_MESSAGES/vdradmin.mo || exit 1
		done
	)

	local RESTART=
	if [ -d $BINDIR ]; then
		killRunningVDRAdmin
		if [ $? -ne 0 ] ; then
			RESTART=1
			echo "Killed running VDRAdmin-AM..."
		fi
		sed <vdradmind.pl >$BINDIR/vdradmind \
		    -e "s/^\(my \$SEARCH_FILES_IN_SYSTEM *=\) 0;/\1 1;/" \
		    -e "s:/usr/share/vdradmin/lib:${LIBDIR}/lib:" \
		    -e "s:/usr/share/vdradmin/template:${LIBDIR}/template:" \
		   -e "s:/var/log/vdradmin:${LOGDIR}:" \
		    -e "s:/var/cache/vdradmin:${CACHEDIR}:" \
		    -e "s:/var/run/vdradmin/vdradmind.pid:${PIDFILE}:" \
		    -e "s:\(\$ETCDIR *= \)\"/etc/vdradmin\";:\1\"${ETCDIR}\";:" \
		    -e "s:/usr/share/locale:${LOCDIR}:" \
		    -e "s:\(\$CONFIG{VIDEODIR} *= \)\"/video\";:\1\"${VIDEODIR}\";:" \
		    -e "s:\(\$CONFIG{EPGIMAGES} *= \)\"\$CONFIG{VIDEODIR}/epgimages\";:\1\"${EPGIMAGES}\";:" \
				-e "s:\(\$CONFIG{VDRCONFDIR} *= \)\"\$CONFIG{VIDEODIR}\";:\1\"${VDRCONF}\";:"

		chmod a+x  $BINDIR/vdradmind

		if [ "$CONFIG" ]; then
			echo "Configuring VDRAdmin-AM..."
			$BINDIR/vdradmind -c
		fi

		if [ "$RESTART" ]; then
			echo "Restarting VDRAdmin-AM..."
			$BINDIR/vdradmind
		fi

		echo ""
		if [ -e $BINDIR/vdradmind.pl ]; then
			echo "Removing ancient $BINDIR/vdradmind.pl"
			rm -f $BINDIR/vdradmind.pl
		fi
		for man in man1/vdradmind.pl.1 man1/vdradmind.1; do
			if [ -e $MANDIR/$man ]; then
				echo "Removing ancient $MANDIR/$man"
				rm -f $MANDIR/$man
			fi
		done
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
		echo "Run \"$BINDIR/vdradmind\" to start VDRAdmin-AM."
		echo ""
	fi
	echo "NOTE:"
	echo "If you want to run VDRAdmin-AM in a different language you must set the LANG environment variable (see README)."
	echo ""
	echo "NOTE2:"
	echo "If you would like VDRAdmin-AM to start at system's boot, please modify your system's init scripts."

	local USED_DIRS="$(echo -e "$ETCDIR\n$LOGDIR\n$CACHEDIR\n$(dirname "$PIDFILE")" | sort -u)"
	echo
	echo "NOTE3:"
	echo "VDRAdmin-AM needs to access some directories:"
	echo "$USED_DIRS"
	echo
	echo "Please check that the user VDRAdmin-AM runs has enough permissions to access them!"
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
	if [ -d $CACHEDIR ]; then
		rm -rf $CACHEDIR
	fi
	for man in man1/vdradmind.pl.1 man1/vdradmind.1 man8/vdradmind.8; do
		if [ -e $MANDIR/$man ]; then
			rm -f $MANDIR/$man
		fi
	done
	if [ -e $BINDIR/vdradmind.pl ]; then
		rm -f $BINDIR/vdradmind.pl
	fi
	if [ -e $BINDIR/vdradmind ]; then
		rm -f $BINDIR/vdradmind
	fi
	rm -f $LOCDIR/*/LC_MESSAGES/vdradmin.mo

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
	echo "Testing required Perl modules..."
	perlModules
	echo "...done."
else
	doInstall
fi
