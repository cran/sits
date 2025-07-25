#' @title Get labels associated to a data set
#' @name sits_labels
#' @author Rolf Simoes, \email{rolfsimoes@@gmail.com}
#' @description  Finds labels in a sits tibble or data cube
#'
#' @param data      Time series (tibble of class "sits"),
#'                  patterns (tibble of class "patterns"),
#'                  data cube (tibble of class "raster_cube"), or
#'                  model (closure of class "sits_model").
#' @return          The labels of the input data (character vector).
#'
#' @examples
#' if (sits_run_examples()) {
#'     # get the labels for a time series set
#'     labels_ts <- sits_labels(samples_modis_ndvi)
#'     # get labels for a set of patterns
#'     labels_pat <- sits_labels(sits_patterns(samples_modis_ndvi))
#'     # create a random forest model
#'     rfor_model <- sits_train(samples_modis_ndvi, sits_rfor())
#'     # get lables for the model
#'     labels_mod <- sits_labels(rfor_model)
#'     # create a data cube from local files
#'     data_dir <- system.file("extdata/raster/mod13q1", package = "sits")
#'     cube <- sits_cube(
#'         source = "BDC",
#'         collection = "MOD13Q1-6.1",
#'         data_dir = data_dir
#'     )
#'     # classify a data cube
#'     probs_cube <- sits_classify(
#'         data = cube, ml_model = rfor_model, output_dir = tempdir()
#'     )
#'     # get the labels for a probs cube
#'     labels_probs <- sits_labels(probs_cube)
#' }
#' @export
#'
sits_labels <- function(data) {
    UseMethod("sits_labels", data)
}
#' @rdname sits_labels
#' @export
#'
sits_labels.sits <- function(data) {
    # pre-condition
    sort(unique(data[["label"]]))
}
#' @rdname sits_labels
#' @export
#'
sits_labels.derived_cube <- function(data) {
    data[["labels"]][[1L]]
}
#' @rdname sits_labels
#' @export
#'
sits_labels.derived_vector_cube <- function(data) {
    data[["labels"]][[1L]]
}
#' @rdname sits_labels
#' @export
#'
sits_labels.raster_cube <- function(data) {
    stop(.conf("messages", "sits_labels_raster_cube"))
}
#' @rdname sits_labels
#' @export
#'
sits_labels.patterns <- function(data) {
    data[["label"]]
}
#' @rdname sits_labels
#' @export
sits_labels.sits_model <- function(data) {
    .check_is_sits_model(data)
    # Get labels from ml_model
    .ml_labels(data)
}
#' @rdname sits_labels
#' @export
sits_labels.default <- function(data) {
    data <- tibble::as_tibble(data)
    if (all(.conf("sits_cube_cols") %in% colnames(data))) {
        data <- .cube_find_class(data)
    } else if (all(.conf("sits_tibble_cols") %in% colnames(data))) {
        class(data) <- c("sits", class(data))
    } else {
        stop(.conf("messages", "sits_labels_raster_cube"))
    }
    sits_labels(data)
}
#' @title Change the labels of a set of time series
#' @name `sits_labels<-`
#' @author Rolf Simoes, \email{rolfsimoes@@gmail.com}
#'
#' @description Given a sits tibble with a set of labels, renames the labels
#' to the specified in value.
#'
#' @param  data      Data cube or time series.
#' @param  value     A character vector used to convert labels. Labels will
#'                   be renamed to the respective value positioned at the
#'                   labels order returned by \code{\link{sits_labels}}.
#'
#' @return           A sits tibble or data cube with modified labels.
#' @examples
#' # show original samples ("Cerrado" and "Pasture")
#' sits_labels(cerrado_2classes)
#' # rename label samples to "Savanna" and "Grasslands"
#' sits_labels(cerrado_2classes) <- c("Savanna", "Grasslands")
#' # see the change
#' sits_labels(cerrado_2classes)
#' @export
`sits_labels<-` <- function(data, value) {
    .check_set_caller("sits_labels_assign")
    # check for NA and NULL
    .check_na_null_parameter(data)
    # get the meta-type (sits or cube)
    UseMethod("sits_labels<-", data)
}
#' @name `sits_labels<-`
#' @export
#'
`sits_labels<-.sits` <- function(data, value) {
    # does the input data exist?
    .check_samples(data)
    labels <- .samples_labels(data)
    # check if value and labels match
    .check_chr_parameter(value,
        len_max = length(labels),
        len_min = length(labels)
    )
    # check if there are no NA
    .check_that(!anyNA(value))
    # check if there are empty strings
    .check_that(any(trimws(value) != ""))
    names(value) <- labels
    data[["label"]] <- value[data[["label"]]]
    data
}
#' @name `sits_labels<-`
#' @return    A probs or class_cube cube with modified labels.
#' @export
`sits_labels<-.probs_cube` <- function(data, value) {
    .check_set_caller("sits_labels_assign_probs_cube")
    # precondition
    .check_chr(value,
        allow_empty = FALSE,
        len_min = length(.cube_labels(data)),
        len_max = length(.cube_labels(data))
    )
    data[["labels"]] <- list(value)
    data
}
#' @name `sits_labels<-`
#' @export
#'
`sits_labels<-.class_cube` <- function(data, value) {
    .check_set_caller("sits_labels_assign_class_cube")
    # precondition
    n_labels_data <- length(.cube_labels(data))
    labels_data <- .cube_labels(data)
    .check_chr(value,
        len_min = n_labels_data
    )
    if (.has_not(names(value))) {
        names(value) <- names(labels_data)
    }
    slider::slide_dfr(data, function(row) {
        row[["labels"]] <- list(value)
        row
    })
}
#' @name `sits_labels<-`
#' @export
`sits_labels<-.default` <- function(data, value) {
    data <- tibble::as_tibble(data)
    if (all(.conf("sits_cube_cols") %in% colnames(data))) {
        data <- .cube_find_class(data)
    } else if (all(.conf("sits_tibble_cols") %in% colnames(data))) {
        class(data) <- c("sits", class(data))
    } else {
        stop(.conf("messages", "sits_labels_raster_cube"))
    }
    sits_labels(data) <- value
    data
}
#' @title Inform label distribution of a set of time series
#' @name sits_labels_summary
#' @author Rolf Simoes, \email{rolfsimoes@@gmail.com}
#' @description  Describes labels in a sits tibble
#'
#' @param data      Data.frame - Valid sits tibble
#'
#' @return A tibble with the frequency of each label.
#'
#' @examples
#' # read a tibble with 400 samples of Cerrado and 346 samples of Pasture
#' data(cerrado_2classes)
#' # print the labels
#' sits_labels_summary(cerrado_2classes)
#' @export
#'
sits_labels_summary <- function(data) {
    UseMethod("sits_labels_summary", data)
}

#' @rdname sits_labels_summary
#' @export
#'
sits_labels_summary.sits <- function(data) {
    warning(.conf("messages", "sits_labels_summary"))

    # get frequency table
    data_labels <- table(data[["label"]])

    # compose tibble containing labels, count and relative frequency columns
    tibble::as_tibble(list(
        label = names(data_labels),
        count = as.integer(data_labels),
        prop = as.numeric(prop.table(data_labels))
    ))
}
