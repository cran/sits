% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_view.R
\name{sits_view}
\alias{sits_view}
\alias{sits_view.sits}
\alias{sits_view.data.frame}
\alias{sits_view.som_map}
\alias{sits_view.raster_cube}
\alias{sits_view.uncertainty_cube}
\alias{sits_view.class_cube}
\alias{sits_view.probs_cube}
\alias{sits_view.vector_cube}
\alias{sits_view.class_vector_cube}
\alias{sits_view.default}
\title{View data cubes and samples in leaflet}
\usage{
sits_view(x, ...)

\method{sits_view}{sits}(x, ..., legend = NULL, palette = "Set3", radius = 10L, add = FALSE)

\method{sits_view}{data.frame}(x, ..., legend = NULL, palette = "Harmonic", add = FALSE)

\method{sits_view}{som_map}(
  x,
  ...,
  id_neurons,
  legend = NULL,
  palette = "Harmonic",
  radius = 10L,
  add = FALSE
)

\method{sits_view}{raster_cube}(
  x,
  ...,
  band = NULL,
  red = NULL,
  green = NULL,
  blue = NULL,
  tiles = x[["tile"]][[1L]],
  dates = NULL,
  palette = "RdYlGn",
  rev = FALSE,
  opacity = 0.85,
  max_cog_size = 2048L,
  first_quantile = 0.02,
  last_quantile = 0.98,
  leaflet_megabytes = 64L,
  add = FALSE
)

\method{sits_view}{uncertainty_cube}(
  x,
  ...,
  tiles = x[["tile"]][[1L]],
  legend = NULL,
  palette = "RdYlGn",
  rev = FALSE,
  opacity = 0.85,
  max_cog_size = 2048L,
  first_quantile = 0.02,
  last_quantile = 0.98,
  leaflet_megabytes = 64L,
  add = FALSE
)

\method{sits_view}{class_cube}(
  x,
  ...,
  tiles = x[["tile"]],
  legend = NULL,
  palette = "Set3",
  version = NULL,
  opacity = 0.85,
  max_cog_size = 2048L,
  leaflet_megabytes = 32L,
  add = FALSE
)

\method{sits_view}{probs_cube}(
  x,
  ...,
  tiles = x[["tile"]][[1L]],
  label = x[["labels"]][[1L]][[1L]],
  legend = NULL,
  palette = "YlGn",
  rev = FALSE,
  opacity = 0.85,
  max_cog_size = 2048L,
  first_quantile = 0.02,
  last_quantile = 0.98,
  leaflet_megabytes = 64L,
  add = FALSE
)

\method{sits_view}{vector_cube}(
  x,
  ...,
  tiles = x[["tile"]][[1L]],
  seg_color = "yellow",
  line_width = 0.5,
  add = FALSE
)

\method{sits_view}{class_vector_cube}(
  x,
  ...,
  tiles = x[["tile"]][[1L]],
  seg_color = "yellow",
  line_width = 0.2,
  version = NULL,
  legend = NULL,
  palette = "Set3",
  opacity = 0.85,
  add = FALSE
)

\method{sits_view}{default}(x, ...)
}
\arguments{
\item{x}{Object of class "sits", "data.frame", "som_map",
"raster_cube", "probs_cube", "vector_cube",
or "class cube".}

\item{...}{Further specifications for \link{sits_view}.}

\item{legend}{Named vector that associates labels to colors.}

\item{palette}{Color palette from RColorBrewer}

\item{radius}{Radius of circle markers}

\item{add}{Add image to current leaflet}

\item{id_neurons}{Neurons from the SOM map to be shown.}

\item{band}{Single band for viewing false color images.}

\item{red}{Band for red color.}

\item{green}{Band for green color.}

\item{blue}{Band for blue color.}

\item{tiles}{Tiles to be plotted (in case of a multi-tile cube).}

\item{dates}{Dates to be plotted.}

\item{rev}{Revert color palette?}

\item{opacity}{Opacity of segment fill or class cube}

\item{max_cog_size}{Maximum size of COG overviews (lines or columns)}

\item{first_quantile}{First quantile for stretching images}

\item{last_quantile}{Last quantile for stretching images}

\item{leaflet_megabytes}{Maximum size for leaflet (in MB)}

\item{version}{Version name (to compare different classifications)}

\item{label}{Label to be plotted (in case of probs cube)}

\item{seg_color}{Color for segment boundaries}

\item{line_width}{Line width for segments (in pixels)}
}
\value{
A leaflet object containing either samples or
                      data cubes embedded in a global map that can
                      be visualized directly in an RStudio viewer.
}
\description{
Uses leaflet to visualize time series, raster cube and
classified images.
}
\note{
To show a false color image, use "band" to chose one
of the bands, "tiles" to select tiles,
"first_quantile" and "last_quantile" to set the cutoff points. Choose
only one date in the "dates" parameter. The color
scheme is defined by either "palette" (use an available color scheme) or
legend (user-defined color scheme). To see which palettes are pre-defined,
use \code{cols4all::g4a_gui} or select any ColorBrewer name. The "rev"
parameter reverts the order of colors in the palette.

To show an RGB composite, select "red", "green" and "blue" bands, "tiles",
"dates", "opacity", "first_quantile" and "last_quantile". One can also get
an RGB composite, by selecting one band and three dates. In this case,
the first date will be shown in red, the second in green and third in blue.

Probability cubes are shown in false color. The parameter "labels" controls
which labels are shown. If left blank, only the first map is shown. For
color control, use "palette", "legend", and "rev" (as described above).

Vector cubes have both a vector and a raster component. The vector part
are the segments produced by \code{\link{sits_segment}}. Their
visual output is controlled by "seg_color" and "line_width" parameters.
The raster output works in the same way as the false color and RGB views
described above.

Classified cubes need information on how to render each class. There are
three options: (a) the classes are part of an existing color scheme;
(b) the user provides a legend which associates each class to a color;
(c) use a generic palette (such as "Spectral") and allocate colors
based on this palette. To find out how to create a customized color
scheme, read the chapter "Data Visualisation in sits" in the sits book.

To compare different classifications, use the "version" parameter to
distinguish between the different maps that are shown.

Vector classified cubes are displayed as classified cubes, with the
segments overlaid on top of the class map, controlled by "seg_color"
and "line_width".

Samples are shown on the map based on their geographical locations and
on the color of their classes assigned in their color scheme. Users can
also assign a legend or a palette to choose colors. See information above
on the display of classified cubes.

For all types of data cubes, the following parameters apply:
\itemize{
\item opacity: controls the transparency of the map.
\item max_cog_size: For COG data, controls the level of aggregation
to be used for display, measured in pixels, e.g., a value of 512 will
select a 512 x 512 aggregated image. Small values are faster to
show, at a loss of visual quality.
\item leaflet_megabytes: maximum size of leaflet to be shown associated
to the map (in megabytes). Bigger values use more memory.
\item add: controls whether a new visualisation will be overlaid on
top of an existing one. Default is FALSE.
}
}
\examples{
if (sits_run_examples()) {
    # view samples
    sits_view(cerrado_2classes)
    # create a local data cube
    data_dir <- system.file("extdata/raster/mod13q1", package = "sits")
    modis_cube <- sits_cube(
        source = "BDC",
        collection = "MOD13Q1-6.1",
        data_dir = data_dir
    )
    # view the data cube
    sits_view(modis_cube,
        band = "NDVI"
    )
    # train a model
    rf_model <- sits_train(samples_modis_ndvi, sits_rfor())
    # classify the cube
    modis_probs <- sits_classify(
        data = modis_cube,
        ml_model = rf_model,
        output_dir = tempdir()
    )
    # generate a map
    modis_label <- sits_label_classification(
        modis_probs,
        output_dir = tempdir()
    )
    # view the classified map
    sits_view(modis_label)
    # view the classified map with the B/W image
    sits_view(modis_cube,
        band = "NDVI",
        class_cube = modis_label,
        dates = sits_timeline(modis_cube)[[1]]
    )
    # view the classified map with the RGB image
    sits_view(modis_cube,
        red = "NDVI", green = "NDVI", blue = "NDVI",
        class_cube = modis_label,
        dates = sits_timeline(modis_cube)[[1]]
    )
    # create an uncertainty cube
    modis_uncert <- sits_uncertainty(
        cube = modis_probs,
        output_dir = tempdir()
    )
    # view the uncertainty cube
    sits_view(modis_uncert, rev = TRUE)
}
}
\author{
Gilberto Camara, \email{gilberto.camara@inpe.br}
}
