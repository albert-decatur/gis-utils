#!/bin/bash

# convert an arbitrary number of TIFs into two BSQ ASCII rasters for [DaVinci](http://davinci.asu.edu/) (or NumPy)
# the two rasters are data.asc (contains the DNs) and counter.asc (contains 1 for input null and 0 for input non-null by pixel)
# user args: 1) input directory with an arbitrary number of TIFs, 2) input EPSG SRS, 3) input nodata DN
# prereqes: 1) GDAL/OGR, 2) more-utils (for sponge)
# NB: after map algebra is done in NumPy or DaVinci you still need to add a valid ASCII raster header to the output

in_tifdir=$1
epsg=$2
nodata=$3

# making data.asc
# convert tif to asc with user supplied EPSG code and nodata value
cd $in_tifdir
for i in *.tif
do 
	gdal_translate -of AAIGrid -a_srs EPSG:$epsg -a_nodata $nodata -ot Float32 $i /tmp/asc/$( basename $i .tif ).asc
done
# make a single BSQ ascii, with bands separated by newline
# need to remove headers
cd tmp/asc/
ls *.asc | parallel 'asc=$( cat {} | sed "1,6d" ); echo -e "\n$asc"' | sed '1d' > data.asc

# making counter.asc
# make a single BSQ ascii, with bands separated by newline - for boolean nodata mask
cat data.asc | sed "s:\b0\b:1:g;s:\b${nodata}\b:|:g;s:[0-9]\+:1:g;s:|:0:g" > counter.asc
