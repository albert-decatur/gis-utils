#!/bin/bash

# v.export_attr

#%Module
#%  description: export all vector columns that match a pattern as rasters with a given spatial resolution
#%End
#%Option
#% key: outrastprefix
#% type: string
#% description: output prefix for rasters
#% required : yes
#%End
#%Option
#% key: outrastdir
#% type: string
#% description: output directory for rasters
#% required : yes
#%End
#%Option
#% key: map
#% type: string
#% description: vector map to export attributes from
#% required : yes
#%End
#%Option
#% key: column_regex
#% type: string
#% description: pattern for columns with attributes to match, in double quotes
#% required : yes
#%End
#%Option
#% key: xres
#% type: string
#% description: x resolution for raster export
#% required : yes
#%End
#%Option
#% required : yes
#% key: yres
#% type: string
#% description: y resolution for raster export
#% required : yes
#%End

if [ -z "$GISBASE" ] ; then
    echo "You must be in GRASS GIS to run this program." 1>&2
    exit 1
fi

if [ "$1" != "@ARGS_PARSED@" ] ; then
  exec g.parser "$0" "$@"
fi

# remove files if the match user parameters for outputs
#rm ${GIS_OPT_OUTRASTDIR}/${GIS_OPT_OUTRASTPREFIX}* 2>/dev/null

listcols=$(v.info -c map=$GIS_OPT_MAP | grep -E $GIS_OPT_COLUMN_REGEX | awk -F"|" '{print $2}')

# calculate number of rows and columns for rasters
extent=$(g.region -p | grep -E "north|south|west|east" | grep -oE "[0-9.]+")
xpixels=$(echo $extent | awk "{ print (\$1-\$2)/$GIS_OPT_XRES}")
ypixels=$(echo $extent | awk "{ print (\$4-\$3)/$GIS_OPT_YRES}")
g.region vect=$GIS_OPT_MAP rows=$xpixels cols=$ypixels

for i in $listcols
do
        v.to.rast input=$GIS_OPT_MAP output=${GIS_OPT_OUTRASTPREFIX}_${i} type=area column=$i --overwrite
        r.out.gdal input=${GIS_OPT_OUTRASTPREFIX}_${i} output=${GIS_OPT_OUTRASTDIR}/${GIS_OPT_OUTRASTPREFIX}_${i}.tif
done
