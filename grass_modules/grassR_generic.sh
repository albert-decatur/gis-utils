#!/bin/bash
# generic start of an R spgrass6 script
# works on all tifs in working dir

for tif in $(find . -regex "[.]/.*[.]tif$")
do
        dir=$(dirname $tif)
        layer=$(basename $tif .tif)

echo | R --vanilla <<EOF
        setwd('$dir')
        library(spgrass6)
        initGRASS(gisBase='/usr/lib/grass64', home=tempdir(),override = TRUE)
        execGRASS('r.in.gdal',flags=c('o','e'),input='$tif',output='${layer}')
        execGRASS('g.region',flags=c('a'),rast='${layer}')

EOF
done
