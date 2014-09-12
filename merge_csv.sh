#!/bin/bash

# this is just a way to cat CSV without headers causing trouble
# NB: expects input txt files to have identical headers, extension must be .csv, and to all be in the same dir
# user args: 1) input directory of text files, 2) output text file
# example use: $0 /tmp/ /tmp/out.csv

indir=$1
out=$2
# remove the output in case it exists - don't complain about err
rm $out 2>/dev/null
cd $indir
# find a file to get the header from - all header better be identical
header_origin=$( find $indir -type f -iregex ".*[.]csv$" | sed -n '1p')
# get the header
header=$( cat $header_origin | head -n 1 )
# print the header to its own file
echo "$header" > $out
# for every CSV that is not the output file, print the contents of the CSV without the header and append to the output
for csv in $( find $indir -type f -iregex ".*[.]csv$" | grep -vE "^${out}$" )
do 
	cat $csv | sed '1d'
done >> $out
