#!/bin/bash

# script to find the distance between points in decimal degrees
# just called postgis - uses type geography, reports in meters
# user args: 1) double quoted string with four values: first lon, first lat, second lon, second lat 2) postgis enabled db
# WKT for points takes the form 'POINT(X Y)'

# example use: $0 "30 10 30 11" foo_db

coords=$1
db=$2

first=$( echo "$coords" | awk '{print $1,$2}' )
second=$( echo "$coords" | awk '{print $3,$4}' )
cat | psql $db <<EOF
	select 
	st_distance(
		st_geomfromtext(
			'POINT($first)',4326
	)::geography,
	st_geomfromtext(
			'POINT($second)',4326
	)::geography)
	;
EOF
