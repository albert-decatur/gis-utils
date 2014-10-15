#!/bin/bash

# export a polygon shp for each point shp in a dir given input poly grid to join to
# NB: this is a very special case, eg someone has made a poly grid that their point shp always join to, one-to-one
# NB: uses postgres db with postgis, expects exact tables names used by shp2pgsql (take basename, remove .shp, remove anything after first period)
# NB: uses syntax 'geom' rather than 'the_geom' b/c expects postgis 2.0
# this script built with UCAR's CCSM poly grids and point exports in mind
# example use: $0 ccsm_grid/ccsm_polygons.shp historical/precip/ 4326 climate_cities out/

poly_shp=$1
point_dir=$2
epsg=$3
db=$4
outdir=$5

function table_name { basename $1 .shp | grep -oE "^[^.]*" | awk "{print tolower(\$0)}" ;}
function table_exists { echo "COPY ( SELECT EXISTS( SELECT * FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '$1' ) ) TO STDOUT;" | psql $db;}
poly_table=$( table_name $poly_shp )
poly_exists=$( table_exists $poly_table )
if [[ $poly_exists == "t" ]]; then 
	false
else 
	# if the poly table is not in your postgres db then add it
	shp2pgsql -s EPSG:$epsg $poly_shp | psql $db
fi
# for each point shp, add it to the postgres db if it is not there already.  then join it to the poly table, export as del.shp to the outdir, and rename
for point_shp in $( find $point_dir -type f -iregex ".*shp$" )
do 
	point_table=$( table_name $point_shp )
	point_exists=$( table_exists $point_table )
	if [[ $point_exists == "t" ]]; then 
		false
	else 
		shp2pgsql -s EPSG:$epsg $point_shp | psql -q $db
	fi
	# get a list of all point table fields except for gid,geom
	point_fields=$( echo "COPY ( select * from \"$point_table\" limit 0 ) TO STDOUT DELIMITER E'\t' CSV HEADER;" | psql $db | tr '\t' '\n' | grep -vE "^(geom|gid)$" | sed 's:^:":g;s:$:":g;s:^:a.:g' | tr '\n' ',' | sed 's:,$::g' )
	# join all point table fields except for gid,geom to only geom from poly table
	echo "drop table if exists del; create table del as select $point_fields,ST_SetSRID(b.geom,$epsg) as geom from \"$point_table\" as a, \"$poly_table\" as b where st_within(a.geom,b.geom);" | psql $db
	# remove point table
	#echo "DROP TABLE \"$point_table\" | psql $db;"
	cd $outdir
	pgsql2shp $db del
	rename "s:del:$point_table:g" del.*
	cd - 1>/dev/null
done
