#!/bin/bash

# prereq: GDAL/OGR
# user args: 1) inrast 2) inrast nodata 3) inshp 4) outrast

rast=$1
nodata=$2
shp=$3
outrast=$4

tmp=/tmp/$( basename $shp .shp ).tif

extent=$( 
	ogrinfo -so -al $shp |\
	grep Extent |\
	grep -oE "[0-9.-]+" |\
	sed '3d' |\
	tr '\n' ' ' |\
 	awk '{print $1,$4,$3,$2}' 
)

gdal_translate -projwin $extent -co COMPRESS=DEFLATE -co TILED=YES $rast $tmp
gdalwarp -co compress=deflate -co tiled=yes -r lanczos -cutline $shp -srcnodata $nodata -dstnodata $nodata $tmp $outrast
