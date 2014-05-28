#!/bin/bash
# csv2shp.sh

usage()
{
cat << EOF
usage: $0 [OPTIONS]

Export CSV as point shapefile using longitude and latitude columns.
Output shapefile must not exist.
If no -s flag is used, name of CSV will be used as name of shapefile.
Example: $0 -c foo.csv -x longitude -y latitude -s bar.shp

OPTIONS:
   -h      Show this message
   -c      input CSV
   -x      CSV longitude field name
   -y      CSV latitude field name
   -s      output shapefile name
EOF
}

while getopts "hx:y:c:s:" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         c)
             incsv=$OPTARG
             ;;
         x)
             longitude=$OPTARG
             ;;
         y)
             latitude=$OPTARG
             ;;
         s)
             outshp=$OPTARG
             ;;
         ?)
             usage
             exit
             ;;
     esac
done

echo "<OGRVRTDataSource>                                                              
        <OGRVRTLayer name=\"$(basename $incsv .csv)\">                                             
                <SrcDataSource>$incsv</SrcDataSource>                       
                <SrcLayer>$(basename $incsv .csv)</SrcLayer>                                     
                <GeometryType>wkbPoint</GeometryType>                           
                <LayerSRS>WGS84</LayerSRS>                                      
                <GeometryField encoding=\"PointFromColumns\" x=\"$longitude\" y=\"$latitude\" />
        </OGRVRTLayer>                                                          
</OGRVRTDataSource>" > /tmp/$(basename $incsv .csv).vrt


if [ -z $outshp ]; then
	ogr2ogr $(basename $incsv .csv).shp /tmp/$(basename $incsv .csv).vrt
else
	ogr2ogr $outshp /tmp/$(basename $incsv .csv).vrt
fi

exit 0
