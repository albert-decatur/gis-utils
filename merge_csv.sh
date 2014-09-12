#!/bin/bash

# this is just a way to cat CSV without headers causing trouble
# NB: expects input txt files to have identical headers, extension must be .csv, and to all be in the same dir
# user args: 1) input directory of text files, 2) output text file
# example use: $0 /tmp/ /tmp/out.csv

indir=$1
out=$2
rm $out 2>/dev/null
cd $indir
header_origin=$( find $indir -type f -iregex ".*[.]csv$" | sed -n '1p')
header=$( cat $header_origin | head -n 1 )
echo "$header" > $out
for csv in $( find $indir -type f -iregex ".*[.]csv$" | sed '1d' )
do 
	cat $csv | sed '1d'
done >> $out
