#!/bin/sh

[ -z "$1" ] && exit 1

cat $1 | sed -e 's#<\(tmpl_[^>]*\)>#<%!\1 /!%>#g' -e 's#</\(tmpl_[^>]*\)>#<%!\1 /!%>#g' | tidy -xml
#cat $1 | sed -e 's#\(<tmpl_var [^>]*\)>#\1 />#g' -e 's#\(<tmpl_else\)>#\1 />#g' | tidy -xml
