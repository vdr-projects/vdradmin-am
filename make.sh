#!/bin/bash

LANGS="cs de es fr fi it nl ru"
DIST_FILES="autotimer2searchtimer.pl ChangeLog COPYING CREDITS FAQ HISTORY INSTALL LGPL.txt README README.translators REQUIREMENTS contrib convert.pl install.sh lib locale make.sh template uninstall.sh vdradmind vdradmind.pl vdradmind.pl.1"
INSTALL_SH=./install.sh
TMPDIR=/tmp


# Print usage information and exit
#
function Usage()
{
	echo "Usage: $0 <action>"
	echo
	echo "Available actions:"
	echo "  install   - install VDRAdmin-AM"
	echo "  uninstall - uninstall VDRAdmin-AM"
	echo "  po        - convert .po files to .mo files"
	echo "  dist      - create distribution archive"
	echo "  cl        - create ChangeLog file."
	echo "  check     - check requirements"
	exit 1
}

# Print error message and exit.
#
function Error()
{
	[ "$1" ] && echo $*
	exit 1
}

# Compile and install locales.
#
function do_po()
{
	[ -d locale ] && rm -rf locale/*
	for PO in po/*.po 
	do
		L=$(basename $PO .po)
		[ -d locale/$L/LC_MESSAGES/ ] || mkdir -p locale/$L/LC_MESSAGES/
		msgfmt po/$L.po -o po/$L.mo
		install -m 644 po/$L.mo locale/$L/LC_MESSAGES/vdradmin.mo
		rm -f po/$L.mo
	done
}

# Extract VDRAdmin-AM version from vdradmind.pl
#
function getVersion()
{
	grep "^my \$VERSION" vdradmind.pl | sed -e 's/^[^\"]*\"\([^\"]*\)\".*$/\1/'
}

# Create tar.bz2 for distribution.
#
function do_dist()
{
	local DIST_NAME=vdradmin-am-$(getVersion)
	mkdir -p $TMPDIR/$DIST_NAME
	cp -a $DIST_FILES $TMPDIR/$DIST_NAME
	mkdir -p $TMPDIR/$DIST_NAME/po
	cp -a po/*.po po/*.pot $TMPDIR/$DIST_NAME/po
	(
		cd $TMPDIR
		tar --exclude '.#*' --exclude '.nfs*' -cjf $DIST_NAME.tar.bz2 $DIST_NAME
		rm -rf $TMPDIR/$DIST_NAME
	)
	mv $TMPDIR/$DIST_NAME.tar.bz2 .
}

# create ChangeLog file.
#
function do_cl()
{
	git log > ChangeLog
}

# check requirements.
#
function do_check()
{
	$INSTALL_SH -p
}

[ "$1" ] || Usage
[ -x $INSTALL_SH ] || Error "$INSTALL_SH not found!"

while [ $1 ]
do
	case $1 in
		install)
			$INSTALL_SH -c
			;;

		uninstall)
			$INSTALL_SH -u
			;;

		po)
			do_po
			;;

		local)
			do_po
			;;

		dist)
			do_po
			do_cl
			do_dist
			;;

		cl)
			do_cl;
			;;

		check)
			do_check;
			;;

		help|-h|--help)
			Usage;
			;;
		*)
			Error "Unknown command \"$1\""
			;;
	esac
	shift
done
	
