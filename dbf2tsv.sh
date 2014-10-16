#!/bin/bash

# make TSV from DBF
# uses dbfdump from shapelib
# user args: 1) input DBF

indbf=$1
header=$(
	dbfdump --info $indbf |\
	sed '1,9d' |\
	awk '{print $2}' |\
	tr '\n' '\t' |\
	sed 's:\t$::g'
)

echo "$header"
dbfdump -fs '	' $indbf
