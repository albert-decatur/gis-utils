# get 2nd degree polynomial trend surface from point shapefile
# args are: 1) input GIS vector points, 2) polynomial degree, 3) trmat grid dimensions (n X n)
# example use: Rscript --vanilla $0 AL032009.shp 1 500

# load prereqs
library(methods) # this is only required when running with Rscript
library(maptools)
library(spatial)
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
# make trend surface
t <- surf.ls(as.numeric(args[2]),d$lon,d$lat,d$sshws)
# make trend surface over grid
g <- trmat(t,bbox(d)[1,1],bbox(d)[1,2],bbox(d)[2,1],bbox(d)[2,2],as.numeric(args[3]))
# visual
png(paste("/tmp/",layerName,".png",sep=''))
image(g)
title(main=paste(layerName, ", ",args[2]," Degree Polynomial",sep=''))
points(d$lon,d$lat)
contour(g,labcex=1,add=T)
dev.off()
