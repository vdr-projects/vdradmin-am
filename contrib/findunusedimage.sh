#!/bin/bash

echo "This script does not find every used image, because some filenames are generated at runtime!"
for i in bilder/*; do
  grep `basename $i` *.html >/dev/null
	if [ $? != 0 ]; then
	  echo $i
	fi
done
