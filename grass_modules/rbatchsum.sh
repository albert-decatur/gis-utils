#!/bin/bash
# r.sum
# sum a directory of tifs

# NB: 
# for now, region rast must be tif
# mapset should not contain any rasters because all will be used to sum
# all null values will be set to zero.  need to change this for rasters for which this is not appropriate

# TODO
# expand to other types of map algebra
# better null handling
# make export tif a user arg

#%Module
#%  description: sum a directory of tifs
#%End
#%Option
#% key: inrastdir
#% type: string
#% description: input directory of rasters to sum - recurses
#% required : yes
#%End
#%Option
#% key: regionrast
#% type: string
#% description: tif found in the input directory used to set region
#% required : yes
#%End
#%Option
#% key: batchsize
#% type: string
#% description: count of rasters to sum at once
#% required : yes
#%End

if [ -z "$GISBASE" ] ; then
    echo "You must be in GRASS GIS to run this program." 1>&2
    exit 1
fi

if [ "$1" != "@ARGS_PARSED@" ] ; then
  exec g.parser "$0" "$@"
fi

absrast=$(readlink -f $GIS_OPT_INRASTDIR)
regionrast=$(readlink -f $GIS_OPT_REGIONRAST)
batchsize=$(readlink -f $GIS_OPT_BATCHSIZE)

function importrast {
	# ingest dir of rasters
	for rast in $(find $absrast -type f -iregex ".*[.]tif$")
	do
		r.in.gdal input=$rast output=$(basename $rast .tif)
	done
}

function setregion_global {
	# import regionrast
	r.in.gdal input=$regionrast output=$( basename $regionrast .tif )
	# NB: need to use basename b/c grass tries to expand to full "path"
	g.region rast=$( basename $regionrast .tif)
}

function rm_mask {
	# remove any mask that might be present
	r.mask -r
}

function setnull_zero {
	# set all null values to zero
	g.list type=rast |\
	sed '1,2d;$d'|\
	tr ' ' '\n'|\
	grep -vE "^$"|\
	parallel --gnu '
		r.null map={} null=0
	'
}	

function sum {
	n=$( basename $batchsize )
	# rm rasts produced by summing iterations
	g.mremove -f rast=r[0-9]*
	rasts=$( g.list type=rast | sed '1,2d;$d'|tr ' ' '\n'|grep -vE "^$" | grep -vE "^$( basename "$regionrast" .tif )$")
	cols=$( seq 1 $n | sed 's:^:$:g'|tr '\n' ','| sed 's:,$::g' )
	function nextn {  echo $rasts | awk "{OFS=\"\n\";print $cols}" ;}
	function chop { echo "$rasts" | sed "1,${n}d";}
	count_iterations=$( echo "$( echo "$rasts" | wc -l )/$n + 1" | bc )
	seq 1 $count_iterations |\
	while read i
	do 
		if [[ $i -ne 1 ]]; then 
			nextrasts=$( nextn | grep -vE "^$" | tr '\n' ' ' | sed "s:$:\nr$( expr ${i} - 1 ):g" | tr ' ' '\n' | tr '\n' '+' | sed 's:\+$::g' | sed 's:+\+:+:g' )
			# version using C=A + if(isnull(B),0,B). if DN would be null make it 0
			nextrasts=$( echo $nextrasts | tr '+' '\n' | while read rast; do echo $rast | sed "s:^:if(isnull(:g;s:$:),0,$rast):g"; done | tr '\n' '+' | sed 's:+$::g' )
			
		else 
			nextrasts=$( nextn | grep -vE "^$" |tr '\n' '+' | sed 's:\+$::g')
			# version using C=A + if(isnull(B),0,B). if DN would be null make it 0
			nextrasts=$( echo $nextrasts | tr '+' '\n' | while read rast; do echo $rast | sed "s:^:if(isnull(:g;s:$:),0,$rast):g"; done | tr '\n' '+' | sed 's:+$::g' )
		fi
		r.mapcalc r${i}=$nextrasts
# tmp - dont rm intermediate rasts
#		if [[ $i != 1 ]]; then 
#			g.remove -f rast=r$( expr $i - 1 )
#		fi
		rasts=$(chop)
	done
}

importrast
setregion_global
rm_mask
#setnull_zero
sum

exit 0
