#!/bin/bash

# merge a directory of shapefiles
# user args: 1) directory of shp to merge, 2) name of new merge shp

# NB: output merge shp will be overwrittern!

shpdir=$1
mergeshp=$2
rm $( basename $mergeshp .shp ).{shp,dbf,shx,prj}
cd $shpdir

allshp=$(
find $shpdir -type f -iregex ".*[.]shp$"
)

firstshp=$(
echo "$allshp" |\
sed -n '1p'
)

restshp=$(
echo "$allshp" |\
sed '1d'
)

ogr2ogr $mergeshp "$firstshp"
for shp in $restshp
do
	ogr2ogr -update -append $mergeshp $shp  -f "ESRI Shapefile" -nln $( basename $mergeshp .shp)
done
