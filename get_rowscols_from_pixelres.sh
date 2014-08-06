#!/bin/bash

# for given OGR file, provide desired raster xres and yres in map units and get back the number of appropriate rows and columns
# TODO: make less ugly.  this was written years ago
# NB: you probably want the same output xres and yres.  input units are map units 
# user args: 1) input OGR file, 2) desired output xres, 3) desired output yres

xres=$2
yres=$3
ullr=`ogrinfo -ro -al -so $1 | grep -E "Extent" | grep -Eo "[0-9.-]+" | sed '3d' | sed 's/[ \t]//g' | tr '\n' ',' | sed 's/,/ /g' | awk '{ print $1,$4,$3,$2 }'`
maxx=`echo $ullr | awk '{print $3}'`
minx=`echo $ullr | awk '{print $1}'`
maxy=`echo $ullr | awk '{print $2}'`
miny=`echo $ullr | awk '{print $4}'`
xrange=`echo $maxx - $minx | bc`
xpixels=`echo $xrange / $xres | bc`
yrange=`echo $maxy - $miny | bc`
ypixels=`echo $yrange / $yres | bc`
echo -e "$xpixels\t$ypixels"
