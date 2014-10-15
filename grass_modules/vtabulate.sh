#!/bin/bash
# v.tabulate

#TODO
# vector input  and output must be shapefile
# don't delete everything in mapset, or files that match output names

#NB
# summaries are based on parts of vector as they intersect the raster

#%Module
#%  description: Summarize the relative proportions of non-null categories from a raster, given a vector.
#%End
#%Option
#% key: inrast
#% type: string
#% description: input raster to summarize by vector
#% required : yes
#%End
#%Option
#% key: invect
#% type: string
#% description: input vector used to summarize raster
#% required : yes
#%End
#%Option
#% key: outvect
#% type: string
#% description: name of output vector
#% required : yes
#%End
#%Option
#% key: null
#% type: string
#% description: space separated list of null values in double quotes - can be a single value
#% required : no
#%End

if [ -z "$GISBASE" ] ; then
    echo "You must be in GRASS GIS to run this program." 1>&2
    exit 1
fi

if [ "$1" != "@ARGS_PARSED@" ] ; then
  exec g.parser "$0" "$@"
fi

absrast=$(readlink -f $GIS_OPT_INRAST)
absvect=$(readlink -f $GIS_OPT_INVECT)
vectdir=$(dirname $absvect)
vectbase=$(basename $absvect .shp)
outvect=$(readlink -f $GIS_OPT_OUTVECT)

spat=$(gdalinfo $absrast | grep -E "Upper Left|Lower Right" | awk '{ print $4,$5}' | grep -oE "[0-9.]+" | awk '{ print $1,$4,$3,$2 }' | tr '\n' ' ')
rm /tmp/fishnet* 2>/dev/null
ogr2ogr /tmp/fishnet.shp $absvect -spat $spat
rm $(dirname $outvect)/$(basename ${outvect} .shp)* 2>/dev/null
rm /tmp/update.sql 2>/dev/null

g.mremove -f rast=* vect=*

r.in.gdal input=$absrast output=rast --overwrite
v.in.ogr dsn=/tmp layer=fishnet output=fishnet --overwrite
rastcats=$(r.category map=rast)
nullstring=$(echo $GIS_OPT_NULL | sed 's:\([0-9]*\):\\b\1\\b:g;s: :\\|:g')
maskcats=$(echo $rastcats | sed "s:$nullstring::g")
r.mask -o input=rast maskcats="$maskcats"
g.region rast=rast
v.to.rast input=fishnet output=fishnet type=area column=cat --overwrite
r.stats -a input=rast,fishnet | grep -vE "\*" > /tmp/cross
# is this step necessary?  why create fishnet when you can update existing fishnet?
#r.to.vect input=fishnet output=fishnet feature=area --overwrite
newcols=$(echo $maskcats | sed 's:\([0-9]*\):ratio\1 double precision,:g;s:,$::g')
v.db.addcol map=fishnet columns="$newcols"

awk '{ print $2}' /tmp/cross | sort -u > /tmp/cells
while read line
do
        sum=$(awk "{ if ( \$2 ~ /^$line$/ ) {sum+=\$3}} END {print sum}" /tmp/cross)
        report=$(awk "{OFS=\",\"; if ( \$2 ~ /^$line$/ ) print \$1,\$3 / $sum}" /tmp/cross)
        for i in $(echo $report | sed 's: :\n:g')
        do
                cat=$(echo $i | awk -F, '{print $1}')
                ratio=$(echo $i | awk -F, '{print $2}')
                echo "UPDATE fishnet SET ratio${cat}=$ratio WHERE cat=$line;" >> /tmp/update.sql
        done
done < /tmp/cells

cat /tmp/update.sql | db.execute

v.out.ogr input=fishnet type=area dsn=$outvect

exit 0