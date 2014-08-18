#!/bin/bash

# script to report GDAL/OGR layer BBOX coordinates in any SRS by EPSG code
# NB: just calls GDAL/OGR utils and postgis.  must use full path for input layer
# TODO - report BBOX in current SRS. can do this now by repeating the same EPSG code! messy
# user args: 1) input OGR or GDAL layer 2) postgis enabled db, 3) input EPSG code, 4) output EPSG code

# example use: $0 /full/path/to/foo.shp bar_db 4326 900913

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

function get_ullr {
case $type in
	rast)
	xmin_ymax_xmax_ymin=$(
		gdalinfo $inlayer |\
		grep -E "Upper Left|Lower Right" |\
		awk '{ print $4,$5}' |\
		grep -oE "[0-9.-]+" |\
		awk '{ print $1,$4,$3,$2 }' |\
		tr '\n' ' '
	)
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
	;;
esac
}

function get_bbox_asWKT {
	BBOX_WKT=$( 
		echo "$xmin_ymax_xmax_ymin" |\
		awk '{print $3,$4","$3,$2","$1,$2","$1,$4","$3,$4}'|\
		sed 's:^:POLYGON ((:g;s:$:)):g'|\
		sed "s:^:':g;s:$:':g"
	)
}

typetest
get_ullr
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

# print both ullr and BBOX WKT
echo -e "ulx,uly,lrx,lry:\n$transformed_ullr\n\n\nPOLYGON WKT:\n$transformed_wkt"
