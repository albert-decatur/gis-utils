#!/bin/bash
# prereq: netcdf-bin, gdal-bin
# user args: 
	# 1) input NetCDF with points, 
	# 2) spatial reference system ( eg WGS84 ), 
	# 3) comma separated list of three NetCDF variables: variable to burn into raster, lat, lon (order matters),
	# 4) spatial res in map units, 
	# 5) nodata value for burn variable
	# 6) output tif
# example use: $0 in.nc WGS84 p2050,lat_fx,lon_fx 0.125 -9999 out.tif
# this example uses in.nc to make out.tif in WGS84, burning in the variable p2050 at 0.125 degrees on a pixel side, nodata is -9999
# NB: overwrites /tmp/tsv.tsv when converting nc2tsv and /tmp/vrt.vrt when making OGR VRT

in_nc=$1
srs=$2
varstring=$3
res=$4
nodata=$5
out=$6


nc2tsv() {
	# make a directory to hold temporary files - delete it if it exists already
	rm -r /tmp/$in_nc 2>/dev/null
	mkdir /tmp/$in_nc

	# gt ncdump to print out the input nc file
	dumptxt=$(ncdump -v $varstring $in_nc)
	# get the data section on the ncdump
	# it's everything after "data:", except for semi-colons and the end curly brace at the very end
	data=$(
		echo "$dumptxt"|\
		sed '1,/data:/d' |\
		sed 's:}::g;s:;::g' |\
		grep -vE "^$"
	)

	# define a temporary file
	tmp=$(mktemp)
	# dump data section from ncdump into tmp file
	echo "$data" > $tmp
	# for every variable, print a file
	# NB: the first file is blank
	csplit -f /tmp/$in_nc/$in_nc $tmp '/=/' {*} 1>/dev/null

	# for every nc variable, 
	for var in $(find /tmp/$in_nc -type f)
	do 
		# the first split file is blank - do nothing
		if [[ "$(cat $var | wc -l )" = "0" ]]; then 
			false
		else
			# get the variable header - it's text on the first line before an equals sign
			var_header=$( cat $var | grep -oE "^.*=" | sed 's:=::g' | sed 's:^[ \t]\+::g;s:[ \t]\+$::g' )
			# get the variable data - it's comma separated text after the equals sign on the first line
			var_data=$( cat $var | sed 's:^.*[=]::g'|tr ',' '\n'|sed 's:^[ \t]\+::g;s:[ \t]\+$::g'|grep -vE "^$" )
			# print the variable data with header to a file named after the header
			echo -e "$var_header\n$var_data" > /tmp/"$var_header"
		fi
	done

	# make a single TSV from every variable, in the order user provided
	eval paste $(echo "/tmp/{$varstring}") > /tmp/tsv.tsv
}

# get the names of the second (lat) and third (lon) NetCDF variables listed by user
# used by OGR VRT
get_latlonCols() {
	latlon=$( echo $varstring | tr "," "\n" | sed -n "2,3p" )
	latCol=$( echo "$latlon" | sed -n "1p" )
	lonCol=$( echo "$latlon" | sed -n "2p" )
}

# print out OGR VRT format for points with user's lat, lon, srs
mk_vrt() {
	echo "
	<OGRVRTDataSource>
	    <OGRVRTLayer name=\"tsv\">
		<SrcDataSource>/tmp/tsv.tsv</SrcDataSource>
		<GeometryType>wkbPoint</GeometryType>
		<LayerSRS>$srs</LayerSRS>
		<GeometryField encoding=\"PointFromColumns\" x=\"$lonCol\" y=\"$latCol\"/>
	    </OGRVRTLayer>
	</OGRVRTDataSource>" > /tmp/vrt.vrt
}

mk_tif() {
	# get name of first user NetCDF variable to burn into raster
	burnvar=$( echo $varstring | tr "," "\n" | sed -n "1p" )
	gdal_rasterize -a $burnvar -l tsv -a_nodata $nodata -co COMPRESS=LZW -tr $res $res /tmp/vrt.vrt $out
}

nc2tsv
get_latlonCols
mk_vrt
mk_tif
