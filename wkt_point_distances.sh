#!/bin/bash

# list the distances in meters between all input WKT points
# input must be WKT, one point per line
# user must also specify an EPSG code for SRID and a PostgreSQL db to run on, with PostGIS enabled
# tested with PostGIS 2.1, using GEOS
# example use: $0 points.txt 4326 scratch
# example use: $0 <( echo -e "POINT(48.5730475299341 34.6062500297351)\nPOINT(48.57291 34.61062)\nPOINT(48.532988782315 34.6138231599741)" ) 4326 scratch

# TODO:
# allow option to use any OGR compatible vector
# this could be accomplished with something like 'ogrinfo -al $invect | grep -E "^POINT"'

inwkt=$1
srid=$2
db=$3

# function to list pairs of elements exactly once
# example use: listpairs "yo dog sup" "|"
# should create outputs "yo|dog", "yo|sup", and "dog|sup" but not superfluous output pairs like "sup|yo"
function listpairs { 
	d=$2

	set -- $1
	for a
	do 
		shift
		for b
		do 
			printf "%s$d%s\n" "$a" "$b"
		done
	done
}
# note that we only export this function because piping to bash worked but running it normally did not
export -f listpairs

function postgis_wkt2geom {
	fieldnum=$1
	table=$2
	# get just one point from the pair - user selects which with fieldnum
	awk -F, "{ print \$${fieldnum} }" |\
	# write SQL for PostGIS
	sed "s:^:SELECT ST_GeomFromText(':g;s:$:',${srid}) AS geom:g" |\
	sed "s:^:( :g;s:$:) AS ${table}:g"
}

# print a header to explain our outputs
echo -e "distance_meters\tfirst_point\tsecond_point"

# prep a single line based on the listpairs input expectations - a whitespace separated list
# note that we temporarily replace the spaces in each line of WKT with pipes
# these get switched back later
wkt_for_listpairs=$(
	cat $inwkt |\
	sed 's:\s\+:|:g' |\
	tr '\n' ' ' |\
	sed 's:^\|$:":g'
)
# list all non-redundant combinations of WKT point pairs
# use comma as delimiter
echo "listpairs "$wkt_for_listpairs" \",\"" |\
bash |\
sed 's:|: :g' |\
# now write the SQL for PostGIS to find the distance between this pair of points
while read pair
do
	# NB: table names a and b are hard coded into a later step
	# this is sloppy because we made a function that lets us choose any table name
	# however, it is unlikely to be a problem if we only ever examine *pairs* of points
	a=$( echo "$pair" | postgis_wkt2geom 1 a )
	b=$( echo "$pair" | postgis_wkt2geom 2 b )
	# print out both the geom for point a and the geom for point b - these are what we will select from
	echo "$a","$b" |\
	# print the SQL to select the distance between points a and b
	sed "s:^:SELECT ST_Distance(a.geom\:\:geography,b.geom\:\:geography) AS distance_m FROM :g" |\
	# do not print the header
	# NB: this makes defining the column name as anything other than the default unnecessary
	sed "s:^:COPY (:g;s:$: ) TO STDOUT:g" |\
	# add the finishing semicolon to our SQL
	sed "s:$:;:g" |\
	psql $db |\
	# now append the WKT of the inputs in TSV format
	# NB: replacing $pair comma with tab could be evaluated earlier but would be more confusing
	# NB: Bash order of operations is saving the day here, otherwise sed would be confused
	sed "s:$:\t$( echo "$pair" | sed "s:,:\t:g"):g"
done
# for each pair of points, find the distance
# note that geography is used just in case distances across the earth are very large
# geography will also output meters in case input is lon/lat
