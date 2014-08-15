#!/bin/bash

# script to transform a bounding box (BBOX) from one SRS to another
# works on raster or vector
# NB: just calls GDAL/OGR utils and postgis
# WKT polygons looks like this: POLYGON ((30 10, 40 40, 20 40, 10 20, 30 10))
# user args: 1) input OGR or GDAL layer 2) postgis enabled db, 3) input EPSG code, 4) output EPSG code
# TODO - same but for rasters

# example use: $0 foo.shp bar_db 4326 900913

inlayer=$1
db=$2
insrs=$3
outsrs=$4

function typetest {
	# test if inlayer is GDAL or OGR using exit status
	gdalinfo $inlayer &> /dev/null
	gdal_exit=$( echo $? )
	ogrinfo $inlayer &> /dev/null
	ogr_exit=$( echo $? )
	if [[ $gdal_exit -eq 0 ]]; then
		type=rast
	elif [[ $ogr_exit -eq 0 ]]; then 
		type=vect
	else
		echo -e "Input layer either could not be found or is neither GDAL nor OGR compatible.\nCheck your gdal-config --formats"
	fi
}

typetest


function get_bbox_asWKT {
case $type in
	rast)
	echo "it's rast"
	;;
	vect)
	xmin_ymax_xmax_ymin=$(                                                                                                                      
		ogrinfo -so -al $inlayer |\
		grep Extent |\
		grep -oE "[0-9.-]+" |\
		sed '3d' |\
		tr '\n' ' ' |\
		awk '{print $1,$4,$3,$2}'
	)
	BBOX_WKT=$( echo "$xmin_ymax_xmax_ymin" |\
	awk '{print $3,$4","$3,$2","$1,$2","$1,$4","$3,$4}'|\
	sed 's:^:POLYGON ((:g;s:$:)):g'|\
	sed "s:^:':g;s:$:':g"
	)
	;;
esac
}

get_bbox_asWKT

# get WKT of BBOX POLYGON transformed to new SRS
transformed_wkt=$( ( cat | psql $db ) <<EOF
	select 
	st_asText(
		st_transform(	
			st_geomfromtext(
				$BBOX_WKT,$3
			)
		,$4)
	)
	;
EOF
)

# get ULLR (ulx,uly,lrx,lry) or transformed BBOX POLYGON
# note that this is identical to xmin,ymax,xmax,ymin
transformed_ullr=$(
echo "$transformed_wkt" |\
sed -n '3p' |\
sed 's:^\s*POLYGON((::g;s:))$::g'|\
tr ',' '\n'|\
sed -n '1p;3p'|\
tac|\
tr '\n' ' '
)

# strip away the extra text from postgis output
transformed_wkt=$(echo "$transformed_wkt" |\
sed -n '3p'
)

echo -e "ulx,uly,lrx,lry:\n$transformed_ullr\n\n\nPOLYGON WKT:\n$transformed_wkt"
