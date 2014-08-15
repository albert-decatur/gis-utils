#!/bin/bash

# script to transform a single pair of coordintes from one SRS to another
# good for finding a likely SRS of a layer with undefined projection
# NB: just calls postgis
# user args: 1) double quoted string with two values: "x y", eg "42.1 18.3", 2) postgis enabled db, 3) input EPSG code, 4) output EPSG code
# WKT for points takes the form 'POINT(X Y)'

# example use: $0 "42.1 18.3" foo_db 4326 900913

coords=$1
db=$2
insrs=$3
outsrs=$4

transformed=$( ( cat | psql $db ) <<EOF
	select 
	st_asText(
		st_transform(	
			st_geomfromtext(
				'POINT($coords)',$3
			)
		,$4)
	)
	;
EOF
)

echo "$transformed" |\
sed -n '3p' |\
grep -oE "[0-9.-]+" |\
tr '\n' ' '
