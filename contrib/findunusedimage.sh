#!/bin/bash

for i in bilder/*; do
  grep `basename $i` *.html >/dev/null
	if [ $? != 0 ]; then
	  echo $i
	fi
done
