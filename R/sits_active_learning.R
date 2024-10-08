#' @title Suggest samples for enhancing classification accuracy
#'
#' @name sits_uncertainty_sampling
#'
#' @author Alber Sanchez, \email{alber.ipia@@inpe.br}
#' @author Rolf Simoes, \email{rolf.simoes@@inpe.br}
#' @author Felipe Carvalho, \email{felipe.carvalho@@inpe.br}
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description
#' Suggest samples for regions of high uncertainty as predicted by the model.
#' The function selects data points that have confused an algorithm.
#' These points don't have labels and need be manually labelled by experts
#' and then used to increase the classification's training set.
#'
#' This function is best used in the following context:
#'  1. Select an initial set of samples.
#'  2. Train a machine learning model.
#'  3. Build a data cube and classify it using the model.
#'  4. Run a Bayesian smoothing in the resulting probability cube.
#'  5. Create an uncertainty cube.
#'  6. Perform uncertainty sampling.
#'
#' The Bayesian smoothing procedure will reduce the classification outliers
#' and thus increase the likelihood that the resulting pixels with high
#' uncertainty have meaningful information.
#'
#' @param uncert_cube     An uncertainty cube.
#'                        See \code{\link[sits]{sits_uncertainty}}.
#' @param n               Number of suggested points.
#' @param min_uncert      Minimum uncertainty value to select a sample.
#' @param sampling_window Window size for collecting points (in pixels).
#'                        The minimum window size is 10.
#' @param multicores      Number of workers for parallel processing
#'                        (integer, min = 1, max = 2048).
#' @param memsize         Maximum overall memory (in GB) to run the
#'                        function.
#'
#' @return
#' A tibble with longitude and latitude in WGS84 with locations
#' which have high uncertainty and meet the minimum distance
#' criteria.
#'
#'
#' @references
#' Robert Monarch, "Human-in-the-Loop Machine Learning: Active learning
#' and annotation for human-centered AI". Manning Publications, 2021.
#'
#' @examples
#' if (sits_run_examples()) {
#'     # create a data cube
#'     data_dir <- system.file("extdata/raster/mod13q1", package = "sits")
#'     cube <- sits_cube(
#'         source = "BDC",
#'         collection = "MOD13Q1-6.1",
#'         data_dir = data_dir
#'     )
#'     # build a random forest model
#'     rfor_model <- sits_train(samples_modis_ndvi, ml_method = sits_rfor())
#'     # classify the cube
#'     probs_cube <- sits_classify(
#'         data = cube, ml_model = rfor_model, output_dir = tempdir()
#'     )
#'     # create an uncertainty cube
#'     uncert_cube <- sits_uncertainty(probs_cube,
#'         type = "entropy",
#'         output_dir = tempdir()
#'     )
#'     # obtain a new set of samples for active learning
#'     # the samples are located in uncertain places
#'     new_samples <- sits_uncertainty_sampling(
#'         uncert_cube,
#'         n = 10, min_uncert = 0.4
#'     )
#' }
#'
#' @export
#'
sits_uncertainty_sampling <- function(uncert_cube,
                                      n = 100L,
                                      min_uncert = 0.4,
                                      sampling_window = 10L,
                                      multicores = 1L,
                                      memsize = 1L) {
    .check_set_caller("sits_uncertainty_sampling")
    # Pre-conditions
    .check_is_uncert_cube(uncert_cube)
    .check_int_parameter(n, min = 1, max = 10000)
    .check_num_parameter(min_uncert, min = 0.2, max = 1.0)
    .check_int_parameter(sampling_window, min = 10L)
    .check_int_parameter(multicores, min = 1, max = 2048)
    .check_int_parameter(memsize, min = 1, max = 16384)
    # Get block size
    block <- .raster_file_blocksize(.raster_open_rast(.tile_path(uncert_cube)))
    # Overlapping pixels
    overlap <- ceiling(sampling_window / 2) - 1
    # Check minimum memory needed to process one block
    job_memsize <- .jobs_memsize(
        job_size = .block_size(block = block, overlap = overlap),
        npaths = sampling_window,
        nbytes = 8,
        proc_bloat = .conf("processing_bloat_cpu")
    )
    # Update multicores parameter
    multicores <- .jobs_max_multicores(
        job_memsize = job_memsize,
        memsize = memsize,
        multicores = multicores
    )
    # Update block parameter
    block <- .jobs_optimal_block(
        job_memsize = job_memsize,
        block = block,
        image_size = .tile_size(.tile(uncert_cube)),
        memsize = memsize,
        multicores = multicores
    )
    # Prepare parallel processing
    .parallel_start(workers = multicores)
    on.exit(.parallel_stop(), add = TRUE)
    # Slide on cube tiles
    samples_tb <- slider::slide_dfr(uncert_cube, function(tile) {
        # Create chunks as jobs
        chunks <- .tile_chunks_create(
            tile = tile,
            overlap = overlap,
            block = block
        )
        # Tile path
        tile_path <- .tile_path(tile)
        # Get a list of values of high uncertainty
        # Process jobs in parallel
        top_values <- .jobs_map_parallel_dfr(chunks, function(chunk) {
            # Read and preprocess values
            .raster_open_rast(tile_path) |>
            .raster_get_top_values(
                block = .block(chunk),
                band  = 1,
                n     = n,
                sampling_window = sampling_window
            ) |>
            dplyr::mutate(
                value = .data[["value"]] *
                    .conf("probs_cube_scale_factor")
            ) |>
            dplyr::filter(
                .data[["value"]] >= min_uncert
            ) |>
            dplyr::select(dplyr::matches(
                c("longitude", "latitude", "value")
            )) |>
            tibble::as_tibble()
        })
        # All the cube's uncertainty images have the same start & end dates.
        top_values[["start_date"]] <- .tile_start_date(tile)
        top_values[["end_date"]] <- .tile_end_date(tile)
        top_values[["label"]] <- "NoClass"

        return(top_values)
    })

    # Slice result samples
    result_tb <- samples_tb |>
        dplyr::slice_max(
            order_by = .data[["value"]], n = n,
            with_ties = FALSE
        ) |>
        dplyr::transmute(
            longitude = .data[["longitude"]],
            latitude = .data[["latitude"]],
            start_date = .data[["start_date"]],
            end_date = .data[["end_date"]],
            label = .data[["label"]],
            uncertainty = .data[["value"]]
        )

    # Warn if it cannot suggest all required samples
    if (nrow(result_tb) < n) {
        warning(.conf("messages", "sits_uncertainty_sampling_window"),
                call. = FALSE)
    }

    class(result_tb) <- c("sits_uncertainty", "sits", class(result_tb))
    return(result_tb)
}

#' @title Suggest high confidence samples to increase the training set.
#'
#' @name sits_confidence_sampling
#'
#' @author Alber Sanchez, \email{alber.ipia@@inpe.br}
#' @author Rolf Simoes, \email{rolf.simoes@@inpe.br}
#' @author Felipe Carvalho, \email{felipe.carvalho@@inpe.br}
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description
#' Suggest points for increasing the training set. These points are labelled
#' with high confidence so they can be added to the training set.
#' They need to have a satisfactory margin of confidence to be selected.
#' The input is a probability cube. For each label, the algorithm finds out
#' location where the machine learning model has high confidence in choosing
#' this label compared to all others. The algorithm also considers a
#' minimum distance between new labels, to minimize spatial autocorrelation
#' effects.
#' This function is best used in the following context:
#'  1. Select an initial set of samples.
#'  2. Train a machine learning model.
#'  3. Build a data cube and classify it using the model.
#'  4. Run a Bayesian smoothing in the resulting probability cube.
#'  5. Perform confidence sampling.
#'
#' The Bayesian smoothing procedure will reduce the classification outliers
#' and thus increase the likelihood that the resulting pixels with provide
#' good quality samples for each class.
#'
#' @param probs_cube      A smoothed probability cube.
#'                        See \code{\link[sits]{sits_classify}} and
#'                        \code{\link[sits]{sits_smooth}}.
#' @param n               Number of suggested points per class.
#' @param min_margin      Minimum margin of confidence to select a sample
#' @param sampling_window Window size for collecting points (in pixels).
#'                        The minimum window size is 10.
#' @param multicores      Number of workers for parallel processing
#'                        (integer, min = 1, max = 2048).
#' @param memsize         Maximum overall memory (in GB) to run the
#'                        function.
#'
#' @return
#' A tibble with longitude and latitude in WGS84 with locations
#' which have high uncertainty and meet the minimum distance
#' criteria.
#'
#'
#' @examples
#' if (sits_run_examples()) {
#'     # create a data cube
#'     data_dir <- system.file("extdata/raster/mod13q1", package = "sits")
#'     cube <- sits_cube(
#'         source = "BDC",
#'         collection = "MOD13Q1-6.1",
#'         data_dir = data_dir
#'     )
#'     # build a random forest model
#'     rfor_model <- sits_train(samples_modis_ndvi, ml_method = sits_rfor())
#'     # classify the cube
#'     probs_cube <- sits_classify(
#'         data = cube, ml_model = rfor_model, output_dir = tempdir()
#'     )
#'     # obtain a new set of samples for active learning
#'     # the samples are located in uncertain places
#'     new_samples <- sits_confidence_sampling(probs_cube)
#' }
#' @export
sits_confidence_sampling <- function(probs_cube,
                                     n = 20L,
                                     min_margin = 0.90,
                                     sampling_window = 10L,
                                     multicores = 1L,
                                     memsize = 1L) {
    .check_set_caller("sits_confidence_sampling")
    # Pre-conditions
    .check_is_probs_cube(probs_cube)
    .check_int_parameter(n, min = 20)
    .check_num_parameter(min_margin, min = 0.01, max = 1.0)
    .check_int_parameter(sampling_window, min = 10)
    .check_int_parameter(multicores, min = 1, max = 2048)
    .check_int_parameter(memsize, min = 1, max = 16384)
    # Get block size
    block <- .raster_file_blocksize(.raster_open_rast(.tile_path(probs_cube)))
    # Overlapping pixels
    overlap <- ceiling(sampling_window / 2) - 1
    # Check minimum memory needed to process one block
    job_memsize <- .jobs_memsize(
        job_size = .block_size(block = block, overlap = overlap),
        npaths = sampling_window,
        nbytes = 8,
        proc_bloat = .conf("processing_bloat_cpu")
    )
    # Update multicores parameter
    multicores <- .jobs_max_multicores(
        job_memsize = job_memsize,
        memsize = memsize,
        multicores = multicores
    )
    # Update block parameter
    block <- .jobs_optimal_block(
        job_memsize = job_memsize,
        block = block,
        image_size = .tile_size(.tile(probs_cube)),
        memsize = memsize,
        multicores = multicores
    )
    # Prepare parallel processing
    .parallel_start(workers = multicores)
    on.exit(.parallel_stop(), add = TRUE)
    # get labels
    labels <- .cube_labels(probs_cube)
    # Slide on cube tiles
    samples_tb <- slider::slide_dfr(probs_cube, function(tile) {
        # Create chunks as jobs
        chunks <- .tile_chunks_create(
            tile = tile,
            overlap = overlap,
            block = block
        )
        # Tile path
        tile_path <- .tile_path(tile)
        # Get a list of values of high uncertainty
        # Process jobs in parallel
        .jobs_map_parallel_dfr(chunks, function(chunk) {
            # Get samples for each label
            purrr::map2_dfr(labels, seq_along(labels), function(lab, i) {
                # Get a list of values of high confidence & apply threshold
                top_values <- .raster_open_rast(tile_path) |>
                    .raster_get_top_values(
                        block = .block(chunk),
                        band = i,
                        n = n,
                        sampling_window = sampling_window
                    ) |>
                    dplyr::mutate(
                        value = .data[["value"]] *
                            .conf("probs_cube_scale_factor")
                    ) |>
                    dplyr::filter(
                        .data[["value"]] >= min_margin
                    ) |>
                    dplyr::select(dplyr::matches(
                        c("longitude", "latitude", "value")
                    )) |>
                    tibble::as_tibble()

                # All the cube's uncertainty images have the same start &
                # end dates.
                top_values[["start_date"]] <- .tile_start_date(tile)
                top_values[["end_date"]] <- .tile_end_date(tile)
                top_values[["label"]] <- lab

                return(top_values)
            })
        })
    })
    # Slice result samples
    result_tb <- samples_tb |>
        dplyr::group_by(.data[["label"]]) |>
        dplyr::slice_max(
            order_by = .data[["value"]], n = n,
            with_ties = FALSE
        ) |>
        dplyr::ungroup() |>
        dplyr::transmute(
            longitude = .data[["longitude"]],
            latitude = .data[["latitude"]],
            start_date = .data[["start_date"]],
            end_date = .data[["end_date"]],
            label = .data[["label"]],
            confidence = .data[["value"]]
        )

    # Warn if it cannot suggest all required samples
    incomplete_labels <- result_tb |>
        dplyr::count(.data[["label"]]) |>
        dplyr::filter(.data[["n"]] < !!n) |>
        dplyr::pull("label")

    if (length(incomplete_labels) > 0) {
        warning(.conf("messages", "sits_confidence_sampling_window"),
                toString(incomplete_labels),
                call. = FALSE
        )
    }

    class(result_tb) <- c("sits_confidence", "sits", class(result_tb))
    return(result_tb)
}
