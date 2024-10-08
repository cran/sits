% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_regularize.R
\name{sits_regularize}
\alias{sits_regularize}
\alias{sits_regularize.raster_cube}
\alias{sits_regularize.sar_cube}
\alias{sits_regularize.dem_cube}
\alias{sits_regularize.derived_cube}
\alias{sits_regularize.default}
\title{Build a regular data cube from an irregular one}
\usage{
sits_regularize(
  cube,
  ...,
  period,
  res,
  output_dir,
  roi = NULL,
  tiles = NULL,
  multicores = 2L,
  progress = TRUE
)

\method{sits_regularize}{raster_cube}(
  cube,
  ...,
  period,
  res,
  output_dir,
  roi = NULL,
  multicores = 2L,
  progress = TRUE
)

\method{sits_regularize}{sar_cube}(
  cube,
  ...,
  period,
  res,
  output_dir,
  roi = NULL,
  tiles = NULL,
  multicores = 2L,
  progress = TRUE
)

\method{sits_regularize}{dem_cube}(
  cube,
  ...,
  res,
  output_dir,
  roi = NULL,
  tiles = NULL,
  multicores = 2L,
  progress = TRUE
)

\method{sits_regularize}{derived_cube}(cube, ...)

\method{sits_regularize}{default}(cube, ...)
}
\arguments{
\item{cube}{\code{raster_cube} object whose observation
period and/or spatial resolution is not constant.}

\item{...}{Additional parameters for \code{fn_check} function.}

\item{period}{ISO8601-compliant time period for regular
data cubes, with number and unit, where
"D", "M" and "Y" stand for days, month and year;
 e.g., "P16D" for 16 days.}

\item{res}{Spatial resolution of regularized images (in meters).}

\item{output_dir}{Valid directory for storing regularized images.}

\item{roi}{A named \code{numeric} vector with a region of interest.}

\item{tiles}{MGRS tiles to be produced (only for Sentinel-1 cubes)}

\item{multicores}{Number of cores used for regularization;
used for parallel processing of input (integer)}

\item{progress}{show progress bar?}
}
\value{
A \code{raster_cube} object with aggregated images.
}
\description{
Produces regular data cubes for analysis-ready data (ARD)
image collections. Analysis-ready data (ARD) collections available in
AWS, MPC, USGS and DEAfrica are not regular in space and time.
Bands may have different resolutions,
images may not cover the entire time, and time intervals are not regular.
For this reason, subsets of these collection need to be converted to
regular data cubes before further processing and data analysis.
This function requires users to include the cloud band in their ARD-based
data cubes.
}
\note{
The "roi" parameter defines a region of interest. It can be
     an sf_object, a shapefile, or a bounding box vector with
     named XY values ("xmin", "xmax", "ymin", "ymax") or
     named lat/long values ("lat_min", "lat_max", "long_min", "long_max").
     \code{sits_regularize()} function will crop the images
     that contain the region of interest().

The aggregation method used in \code{sits_regularize}
     sorts the images based on cloud cover, where images with the fewest
     clouds at the top of the stack. Once
     the stack of images is sorted, the method uses the first valid value to
     create the temporal aggregation.

The input (non-regular) ARD cube needs to include the cloud band for
     the regularization to work.
}
\examples{
if (sits_run_examples()) {
    # define a non-regular Sentinel-2 cube in AWS
    s2_cube_open <- sits_cube(
        source = "AWS",
        collection = "SENTINEL-2-L2A",
        tiles = c("20LKP", "20LLP"),
        bands = c("B8A", "CLOUD"),
        start_date = "2018-10-01",
        end_date = "2018-11-01"
    )
    # regularize the cube
    rg_cube <- sits_regularize(
        cube = s2_cube_open,
        period = "P16D",
        res = 60,
        multicores = 2,
        output_dir = tempdir()
    )

    ## Sentinel-1 SAR
    roi <- c("lon_min" = -50.410, "lon_max" = -50.379,
             "lat_min" = -10.1910, "lat_max" = -10.1573)
    s1_cube_open <- sits_cube(
        source = "MPC",
        collection = "SENTINEL-1-GRD",
        bands = c("VV", "VH"),
        orbit = "descending",
        roi = roi,
        start_date = "2020-06-01",
        end_date = "2020-09-28"
    )
    # regularize the cube
    rg_cube <- sits_regularize(
        cube = s1_cube_open,
        period = "P12D",
        res = 60,
        roi = roi,
        multicores = 2,
        output_dir = tempdir()
    )
}

}
\references{
Appel, Marius; Pebesma, Edzer. On-demand processing of data cubes
 from satellite image collections with the gdalcubes library. Data, v. 4,
 n. 3, p. 92, 2019. DOI: 10.3390/data4030092.
}
