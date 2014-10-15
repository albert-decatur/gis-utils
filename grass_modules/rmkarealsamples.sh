#!/bin/bash

        ############################################################################
        #
        # MODULE:       r.mksamples for GRASS 6
        # AUTHOR(S):    Albert Decatur (albert.decatur@gmail.com), Clark University, Worcester MA
        # PURPOSE:      Makes samples for accuracy assesment using different methods.
        # COPYRIGHT:    (C) 2011 Albert Decatur
        #
        #               This program is free software under the GNU General Public
        #               License (>=v2). Read the file COPYING that comes with GRASS
        #               for details.
        #
        # TODO
        # sort samples randomly for stratified and areal
        # don't delete all contents of mapset
        # add blank landcover field to enumerator copy
        # requires dice_raster.sh - include all this code inside instead
        #############################################################################

# NB:
# input raster must not be type float
# assumes shapefile output
# execution time will be very slow if dicedim is too small - try to get the largest dicedim before failure

#%Module
#%  description: Makes polygons for accuracy assessment.
#%End
#%Option
#% key: input
#% type: string
#% description: input raster
#% required : yes
#%End
#%Option
#% key: output_master
#% type: string
#% description: copy of output vector samples to be used as master
#% required : yes
#%End
#%Option
#% key: output_enumerator
#% type: string
#% description: copy of output vector samples to be used by enumerator
#% required : yes
#%End
#%Option
#% key: samples
#% type: integer
#% description: number of samples
#% required : yes
#%End
#%Option
#% key: radius
#% type: double
#% description: radius to grow by
#% required : yes
#%End
#%Option
#% key: mmu
#% type: double
#% description: minimum mapping unit, in square meters
#% required : yes
#%End
#%Option
#% key: null
#% type: integer
#% description: null value for raster
#% multiple: yes
#% required : no
#%End
#%Option
#% key: dicedim
#% type: integer
#% description: dimensions for dicing step for large rasters
#% required : no
#%End
#%flag
#% key: c
#% description: categories are the same as the range - faster for large rasters
#%End

if [ -z "$GISBASE" ] ; then
    echo "You must be in GRASS GIS to run this program." 1>&2
    exit 1
fi

if [ "$1" != "@ARGS_PARSED@" ] ; then
  exec g.parser "$0" "$@"
fi

while [ -n "`g.mlist type=rast type=vect`" ] ; do
        g.mremove -f rast="*" vect="*"
done

dirmaster=$(dirname $GIS_OPT_OUTPUT_MASTER)
direnumerator=$(dirname $GIS_OPT_OUTPUT_ENUMERATOR)
rm $dirmaster/$(basename $GIS_OPT_OUTPUT_MASTER .shp)* 2>/dev/null
rm $direnumerator/$(basename $GIS_OPT_OUTPUT_ENUMERATOR .shp)* 2>/dev/null
rm -r /tmp/dicedir 2>/dev/null

rast=rast

r.in.gdal -o -e input=$GIS_OPT_INPUT output=$rast --overwrite
g.region -a rast=$rast
nullstring=$(echo $GIS_OPT_NULL | tr ' ' '|')

if [[ -z "$GIS_OPT_NULL" && $GIS_FLAG_C -eq 0 ]]; then
        cats=$(r.category map=$rast)
elif [[ -n "$GIS_OPT_NULL" && $GIS_FLAG_C -eq 0 ]]; then
        cats=$(r.category map=$rast | grep -vE "$nullstring")
elif [[ -z "$GIS_OPT_NULL" &&  $GIS_FLAG_C -eq 1 ]]; then
        cats=$(seq $(r.info -r map=$rast | grep -oE "[0-9]+" | tr '\n' ' '))
elif [[ -n "$GIS_OPT_NULL" && $GIS_FLAG_C -eq 1 ]]; then
        cats=$(seq $(r.info -r map=$rast | grep -oE "[0-9]+" | tr '\n' ' ') | grep -vE "$nullstring")
fi

catscount=$(echo $cats | wc -w)

areal()
{

rm /tmp/update.sql 2>/dev/null

for i in $cats
do
        rm /tmp/grass1.rcl /tmp/grass2.rcl 2>/dev/null
        touch /tmp/grass1.rcl
        echo $i = $i >> /tmp/grass1.rcl; echo "*" = NULL >> /tmp/grass1.rcl
        r.reclass input=$rast output=r_stratum_$i rules=/tmp/grass1.rcl --overwrite
        if [ -n "$GIS_OPT_DICEDIM" ]; then
                dice_raster.sh -i $(echo $(g.gisenv get="GISDBASE")/$(g.gisenv get="LOCATION_NAME")/$(g.gisenv get="MAPSET"))/cellhd/r_stratum_$i -d $GIS_OPT_DICEDIM -o /tmp/dicedir

                for d in /tmp/dicedir/*.tif
                do
                        r.in.gdal -o input=$d output=$(basename $d .tif) --overwrite
                        r.buffer input=$(basename $d .tif) output=rbuffer_stratum_${i}_$(basename $d .tif) distances=$GIS_OPT_RADIUS --overwrite
                        rm $d
                done

                dicelist=$(g.mlist type=$rast sep=, pat=rbuffer_stratum_$i_*)
                g.region rast=$dicelist
                r.patch in=$dicelist out=rbuffer_stratum_$i
                for t in /tmp/dicedir/*.tif
                do
                        g.remove -f rast=$(basename $t .tif)
                        g.remove -f rast=rbuffer_stratum_$i_*
                done
        else
                r.buffer input=r_stratum_$i output=rbuffer_stratum_$i distances=$GIS_OPT_RADIUS --overwrite
        fi
        touch /tmp/grass2.rcl
        echo $(echo 1 2 = 1; echo "\*" = "\*") > /tmp/grass2.rcl
        r.reclass input=rbuffer_stratum_$i output=rreclass_stratum_$i rules=/tmp/grass2.rcl --overwrite
        r.random input=rreclass_stratum_$i raster_output=rrandom_$i n=$GIS_OPT_SAMPLES --overwrite
        r.buffer input=rrandom_$i output=rbuffer_random_$i distance=$GIS_OPT_RADIUS --overwrite
        r.reclass input=rbuffer_random_$i output=rreclass_buffer_random_$i rules=/tmp/grass2.rcl --overwrite
        r.mask -o input=$rast maskcats=$i
        r.to.vect input=rreclass_buffer_random_$i output=vsample_$i feature=area --overwrite
        v.db.dropcol map=vsample_$i column=label
        v.db.dropcol map=vsample_$i column=value
        abovemmu=$(v.report map=vsample_$i option=area units=me | awk "{ FS=\"|\"; if (\$2 > "$GIS_OPT_MMU" ) print \$1 }")
        abovemmucount=$(echo $abovemmu | wc -w)
        abovemmulist=$(echo $abovemmu | sed 's/ /,/g')
        v.extract input=vsample_$i output=areal_$i type=area list="$abovemmulist" --overwrite
        v.db.addcol map=areal_$i columns="master varchar(15)"
        v.db.update map=areal_$i column=master value=$i
        r.mask -r
        rm /tmp/grass1.rcl /tmp/grass2.rcl
done

if [ $catscount == 1 ]; then
        v.out.ogr input=areal_$i type=area dsn=$GIS_OPT_OUTPUT_MASTER
        v.db.dropcol map=areal_$i column=master
        v.db.addcol map=areal_$i columns="enumerator varchar(15)"
        n=1
        v.db.select map=areal_$i | sed '1d;s:|::g' > /tmp/values
        sort -R /tmp/values | while read line
        do
                echo $line $(sed -n "${n}p" /tmp/values)
                n=$(($n+1))
        done | while read line
        do
                orig=$(echo $line | awk '{ print $1 }')
                new=$(echo $line | awk '{ print $2 }')
                echo "UPDATE areal_$i SET cat=$new WHERE cat=$orig;" >> /tmp/update.sql
        done
        cat /tmp/update.sql | db.execute
        v.out.ogr input=areal_$i type=area dsn=$GIS_OPT_OUTPUT_ENUMERATOR
else
        areallist=$(g.mlist type=vect pattern=areal_* | tr '\n' ',' | sed 's/,$//g')
        v.patch input=$areallist output=areal_samples -e --o
        v.out.ogr -c input=areal_samples dsn=$GIS_OPT_OUTPUT_MASTER type=area
        v.to.rast input=areal_samples type=area output=areal_samples use=val value=1
        r.to.vect input=areal_samples output=areal_enumerator feature=area
        v.db.dropcol map=areal_enumerator column=label
        v.db.dropcol map=areal_enumerator column=value
        v.db.addcol map=areal_enumerator columns="enumerator varchar(15)"
        n=1
        v.db.select map=areal_enumerator | sed '1d;s:|::g' > /tmp/values
        sort -R /tmp/values | while read line
        do
                echo $line $(sed -n "${n}p" /tmp/values)
                n=$(($n+1))
        done | while read line
        do
                orig=$(echo $line | awk '{ print $1 }')
                new=$(echo $line | awk '{ print $2 }')
                echo "UPDATE areal_enumerator SET cat=$new WHERE cat=$orig;" >> /tmp/update.sql
        done
        cat /tmp/update.sql | db.execute
        v.out.ogr -c input=areal_enumerator dsn=$GIS_OPT_OUTPUT_ENUMERATOR type=area
fi
}

areal

exit 0