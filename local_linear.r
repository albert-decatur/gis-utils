# originally made to produce maps of Saffir-Simpson index for all Atlantic hurricanes in HURDAT
# TODO: add basemap to png
# TODO: export tif
# args are: 1) input GIS vector points
# example use: Rscript --vanilla $0 AL132003.shp

# load prereqs
library(methods) # this is only required when running with Rscript
library(maptools)
library(akima)
# get user args
args <- commandArgs(trailingOnly = TRUE)
# load points
d <- readShapePoints(args[1])
# get name of layer without file extension - assumes a period then a file extension then end of line
# needed for plot title, png filename
layerName <- unlist(strsplit(basename(args[1]),"\\."))[1]
# numeric fields are numeric
# TODO loop over user arg list of fields
d$lon <- as.numeric(as.character(d$lon))
d$lat <- as.numeric(as.character(d$lat))
d$sshws <- as.numeric(as.character(d$sshws))
# linear interpolation using akima package
# note that map units are used as the spatial res, and that BBOX is used for grid
# TODO: user arg for spatial res
d.li <- interp(d$lon,d$lat,d$sshws, xo=seq(bbox(d)[1,1],bbox(d)[1,2], length=abs(bbox(d)[1,1] - bbox(d)[1,2])),yo=seq(bbox(d)[2,1],bbox(d)[2,2], length=abs(bbox(d)[2,1] - bbox(d)[2,2])))
# enforce min (0) and max (particular to the HURDAT points)
# first find the SSHWS max
maxsshws <- max(d$sshws)
# now enforce 0 min and SSHWS max on trend grid
maxsshws <- max(d$sshws); d.li$z <- round(replace(replace(d.li$z,d.li$z>maxsshws,maxsshws),d.li$z<0,0))
# visual
png(paste("/tmp/",layerName,".png",sep=''))
image(d.li)
title(main=paste(layerName, ", "," Linear Interpolation from Akima",sep=''))
contour(d.li,labcex=1,add=T,nlevels=maxsshws)
points(d$lon,d$lat)
dev.off()
