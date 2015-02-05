#!/bin/bash
#r.batchunivar

#%Module
#%  description: get univariate stats on a directory of tifs
#%End
#%Option
#% key: inrastdir
#% type: string
#% description: input directory of rasters to sum - recurses
#% required : yes
#%End
#%Option
#% key: findregex
#% type: string
#% description: regex used by UNIX find command - ".*[.]tif$" if not supplied
#% required : no
#%End

if [ -z "$GISBASE" ] ; then
    echo "You must be in GRASS GIS to run this program." 1>&2
    exit 1
fi

if [ "$1" != "@ARGS_PARSED@" ] ; then
  exec g.parser "$0" "$@"
fi

inrastdir=$(readlink -f $GIS_OPT_INRASTDIR)
findregex=$(echo $GIS_OPT_FINDREGEX)

## remove all existing rasters
#g.mremove -f rast=*

# define header
header=$( echo -e "non_null_cells\tnull_cells\tmin\tmax\trange\tmean\tmean_of_abs\tstddev\tvariance\tcoeff_var\tsum\tsum_abs" )
# define find's regex if not user supplied
if [[ -z $findregex ]]; then
	findregex=".*[.]tif$"
fi
# print header once
echo "$header"
find $inrastdir -type f -iregex "$findregex" |\
# only run once process at a time - otherwise g.region gets messed up
parallel -P 1 --gnu '
	map=$(basename {} .tif)
	r.in.gdal --q input={} output=$map --overwrite 2>/dev/null
	# set region to raster map
	g.region rast=$map
	# get stats of raster map
	r.univar map=$map -t fs=tab |\
	# remove header
	sed "1d" |\
	# add file basename
	sed "s:^:${map}\t:g"
'
