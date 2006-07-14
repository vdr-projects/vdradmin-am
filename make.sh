#!/bin/bash

LANGS="de es fr fi nl ru"
DIST_FILES="COPYING CREDITS FAQ HISTORY INSTALL README README.translators REQUIREMENTS contrib convert.pl install.sh lib locale make.sh template uninstall.sh vdradmind.pl vdradmind.pl.1"
INSTALL_SH=./install.sh
TMPDIR=/tmp


# Print usage information and exit
#
function Usage()
{
	echo "Usage: $0 cvs"
	echo "  cvs       - always use this after a \"cvs update \" or \"cvs checkout\""
	echo "  install   - install VDRAdmin-AM"
	echo "  uninstall - uninstall VDRAdmin-AM"
	echo "  po        - convert .po files to .mo files"
	echo "  dist      - create distribution archive"
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
	for L in $LANGS
	do
		[  -d locale/$L/LC_MESSAGES/ ] || mkdir -p locale/$L/LC_MESSAGES/
		msgfmt po/$L.po -o po/$L.mo
		install -m 644 po/$L.mo locale/$L/LC_MESSAGES/vdradmin.mo
		rm -f po/$L.mo
	done
}

# Setup things after CVS checkout or update.
#
function do_cvs()
{
	# Create missing symbolic links
	[ -e uninstall.sh ] || ln -s install.sh uninstall.sh
	[ -e README ] || ln -s INSTALL README
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
		tar --exclude CVS -cjf $DIST_NAME.tar.bz2 $DIST_NAME
		rm -rf $TMPDIR/$DIST_NAME
	)
	mv $TMPDIR/$DIST_NAME.tar.bz2 .
}

[ "$1" ] || Usage
[ -x $INSTALL_SH ] || Error "$INSTALL_SH not found!"

while [ $1 ]
do
	case $1 in
		cvs)
			do_cvs
			;;

		install)
			$INSTALL_SH -c
			;;

		uninstall)
			$INSTALL_SH -u
			;;

		po)
			do_po
			;;

		dist)
			do_dist
			;;

		*)
			Error "Unknown command \"$1\""
			;;
	esac
	shift
done
	
