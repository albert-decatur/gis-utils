#!/bin/bash
# csv2shp.sh

usage()
{
cat << EOF
usage: $0 [OPTIONS]

Export CSV as OGR VRT file using longitude and latitude columns.
Example: $0 -c foo.csv -x longitude -y latitude -o bar/

OPTIONS:
   -h      Show this message
   -c      input CSV
   -x      CSV longitude field name
   -y      CSV latitude field name
   -o      output directory for VRT file
EOF
}

while getopts "hx:y:c:o:" OPTION
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
         o)
             outdir=$OPTARG
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
</OGRVRTDataSource>" > $outdir/$(basename $incsv .csv).vrt

exit 0
