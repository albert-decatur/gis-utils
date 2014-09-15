#!/usr/bin/python

# use ogr to make a new shapefile with select by attributes
# note that 'ogr2ogr -sql' is way awesomer
# this script was nearly written by http://gis.stackexchange.com/ user Luke: http://gis.stackexchange.com/questions/68650/ogr-how-to-save-layer-from-attributefilter-to-a-shape-filter
# example use: selectByAttributes.py parks.shp 'PARK_TYPE2 = "Park"' new.shp

from osgeo import ogr
import sys
import os
inds = ogr.Open(sys.argv[1])
inlyr=inds.GetLayer()
# apply the user supplied SQL to select by attributes
inlyr.SetAttributeFilter(sys.argv[2])
drv = ogr.GetDriverByName( 'ESRI Shapefile' )
# if output shp exists delete it
if os.path.exists(sys.argv[3]):
	drv.DeleteDataSource(sys.argv[3])
outds = drv.CreateDataSource(sys.argv[3])
# get basename (layer name) of output shp
basename = os.path.basename(sys.argv[3])
outlyr = outds.CopyLayer(inlyr,basename)
del inlyr,inds,outlyr,outds
