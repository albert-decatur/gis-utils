#!/bin/bash
usage()
{
cat << EOF
usage: $0 [-d] -s inshp.sh -c field1 -g field2

For a shapefile, count the number of features in one field given unique values in a second field, 
OR, using the "-d" flag, count the number of DISTINCT values in one field given unique values in another field.

Particularly useful for checking ID and name fields before you attempt to make a new ID field due to IDs not being unique.
Complicating issues: 1) there may be many distinct polys that legitimately have the same name (eg "Western District" in many countries), 2) polys with the same name that are not contiguous should **maybe** be multipart so watch out with dissolves

OPTIONS:
   -h      Show this message
   -s      input shapefile
   -c      name of field in shapefile to count by
   -g      name of field in shapefile to group by
   -d      use this optional flag for SQL DISTINCT on the count field
EOF
}

while getopts "hds:c:g:" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         s)
             inshp=$OPTARG
             ;;
         c)
             count_field=$OPTARG
             ;;
         g)
             groupby_field=$OPTARG
             ;;
         d)
             distinct=1
             ;;
         ?)
             usage
             exit
             ;;
     esac
done
# use -d flag for SQL DISTINCT
if [[ -n $distinct ]]; then
	# super awkward
	usedistinct='DISTINCT('
	endparen=')'
fi
ogrinfo -geom=no -dialect SQLite -sql \
	"SELECT 
	COUNT(${usedistinct}$count_field${endparen}),
	$groupby_field 
	FROM \"$( basename $inshp .shp)\" 
	GROUP BY $groupby_field 
	HAVING COUNT(${usedistinct}$count_field${endparen}) > 1 
	ORDER BY COUNT(${usedistinct}$count_field${endparen}) DESC"\
 $inshp|\
grep -A2 OGRFeature|\
grep -v OGRFeature
