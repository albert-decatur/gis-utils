#!/bin/bash
# make a TSV from NetCDF variables
# tested with classic NetCDF
# prereq: netcdf-bin
# user args: 1) input NetCDF file, 2) comma separated list of NetCDF variables, 3) output TSV to hold those variables
# example use: $0 Urb10.nc lon_fx,lat_fx,p2050 del.tsv

in_nc=$1
varstring=$2
outtxt=$3

# make a directory to hold temporary files - delete it if it exists already
rm -r /tmp/$in_nc 2>/dev/null
mkdir /tmp/$in_nc

# gt ncdump to print out the input nc file
dumptxt=$(ncdump -v $varstring $in_nc)
# get the data section on the ncdump
# it's everything after "data:", except for semi-colons and the end curly brace at the very end
data=$(
	echo "$dumptxt"|\
	sed '1,/data:/d' |\
	sed 's:}::g;s:;::g' |\
	grep -vE "^$"
)

# define a temporary file
tmp=$(mktemp)
# dump data section from ncdump into tmp file
echo "$data" > $tmp
# for every variable, print a file
# NB: the first file is blank
csplit -f /tmp/$in_nc/$in_nc $tmp '/=/' {*} 1>/dev/null

# for every nc variable, 
for var in $(find /tmp/$in_nc -type f)
do 
	# the first split file is blank - do nothing
	if [[ "$(cat $var | wc -l )" = "0" ]]; then 
		false
	else
		# get the variable header - it's text on the first line before an equals sign
		var_header=$( cat $var | grep -oE "^.*=" | sed 's:=::g' | sed 's:^[ \t]\+::g;s:[ \t]\+$::g' )
		# get the variable data - it's comma separated text after the equals sign on the first line
		var_data=$( cat $var | sed 's:^.*[=]::g'|tr ',' '\n'|sed 's:^[ \t]\+::g;s:[ \t]\+$::g'|grep -vE "^$" )
		# print the variable data with header to a file named after the header
		echo -e "$var_header\n$var_data" > /tmp/"$var_header"
	fi
done

# make a single TSV from every variable, in the order user provided
eval paste $(echo "/tmp/{$varstring}") > $outtxt
