#!/bin/bash

# rgeomod
# land-change prediction

#TODO 
# user must specify whether spatially constrained - send this to a gis

#NB: 
#1) very important! "outdir" permanently removes directory with this name
#2) the extent and number of rows and columns must be identical between all input maps
#3) the input to the minNull option must be in percent*100 - this makes the numbers integers
#4) 999999 is assumed to not be a value in suitability and development maps
#5) deletes maps in GRASS location

#%Module
#%  description: Make land change predictions similar to IDRISI's GeoMod.  Predicts locations of gains in one category over one time step given user inputs.  Makes use of suitability maps, allows for growth to be adjacent to existing development.  Note that text files under output directory relate to decisions made by the model.
#%End
#%Option
#% key: indir
#% type: string
#% description: input directory to find ascii grid files
#% required : yes
#%End
#%Option
#% key: outdir
#% type: string
#% description: output directory to place land change predictions, user determined boolean maps, and files with counts of cells relating to the land change prediction. NB: erases current directory!
#% required : yes
#%End
#%Option
#% key: output
#% type: string
#% description: output TIFF file with new residential areas
#% required : yes
#%End
#%Option
#% key: suitabilityMap
#% type: string
#% description: suitability map used for crosstabulation, for instance old landuse or distance to roads
#% required : yes
#%End
#%Option
#% key: residentialMap
#% type: string
#% description: map of count of residential households
#% required : yes
#%End
#%Option
#% key: nullMap
#% type: string
#% description: map of percent of cells that are ineligible or "null"
#% required : yes
#%End
#%Option
#% key: strataMap
#% type: string
#% description: map of strata used - for instance, towns
#% required : yes
#%End
#%Option
#% key: gainCSV
#% type: string
#% description: csv with strata values in first column and count of cells to gain in second column
#% required : yes
#%End
#%Option
#% key: minHH
#% type: string
#% description: minimum count of households for cell to be considered developed
#% required : yes
#%End
#%Option
#% key: minNull
#% type: string
#% description: minimum percent of cell that must be null for the cell to be considered ineligible for development
#% required : yes
#%End
#%Option
#% key: tmpDir
#% type: string
#% description: location of directroy to place temporary files.  Very important!  This directory is overwritten.
#% required : yes
#%End

if [ -z "$GISBASE" ] ; then
    echo "You must be in GRASS GIS to run this program." 1>&2
    exit 1
fi

if [ "$1" != "@ARGS_PARSED@" ] ; then
  exec g.parser "$0" "$@"
fi

prepareWorkspace()
{
# remove mask in case present
r.mask -r

# remove existing maps in GRASS location to avoid confusion
g.mremove -f rast=* vect=*

# get full path to outdir
absoutdir=$(readlink -f $GIS_OPT_OUTDIR)
absSuitability=$(readlink -f $GIS_OPT_SUITABILITYMAP)
absStrata=$(readlink -f $GIS_OPT_STRATAMAP)

# make directory for headerless ASCII files
headerless=$GIS_OPT_TMPDIR
rm -r $headerless 2>/dev/null
mkdir $headerless 2>/dev/null

# make directory for columns to be reorganized into new ASCII file for alt_geomod steps
rm -r $absoutdir 2>/dev/null
mkdir $absoutdir

# make reclass rules file for GRASS that converts 0 to null
rm /tmp/remove0.rcl 2>/dev/null
echo "*" = 1 > /tmp/remove0.rcl
}

userDefinedMaps()
{
# given user input, determine residential cells
rm /tmp/minHH.rcl 2>/dev/null
echo $GIS_OPT_MINHH thru 999999 = 1 >> /tmp/minHH.rcl
echo 1 thru $GIS_OPT_MINHH = 0 >> /tmp/minHH.rcl
r.in.gdal -o input=$GIS_OPT_RESIDENTIALMAP output=residentialMap --overwrite
# in GRASS, set region
g.region rast=residentialMap
# continue determining residential cells according to user parameter
r.reclass input=residentialMap output=residentialMap_tmp rules=/tmp/minHH.rcl --overwrite
r.reclass input=residentialMap_tmp output=residentialMap_boolean rules=/tmp/remove0.rcl --overwrite

# given user input, determine ineligible cells
rm /tmp/minNull.rcl 2>/dev/null
echo 1 thru $GIS_OPT_MINNULL = 0 >> /tmp/minNull.rcl
echo $GIS_OPT_MINNULL thru 999999 = 1 >> /tmp/minNull.rcl
r.in.gdal -o input=$GIS_OPT_NULLMAP output=nullMap --overwrite
r.reclass input=nullMap output=nullMap_tmp rules=/tmp/minNull.rcl --overwrite
r.reclass input=nullMap_tmp output=nullMap_boolean rules=/tmp/remove0.rcl --overwrite
}

importMaps()
{
# add suitability and strata maps to GRASS
r.in.gdal -o input=$GIS_OPT_SUITABILITYMAP output=suitabilityMap --overwrite
r.in.gdal -o input=$GIS_OPT_STRATAMAP output=strataMap --overwrite
}

getCounts()
{
# for each stratum in gainCSV, mask out all but one stratum, then crosstab suitability, null, and res
listStrata=$(awk -F, '{print $1}' $GIS_OPT_GAINCSV | sed '1d')
for i in $listStrata
do
	# mask out one stratum at a time
	r.mask -o input=strataMap maskcats=$i
	# determine stuiability value ranks
	r.stats -c input=residentialMap_boolean,suitabilityMap output=- | awk '{if($1 == 1) print $0}' | grep -v "*" | sort -rnk 3,3 > $headerless/${i}.developed
	# get counts of all cells in town - need this to weigh by
	r.report -h map=suitabilityMap units=c | awk -F"|" '{print $2,$4}' | sed '1,4d' | sed 's:-::g;s:TOTAL::g' | grep -v "*" | sed '$d' | sed '$d' | sed '$d'  > $headerless/${i}.townCells
	# get rank of suitability categories from most developed to least developed 
	while read line
	do 
		suitabilityCat=$(echo $line | awk '{print $2}')
		developedCatArea=$(echo $line | awk '{print $3}')
		townCatArea=$(awk "{if(\$1 == $suitabilityCat) print \$2}" $headerless/${i}.townCells)
		ratio=$(echo "scale = 2; $developedCatArea / $townCatArea" | bc)
		echo $suitabilityCat $ratio >> $headerless/${i}.ranktmp
	done < $headerless/${i}.developed
	sort -rnk 2,2 $headerless/${i}.ranktmp > $headerless/${i}.rank
	rm $headerless/${i}.ranktmp
	# determine count of non-null cells for each suitability value
	r.stats -c input=residentialMap_boolean,suitabilityMap,nullMap_boolean output=- | awk '{if($1 == "*") print $0}' | awk '{if($3 == "*") print $0}' | sort -rnk 4,4 > $headerless/${i}.eligibleCount
	# get count of cells to gain in this stratum
	strataGain=$(awk -F, "{if(\$1 == $i) print \$2}" $GIS_OPT_GAINCSV)
	# loop on ranks in order of existing res
	# determine whether count of eligible cells in rank is less than equal to number of cells to develop
	for r in $(awk '{print $1}' $headerless/${i}.rank)
	do 
		potentialEligible=$(awk "{if(\$2 == $r) print \$4}" $headerless/${i}.eligibleCount)
		if [[ -n $potentialEligible ]]; then 
			eligibleCount=$potentialEligible
		else
			eligibleCount=0
		fi
		if [[ $eligibleCount -le $strataGain ]]; then
			echo $r $eligibleCount >> $headerless/${i}.changeAll
			strataGain=$(expr $strataGain - $eligibleCount) 
		else
			echo $r $strataGain >> $headerless/${i}.changeSome
			break
		fi
	done
	# note that ranks in changeAll file must be changed first, as only the last rank to appear will ever be in a changeSome file - there will be no gain left
	# with changeSome, you must know the current strataGain needed because changeAll ranks might have some before it	
	# remove mask in order to mask next stratum
	r.mask -r
done
}

getChangeAll()
{
# export user definied residential map
rm $absoutdir/residentialMap_boolean.tif 2>/dev/null
r.out.gdal input=residentialMap_boolean format=GTiff type=Byte nodata=0 output=$absoutdir/residentialMap_boolean.tif
gdal_translate -of AAIGrid $absoutdir/residentialMap_boolean.tif $absoutdir/residentialMap_boolean.asc

# export user defined null map
rm $absoutdir/nullMap_boolean.tif 2>/dev/null
r.out.gdal input=nullMap_boolean format=GTiff type=Byte nodata=0 output=$absoutdir/nullMap_boolean.tif
gdal_translate -of AAIGrid $absoutdir/nullMap_boolean.tif $absoutdir/nullMap_boolean.asc

# retain ASCII header for later use, determine number of columns
firstASCII=$(ls *.asc | sed q)
ASCIIheader=$(sed -n '1,6p' $firstASCII)
numcol=$(echo $ASCIIheader | sed 's:ncols \([0-9]\+\).*:\1:g')

cd $absoutdir
cp $absSuitability . 
cp $absStrata .
for i in $GIS_OPT_SUITABILITYMAP $GIS_OPT_STRATAMAP residentialMap_boolean.asc nullMap_boolean.asc
do 
	sed '1,6d' $i > $headerless/$i	
done

# reorganized into new ASCII file for alt_geomod steps
cd $headerless
for i in $(seq 1 $numcol)
do
	for f in *.asc
	do	
		awk "{print \$"$i"\",\"}" $f >> $headerless/${i}_${f}
	done
	cd $headerless
	# defines the order in which maps are pasted together
	paste -d, ${i}_residentialMap_boolean.asc ${i}_nullMap_boolean.asc ${i}_${GIS_OPT_SUITABILITYMAP} ${i}_${GIS_OPT_STRATAMAP} > $i.col
	sed -i 's:,\+:,:g;s:,$::g' ${i}.col
	rm ${i}_*
	cd - >>/dev/null
done

# paste columns together in numberical order
paste -d" " $(ls *.col | sort -n) > /tmp/tmp.asc
# remove temporary files
rm *.col
}

getChangeSome()
{
# make reclass file for changeSome changes - necessary to mask out zero values
rm /tmp/makeZeroNull.rcl 2>/dev/null
echo 0 = NULL >> /tmp/makeZeroNull.rcl
echo "*" = "*" >> /tmp/makeZeroNull.rcl

# alter text file made of pasted columns based on text files made earlier
r.mapcalc "eligible=if(isnull(residentialMap_boolean),1,0)*if(isnull(nullMap_boolean),1,0)"
for i in $listStrata
do 
	if [[ -e ${i}.changeAll ]]; then
	while read line
	do 
		r=$(echo $line | awk '{print $1}')
		sed -i "s:0,0,\b$r\b,\b$i\b:1,0,$r,$i:g" /tmp/tmp.asc
	done < ${i}.changeAll
	fi
done

makeSpatial()
{
# remove all but residential cell information
sed -i "s:\([0-9]\+\),[0-9]\+,[0-9]\+,[0-9]\+:\1:g" /tmp/tmp.asc
# put ASCII header back on
sed -i 1i"$(echo $ASCIIheader)" /tmp/tmp.asc
}

# make outasc spatial, remove all non-residential information
makeSpatial

for i in $listStrata
do 
	if [[ -e ${i}.changeSome ]]; then
		r.mask -r
		r=$(awk '{print $1}' ${i}.changeSome)
		n=$(awk '{print $2}' ${i}.changeSome)
		r.mask -o input=strataMap maskcats=$i
		r.random.cells --o output=random_${i} distance=1 seed=30787625
		r.mask -o input=suitabilityMap maskcats=$r
		r.mapcalc "randomAndEligible_${i}=random_${i}*eligible"
		r.mask -o input=strataMap maskcats=$i
		r.reclass input=randomAndEligible_${i} output=changeSome_${i} rules=/tmp/makeZeroNull.rcl --overwrite
		toRemove=$(r.describe -n -1 map=changeSome_${i} | sort -rn | sed "1,${n}d")
		# make a reclass file to remove unecessary random cells
		rm /tmp/toRemove.rcl 2>/dev/null
		echo $toRemove = NULL >> /tmp/toRemove.rcl
		echo "*" = "*" >> /tmp/toRemove.rcl
		cat  /tmp/toRemove.rcl
		# remove uneeded random cells
		r.reclass input=changeSome_${i} output=randomGain_${i}_${r} rules=/tmp/toRemove.rcl
		# keep all randomm gains in grass until can patch with imported changeAll
		#r.reclass input=randomGain_${i}_${r} output=boolean_randomGain_${i}_${r} rules=/tmp/makeOne.rcl
		r.mapcalc "boolean_randomGain_${i}_${r}=if(randomGain_${i}_${r} >= 1,1,0)"
		r.mask -r
	fi
done
# patch together randomGain
randomGain_list=$(g.mlist type=rast sep=, pat="boolean_randomGain_*")
r.patch in=$randomGain_list out=all_randomGain --overwrite
# import changeAll map
r.in.gdal -o input=/tmp/tmp.asc output=outAsc --overwrite
# patch together changeAll and changeSome maps
r.patch in=all_randomGain,outAsc out=allGains --overwrite
}

outputs()
{
# export modeled output
r.out.gdal input=allGains format=GTiff type=Byte nodata=0 output=$absoutdir/$GIS_OPT_OUTPUT
cd $absoutdir
mkdir count_files
cd $headerless
# copy count files to outdir
cp *.rank *.change* *.townCells *.eligibleCount *.developed $absoutdir/count_files
# add headers to count files
cd $absoutdir/count_files
sed -i 1i"suitability cat,number of cells to gain" *.change*
sed -i 1i"whether developed,suitability cat,number of cells developed" *.developed
sed -i 1i"whether developed,suitability cat,whether null,number of cells eligible" *.eligibleCount
sed -i 1i"suitability cat,ratio of developed to not developed" *.rank
sed -i 1i"suitability cat,number of cells in stratum" *.townCells
# remove unecessary files
cd $absoutdir
rm nullMap_boolean.tif nullMap_boolean.prj residentialMap_boolean.tif residentialMap_boolean.prj
}

# run funtions defined above
prepareWorkspace
userDefinedMaps
importMaps
getCounts
getChangeAll
getChangeSome
outputs

exit 0
