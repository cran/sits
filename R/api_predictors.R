# ---- Predictors ----

.pred_cols <- c("sample_id", "label")

#' @title Get predictors from samples
#' @keywords internal
#' @noRd
#' @param  samples  Training samples
#' @param  ml_model ML model (optional)
#' @return          Data.frame with predictors
.predictors <- function(samples, ml_model = NULL) {
    UseMethod(".predictors", samples)
}
#'
#' @export
.predictors.sits <- function(samples, ml_model = NULL) {
    # Prune samples time series
    samples <- .samples_prune(samples)
    # Get samples time series
    pred <- .ts(samples)
    # By default get bands as the same of first sample
    bands <- .samples_bands(samples, include_base = FALSE)
    # Preprocess time series
    if (.has(ml_model)) {
        # If a model is informed, get predictors from model bands
        bands <- intersect(.ml_bands(ml_model), bands)

        # Normalize values for old version model classifiers that
        #   do not normalize values itself
        # Models trained after version 1.2 do this automatically before
        #   classification
        stats <- .ml_stats_0(ml_model) # works for old models only!!
        if (.has(stats)) {
            # Read and preprocess values of each band
            pred[bands] <- purrr::imap_dfc(pred[bands], function(values, band) {
                # Get old stats parameters
                q02 <- .stats_0_q02(stats, band)
                q98 <- .stats_0_q98(stats, band)
                if (.has(q02) && .has(q98)) {
                    # Use C_normalize_data_0 to process old version of
                    #   normalization
                    values <- C_normalize_data_0(
                        data = as.matrix(values), min = q02, max = q98
                    )
                    # Convert from matrix to vector and return
                    unlist(values)
                }
                # Return updated values
                values
            })
        }
    }
    # Create predictors
    pred <- pred[c(.pred_cols, bands)]
    # Add sequence 'index' column grouped by 'sample_id'
    pred <- pred |>
        dplyr::select("sample_id", "label", dplyr::all_of(bands)) |>
        dplyr::group_by(.data[["sample_id"]]) |>
        dplyr::mutate(index = seq_len(dplyr::n())) |>
        dplyr::ungroup()
    # Rearrange data to create predictors
    pred <- tidyr::pivot_wider(
        data = pred, names_from = "index", values_from = dplyr::all_of(bands),
        names_prefix = if (length(bands) == 1) bands else "",
        names_sep = ""
    )
    # Return predictors
    pred
}
#' @export
.predictors.sits_base <- function(samples, ml_model = NULL) {
    # Prune samples time series
    samples <- .samples_prune(samples)
    # Get samples time series
    pred <- .predictors.sits(samples, ml_model)
    # Get predictors for base data
    pred_base <- samples |>
                 dplyr::rename(
                     "_" = "time_series", "time_series" = "base_data"
                 ) |>
                 .predictors.sits() |>
                 dplyr::select(-.data[["label"]])
    # Merge predictors
    pred <- dplyr::inner_join(pred, pred_base, by = "sample_id")
    # Return predictors
    pred
}
#' @title Get predictors names with timeline
#' @keywords internal
#' @noRd
#' @param bands    Character vector with bands of training samples
#' @param timeline Character vector with timeline
#' @return Character vector with predictors name
.pred_features_name <- function(bands, timeline) {
    n <- length(timeline)
    c(vapply(
        X = bands,
        FUN = function(band) paste0(band, seq_len(n)),
        FUN.VALUE = character(n),
        USE.NAMES = FALSE
    ))
}
#' @title Get features from predictors
#' @keywords internal
#' @noRd
#' @param  pred    Predictors
#' @return         Data.frame without first two cols
.pred_features <- function(pred) {
    if (all(.pred_cols %in% names(pred))) {
        pred[, -2:0]
    } else {
        pred
    }
}
#' @title Set features from predictors
#' @keywords internal
#' @noRd
#' @param  pred    Predictors
#' @param  value   Value to be set
#' @return         Data.frame with new value
`.pred_features<-` <- function(pred, value) {
    if (all(.pred_cols %in% names(pred))) {
        pred[, seq_len(ncol(pred) - 2) + 2] <- value
    } else {
        pred[, ] <- value
    }
    pred
}
#' @title Get reference labels from predictors
#' @keywords internal
#' @noRd
#' @param  pred    Predictors
#' @return         Vector with reference labels
.pred_references <- function(pred) {
    if (all(.pred_cols %in% names(pred))) .as_chr(pred[["label"]]) else NULL
}
#' @title Normalize predictors
#' @keywords internal
#' @noRd
#' @param  pred    Predictors
#' @param  stats   Training data statistics
#' @return         Normalized predictors
.pred_normalize <- function(pred, stats) {
    values <- as.matrix(.pred_features(pred))
    values <- C_normalize_data(
        data = values, min = .stats_q02(stats), max = .stats_q98(stats)
    )
    .pred_features(pred) <- values
    # Return predictors
    pred
}
#' @title Create partitions in predictors data.frame
#' @keywords internal
#' @noRd
#' @param  pred           Predictors
#' @param  partititions   Number of partitions
#' @return                Predictors data.frame with partition id
.pred_create_partition <- function(pred, partitions) {
    pred[["part_id"]] <- .partitions(x = seq_len(nrow(pred)), n = partitions)
    tidyr::nest(pred, predictors = -"part_id")
}
#' @title Sample predictors
#' @keywords internal
#' @noRd
#' @param  pred           Predictors
#' @param  frac           Fraction to sample
#' @return                Predictors data.frame sampled
.pred_sample <- function(pred, frac) {
    pred <- dplyr::group_by(pred, .data[["label"]])
    frac <- dplyr::slice_sample(pred, prop = frac) |>
        dplyr::ungroup()
    return(frac)
}
#' @title Convert predictors to ts
#' @keywords internal
#' @noRd
#' @param  data      Predictor data to be converted.
#' @param  bands     Name of the bands available in the given predictor data.
#' @param  timeline  Timeline of the predictor data.
#' @return           Predictor data as ts.
.pred_as_ts <- function(data, bands, timeline) {
    data |>
        dplyr::as_tibble() |>
        tidyr::pivot_longer(
            cols = dplyr::everything(),
            cols_vary = "fastest",
            names_to = ".value",
            names_pattern = paste0(
                "^(", paste(bands, collapse = "|"), ")"
            )
        ) |>
        dplyr::mutate(
            sample_id = rep( seq_len(nrow(data)), each = dplyr::n() / nrow(data) ),
            label = "NoClass",
            Index = rep(timeline, nrow(data)),
            .before = 1
        )
}
# ---- Partitions ----
#' @title Get predictors of a given partition
#' @keywords internal
#' @noRd
#' @param  part           Predictors partition
.pred_part <- function(part) {
    .default(part[["predictors"]][[1]])
}



