# Template for R analysis script
# Ben Bond-Lamberty March 2015

# This is my starting point for most analysis or data processing scripts
# Most critically, it provides lightweight logging, with sessionInfo() 
# written at the bottom of every log; easy ggplot and data saving; 
# logged csv[.gz|zip] read/write; and a few other handy things.

INPUT_DIR     <- "data/"
OUTPUT_DIR		<- "outputs/"
#RANDOM_SEED		<- 12345		# comment out to not set seed
#CHECKPOINTDATE	<- "2015-03-05" # comment out to not use checkpoint
SEPARATOR		<- "-------------------"

# -----------------------------------------------------------------------------
# Print dimensions of data frame
print_dims <- function(d, dname=deparse(substitute(d))) {
  stopifnot(is.data.frame(d))
  printlog(dname, "rows =", nrow(d), "cols =", ncol(d))
} # print_dims

# -----------------------------------------------------------------------------
# Return matrix of memory consumption
object_sizes <- function() {
  rev(sort(sapply(ls(envir=.GlobalEnv), function(object.name) 
    object.size(get(object.name)))))
} # object_sizes

# -----------------------------------------------------------------------------
# Return output directory (perhaps inside a script-specific folder)
# If caller specifies `scriptfolder=FALSE`, return OUTPUT_DIR
# If caller specifies `scriptfolder=TRUE` (default), return OUTPUT_DIR/SCRIPTNAME
outputdir <- function(scriptfolder=TRUE) {
  output_dir <- OUTPUT_DIR
  if(scriptfolder) output_dir <- file.path(output_dir, sub(".R$", "", SCRIPTNAME))
  if(!file.exists(output_dir)) dir.create(output_dir)
  output_dir
} # outputdir

# -----------------------------------------------------------------------------
# Save a ggplot figure
save_plot <- function(pname, p=last_plot(), ptype=".pdf", scriptfolder=TRUE, ...) {
  fn <- file.path(outputdir(scriptfolder), paste0(pname, ptype))
  printlog("Saving", fn)
  ggsave(fn, p, ...)
} # save_plot

# -----------------------------------------------------------------------------
# Save a data frame
save_data <- function(df, fname=paste0(deparse(substitute(df)), ".csv"), scriptfolder=TRUE, gzip=FALSE, ...) {
  fn <- file.path(outputdir(scriptfolder), fname)
  if(gzip) {
    printlog("Saving", fn, "[gzip]")    
    fn <- gzfile(paste0(fn, ".gz"))
  } else {
    printlog("Saving", fn)    
  }
  write.csv(df, fn, row.names=FALSE, ...)
} # save_data

# -----------------------------------------------------------------------------
# Open a netCDF file and return handle (using ncdf4 package)
open_ncdf <- function(fn, datadir=".") {
  fqfn <- file.path(datadir, fn)
  printlog("Opening", fqfn)
  nc_open(fqfn)
} # open_ncdf

# -----------------------------------------------------------------------------
# Open a (possibly compressed) csv file and return data
read_csv <- function(fn, datadir=".", ...) {
  if(is.null(datadir)) {  # NULL signifies absolute path
    fqfn <- fn 
  } else {
    fqfn <- file.path(datadir, fn)      
  }
  printlog("Opening", fqfn)
  if(grepl(".gz$", fqfn)) {
    fqfn <- gzfile(fqfn)
  } else if(grepl(".zip$", fqfn)) {
    fqfn <- unz(fqfn)
  }
  invisible(read.csv(fqfn, stringsAsFactors=F, ...))
} # read_csv

# -----------------------------------------------------------------------------
# Read data from the clipboard
paste_data <- function(header=TRUE) {
  read.table(pipe("pbpaste"), header=header)
} # paste_data

# -----------------------------------------------------------------------------
is_outlier <- function(x, devs=3.2) {
  # See: Davies, P.L. and Gather, U. (1993).
  # "The identification of multiple outliers" (with discussion)
  # J. Amer. Statist. Assoc., 88, 782-801.
  
  x <- na.omit(x)
  lims <- median(x) + c(-1, 1) * devs * mad(x, constant = 1)
  x < lims[ 1 ] | x > lims[2]
} # is_outlier

if(!file.exists(OUTPUT_DIR)) {
  printlog("Creating", OUTPUT_DIR)
  dir.create(OUTPUT_DIR)
}

# from http://www.cookbook-r.com/Graphs/Multiple_graphs_on_one_page_(ggplot2)/

# Multiple plot function
#
# ggplot objects can be passed in ..., or to plotlist (as a list of ggplot objects)
# - cols:   Number of columns in layout
# - layout: A matrix specifying the layout. If present, 'cols' is ignored.
#
# If the layout is something like matrix(c(1,2,3,3), nrow=2, byrow=TRUE),
# then plot 1 will go in the upper left, 2 will go in the upper right, and
# 3 will go all the way across the bottom.
#
multiplot <- function(..., plotlist=NULL, file, cols=1, layout=NULL) {
  require(grid)
  
  # Make a list from the ... arguments and plotlist
  plots <- c(list(...), plotlist)
  
  numPlots = length(plots)
  
  # If layout is NULL, then use 'cols' to determine layout
  if (is.null(layout)) {
    # Make the panel
    # ncol: Number of columns of plots
    # nrow: Number of rows needed, calculated from # of cols
    layout <- matrix(seq(1, cols * ceiling(numPlots/cols)),
                     ncol = cols, nrow = ceiling(numPlots/cols))
  }
  
  if (numPlots==1) {
    print(plots[[1]])
    
  } else {
    # Set up the page
    grid.newpage()
    pushViewport(viewport(layout = grid.layout(nrow(layout), ncol(layout))))
    
    # Make each plot, in the correct location
    for (i in 1:numPlots) {
      # Get the i,j matrix positions of the regions that contain this subplot
      matchidx <- as.data.frame(which(layout == i, arr.ind = TRUE))
      
      print(plots[[i]], vp = viewport(layout.pos.row = matchidx$row,
                                      layout.pos.col = matchidx$col))
    }
  }
}

# -----------------------------------------------------------------------------
#if(exists("CHECKPOINTDATE") & require(checkpoint))
#    try(checkpoint(CHECKPOINTDATE)) # 'try' b/c errors w/o network (issue #171)
library(ggplot2)
theme_set(theme_bw())
library(reshape2)
library(dplyr)
library(readr)
library(lubridate)
library(stringr)
library(luzlogr)

