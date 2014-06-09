#!/bin/bash

usage()
{
cat << EOF
usage: $0 [OPTIONS] 

Makes point map of photos from EXIF GPS data.
When using pattern matching for inputs, encase argument in double quotes.
KML exports include altitude.
Example use: $0 -i "*.jpg" -o out.kml

OPTIONS:
   -h      Show this message
   -i      input photos, eg "*.jpg"
   -o      output KML or Shapefile
EOF
}

while getopts “hi:o:” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         i)
             inphotos=$OPTARG
             ;;
         o)
             outpoints=$OPTARG
             ;;
	 ?)
             usage
             exit
             ;;
     esac
done

ext=$(echo $outpoints | sed 's:^.*[.]::g')
if [ $ext != kml -a $ext != shp ]; then
	echo "Output spatial file must be either shapefile or KML."
	exit 0
fi

latlongfile=/tmp/latlong.csv
rm $latlongfile 2>/dev/null
touch $latlongfile

layername=photo_points
srcsource=$latlongfile
srclayer=$(basename $srcsource .csv)

VRT="<OGRVRTDataSource>
<OGRVRTLayer name=\""$layername"\">
  <SrcDataSource>$srcsource</SrcDataSource>
  <SrcLayer>"$srclayer"</SrcLayer>
  <GeometryType>wkbPoint</GeometryType>
  <LayerSRS>WGS84</LayerSRS>
  <GeometryField encoding=\"PointFromColumns\" x=\"long\" y=\"lat\"/>
   </OGRVRTLayer>
</OGRVRTDataSource>"

rm /tmp/placemarks.txt 2>/dev/null
touch /tmp/placemarks.txt
vrtpath=/tmp/${srclayer}.vrt
rm $vrtpath 2>/dev/null
echo $VRT > $vrtpath

for i in $inphotos 
do 
	latlong=$(gdalinfo $i | grep -E "EXIF_GPSLatitudeRef|EXIF_GPSLongitudeRef|EXIF_GPSLatitude|EXIF_GPSLongitude|EXIF_GPSAltitude=|EXIF_DateTime=" )
	latref=$(echo "$latlong" | grep LatitudeRef | sed 's:.*\(.$\):\1:g')
	longref=$(echo "$latlong" | grep LongitudeRef | sed 's:.*\(.$\):\1:g')
	latraw=$(echo "$latlong" | grep 'Latitude=' | sed 's:[^0-9. ]::g;s:^ ::g' | awk '{print $1+($2*60+$3)/3600}')
	longraw=$(echo "$latlong" | grep 'Longitude=' | sed 's:[^0-9. ]::g;s:^ ::g' | awk '{print $1+($2*60+$3)/3600}')
	if [ $latref == "S" ]; then
		latraw=$( echo $latraw | sed 's:^:-:g')
	fi
	if [ $longref == "W" ]; then
		longraw=$( echo $longraw | sed 's:^:-:g')
	fi
	time=$(echo "$latlong" | grep 'DateTime=' | sed 's:.*[=]::g;s:^\([0-9]\+\)\::\1-:g;s:-\([0-9]\+\)\::-\1-:g;s: :T:g;s:$:Z:g')
	altitude=$(echo "$latlong" | grep 'GPSAltitude=' | sed 's:.*[=]::g;s:(::g;s:)::g')
	if [ $ext == kml ]; then
		echo "<Placemark>
        <name>$i</name>
        <TimeStamp><when>$time</when></TimeStamp>
	<ExtendedData><SchemaData schemaUrl=\"#photo_points\">
                <SimpleData name=\"lat\">$latraw</SimpleData>
                <SimpleData name=\"long\">$longraw</SimpleData>
                <SimpleData name=\"time\">$time</SimpleData>
                <SimpleData name=\"altitude\">$altitude</SimpleData>
                <SimpleData name=\"file\">$i</SimpleData>
        </SchemaData></ExtendedData>
        <Point><altitudeMode>absolute</altitudeMode><coordinates>$longraw,$latraw,$altitude</coordinates></Point>
        </Placemark>" >> /tmp/placemarks.txt	
	fi
	echo $latraw,$longraw,$time,$altitude,\"$i\" >> $latlongfile
done

sed -i 1i"lat,long,time,altitude,file" $latlongfile

if [ $ext == shp ]; then 
	ogr2ogr $outpoints $vrtpath
elif [ $ext == kml ]; then
	ogr2ogr -f KML $outpoints $vrtpath
	sed '/<Placemark>/,/<\/Placemark>/d' $outpoints > /tmp/metadata.txt
	lastline=$(sed '$!d' /tmp/metadata.txt)
	sed -i '$d' /tmp/metadata.txt
	cat /tmp/placemarks.txt >> /tmp/metadata.txt
	echo $lastline >> /tmp/metadata.txt
	cp /tmp/metadata.txt $outpoints
fi 

exit 0
