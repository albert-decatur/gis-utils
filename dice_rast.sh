#!/bin/bash
# by Tim Sutton - pretty much
# http://linfiniti.com/2009/09/image-mosaicking-with-gdal/

# user args: 1) input raster, 2) directory to hold dice rasters, 3) size of output blocks
# NB: makes tifs

inrast=$1
outdir=$2

dims=$( 
	gdalinfo $inrast |\
	grep -E "^Size" |\
	grep -oE "[0-9]+" 
)

XDIM=$( echo "$dims" | sed -n "1p" )
YDIM=$( echo "$dims" | sed -n "2p" )

BLOCKSIZE=$3
XPOS=0
YPOS=0
BLOCKNO=0
while [ $YPOS -le $YDIM ]
do
  while [ $XPOS -le $XDIM ]
  do
    echo "$XPOS $YPOS : ${BLOCKNO}.tif"
   # Notice I am using my hand built gdal now!
    gdal_translate -srcwin $XPOS $YPOS \
      $BLOCKSIZE $BLOCKSIZE $inrast $outdir/${BLOCKNO}.tif
    BLOCKNO=`echo "$BLOCKNO + 1" | bc`
    XPOS=`echo "$XPOS + $BLOCKSIZE" | bc`
  done
  YPOS=`echo "$YPOS + $BLOCKSIZE" | bc`
  XPOS=0
done
