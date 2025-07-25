% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_combine_predictions.R
\name{sits_combine_predictions}
\alias{sits_combine_predictions}
\alias{sits_combine_predictions.average}
\alias{sits_combine_predictions.uncertainty}
\alias{sits_combine_predictions.default}
\title{Estimate ensemble prediction based on list of probs cubes}
\usage{
sits_combine_predictions(cubes, type = "average", ...)

\method{sits_combine_predictions}{average}(
  cubes,
  type = "average",
  ...,
  weights = NULL,
  memsize = 8L,
  multicores = 2L,
  output_dir,
  version = "v1",
  progress = FALSE
)

\method{sits_combine_predictions}{uncertainty}(
  cubes,
  type = "uncertainty",
  ...,
  uncert_cubes,
  memsize = 8L,
  multicores = 2L,
  output_dir,
  version = "v1",
  progress = FALSE
)

\method{sits_combine_predictions}{default}(cubes, type, ...)
}
\arguments{
\item{cubes}{List of probability data cubes (class "probs_cube")}

\item{type}{Method to measure uncertainty. One of "average" or
"uncertainty"}

\item{...}{Parameters for specific functions.}

\item{weights}{Weights for averaging (numeric vector).}

\item{memsize}{Memory available for classification in GB
(integer, min = 1, max = 16384).}

\item{multicores}{Number of cores to be used for classification
(integer, min = 1, max = 2048).}

\item{output_dir}{Valid directory for output file.
(character vector of length 1).}

\item{version}{Version of the output
(character vector of length 1).}

\item{progress}{Set progress bar?}

\item{uncert_cubes}{Uncertainty cubes to be used as local weights when
type = "uncertainty" is selected
(list of tibbles with class "uncertainty_cube")}
}
\value{
A combined probability cube (tibble of class "probs_cube").
}
\description{
Calculate an ensemble predictor based a list of probability
cubes. The function combines the output of two or more models
to derive a weighted average.
The supported types of ensemble predictors are 'average' and
'uncertainty'. In the latter case, the uncertainty cubes need to
be provided using param \code{uncert_cubes}.
}
\note{
The distribution of class probabilities produced by machine learning
models such as random forest
is quite different from that produced by deep learning models
such as temporal CNN. Combining the result of two different models
is recommended to remove possible bias induced by a single model.

By default, the function takes the average of the class probabilities
of two or more model results. If desired, users can use the uncertainty
estimates for each results to compute the weights for each pixel.
In this case, the uncertainties produced by the models for each pixel
are used to compute the weights for producing the combined result.
}
\examples{
if (sits_run_examples()) {
    # create a data cube from local files
    data_dir <- system.file("extdata/raster/mod13q1", package = "sits")
    cube <- sits_cube(
        source = "BDC",
        collection = "MOD13Q1-6.1",
        data_dir = data_dir
    )
    # create a random forest model
    rfor_model <- sits_train(samples_modis_ndvi, sits_rfor())
    # classify a data cube using rfor model
    probs_rfor_cube <- sits_classify(
        data = cube, ml_model = rfor_model, output_dir = tempdir(),
        version = "rfor"
    )
    # create an SVM model
    svm_model <- sits_train(samples_modis_ndvi, sits_svm())
    # classify a data cube using SVM model
    probs_svm_cube <- sits_classify(
        data = cube, ml_model = svm_model, output_dir = tempdir(),
        version = "svm"
    )
    # create a list of predictions to be combined
    pred_cubes <- list(probs_rfor_cube, probs_svm_cube)
    # combine predictions
    comb_probs_cube <- sits_combine_predictions(
        pred_cubes,
        output_dir = tempdir()
    )
    # plot the resulting combined prediction cube
    plot(comb_probs_cube)
}
}
\author{
Gilberto Camara, \email{gilberto.camara@inpe.br}

Rolf Simoes, \email{rolfsimoes@gmail.com}
}
