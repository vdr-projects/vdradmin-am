#!/bin/bash

LANGS="cs de es fr fi it nl ru"
DIST_FILES="autotimer2searchtimer.pl ChangeLog COPYING CREDITS FAQ HISTORY INSTALL README README.translators REQUIREMENTS contrib convert.pl install.sh lib locale make.sh template uninstall.sh vdradmind.pl vdradmind.pl.1"
INSTALL_SH=./install.sh
CVS2CL="./cvs2cl.pl"	# get it at http://www.red-bean.com/cvs2cl/
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
	echo "  utf8add   - generate utf8 locales from existing locales"
	echo "  utf8clean - cleanup utf8 locales"
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
	local additional_langs="$(get_utf8_LANGS)"
	local all_langs="$LANGS $additional_langs"
	for L in $all_langs
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
		tar --exclude CVS --exclude '.#*' --exclude '.nfs*' -cjf $DIST_NAME.tar.bz2 $DIST_NAME
		rm -rf $TMPDIR/$DIST_NAME
	)
	mv $TMPDIR/$DIST_NAME.tar.bz2 .
}

# determine additional (utf8-)languages
#
function get_utf8_LANGS()
{
	(	cd po
		local UTF8LANGS
		local UTF8LANG
		for file in *.utf8.po; do
			[ -e $file ] || continue
			UTF8LANG=${file%.po}
			UTF8LANGS="$UTF8LANGS $UTF8LANG"
		done
		echo $UTF8LANGS
	)
}

# extract original character encoding
#
function getOrigEncoding()
{
	local ENC=$(grep 'msgstr "ISO-8859' $1)
	# strip away "ISO-", because sometimes we need it as "iso"
	ENC=${ENC/'msgstr "ISO-'/}
	ENC=${ENC/'"'/}
	echo $ENC
}


# cleanup utf8 locales
#
function do_utf8_clean()
{
	(cd po && rm -f *.utf8.po*)
}

# generate utf8 locales
#
function do_utf8_generate()
{
	# start clean
	do_utf8_clean

	(	cd po
		local filename
		local encoding
		local newfilename

		# generate utf8 locales for existing translations
		for file in *.po; do
			[ -e $file ] || continue
			filename=${file%.po}
			encoding=iso$(getOrigEncoding $filename.po)
			newfilename=$(echo $filename | tr [:lower:] [:upper:])
			if [ "${encoding}" = "iso8859-1" ]; then
    		# just copy
				cp $filename.po ${filename}_$newfilename.utf8.po ;
			else
				# convert
				iconv -f $encoding -t utf-8 $filename.po > ${filename}_$newfilename.utf8.po
			fi
		done

		# generate us_US.utf8.po from POT template
		msginit -i vdradmin.pot -o en_US.utf8.po -l en_US.utf8 --no-translator

		# map ISO-8859-1 encoding to UTF-8 instead of the respective "old" encodings
		for file in $(ls *.utf8.po); do
			encoding=ISO-$(getOrigEncoding $file)
    	sed -e 's:msgstr "'$encoding'":msgstr "UTF-8":g' $file > $file.tmp
    	mv $file.tmp $file
		done
	)
}

# create ChangeLog file.
#
function do_cl()
{
	[ -x $CVS2CL ] || Error "Missing $CVS2CL (http://www.red-bean.com/cvs2cl/)"
	$CVS2CL --FSF --separate-header --no-wrap --no-times --tagdates --log-opts "-d>2006-07-08"
}

# check requirements.
#
function do_check()
{
	LANGS=$LANGS $INSTALL_SH -p
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
			LANGS=$LANGS $INSTALL_SH -c
			;;

		uninstall)
			LANGS=$LANGS $INSTALL_SH -u
			;;

		po)
			do_po
			;;

		dist)
			do_utf8_clean
			do_cvs
			do_po
			do_cl
			do_dist
			;;

		utf8add)
			do_utf8_generate
			;;

		utf8clean)
			do_utf8_clean
			;;

		cl)
			do_cl;
			;;

		check)
			do_check;
			;;

		*)
			Error "Unknown command \"$1\""
			;;
	esac
	shift
done
	
