#!/bin/bash

# assumes 
#1) field of interest with same name in both files
#2) need to change field from string to int - this is not polished
#3) shp input
#4) deletes everything in mapset - dangerous

#%Module
#%  description: Print intersection of two shapefiles, with areas.
#%End
#%Option
#% key: a
#% type: string
#% description: first input vector
#% required : yes
#%End
#%Option
#% key: b
#% type: string
#% description: second input vector
#% required : yes
#%End
#%Option
#% key: xres
#% type: string
#% description: Width of pixel to rasterize to
#% required : yes
#%End
#%Option
#% key: yres
#% type: string
#% description: Height of pixel to rasterize to
#% required : yes
#%End
#%Option
#% key: field
#% type: string
#% description: field, found in both maps a and b, to perform intersect on
#% required : yes
#%End
#%Option
#% key: output
#% type: string
#% description: file to output intersection report to
#% required : yes
#%End

if [ -z "$GISBASE" ] ; then
    echo "You must be in GRASS GIS to run this program." 1>&2
    exit 1
fi

if [ "$1" != "@ARGS_PARSED@" ] ; then
  exec g.parser "$0" "$@"
fi

#while [ -n "g.mlist mapset=$(g.gisenv get=MAPSET) type=vect type=rast" ] ; do
#        g.mremove -f rast="*" vect="*"
#done

absA=$(readlink -f $GIS_OPT_A)
absB=$(readlink -f $GIS_OPT_B)
dsnA=$(dirname $absA)
dsnB=$(dirname $absB)
baseA=$(basename $absA .shp)
baseB=$(basename $absB .shp)

# import shp to GRASS
v.in.ogr dsn=$dsnA layer=$baseA output=$baseA --overwrite
v.in.ogr dsn=$dsnB layer=$baseB output=$baseB --overwrite

# handle columns - note that this is holmes specific right now
v.db.addcol map=$baseA columns="a INT"
v.db.update map=$baseA column=a qcolumn="$GIS_OPT_FIELD"
v.db.dropcol map=$baseA column=$GIS_OPT_FIELD

v.db.addcol map=$baseB columns="b INT"
v.db.update map=$baseB column=b qcolumn="$GIS_OPT_FIELD"
v.db.dropcol map=$baseB column=$GIS_OPT_FIELD

# calculate number of rows and columns for rasters
extent=$(g.region -p | grep -E "north|south|west|east" | grep -oE "[0-9.]+")
xpixels=$(echo $extent | awk "{ print (\$1-\$2)/$GIS_OPT_XRES}")
ypixels=$(echo $extent | awk "{ print (\$4-\$3)/$GIS_OPT_YRES")
g.region vect=$GIS_OPT_ENUMERATOR rows=$xpixels cols=$ypixels

# convert to raster
v.to.rast input=$baseA output=$baseA use=attr type=area column=a --overwrite
v.to.rast input=$baseB output=$baseB use=attr type=area column=b --overwrite

# intersect rasters, get surface areas of intersections
r.stats -a input=$baseB,$baseA | grep -vE "\*" > $GIS_OPT_OUTPUT

exit 0
