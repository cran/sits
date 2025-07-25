#' @title Create statistics for BAYTS algorithm
#' @name .bayts_create_stats
#' @keywords internal
#' @author Felipe Carvalho, \email{felipe.carvalho@@inpe.br}
#' @noRd
#' @param samples     Samples
#' @param stats       Tibble with statistics
#' @returns           A matrix combining new samples with current stats

.bayts_create_stats <- function(samples, stats) {
    if (.has(samples)) {
        bands <- .samples_bands(samples)
        # Create mean and sd columns for each band
        samples <- dplyr::group_by(.ts(samples), .data[["label"]])
        samples <- dplyr::summarise(samples, dplyr::across(
            dplyr::matches(bands), list(mean = mean, sd = stats::sd)
        ))
        # Transform to long form
        names_prefix <- NULL
        if (length(bands) > 1L) {
            names_prefix <- paste(bands, collapse = ",")
        }
        stats <- samples |>
            tidyr::pivot_longer(
                cols = dplyr::ends_with(c("mean", "sd")),
                names_sep = "_",
                names_prefix = names_prefix,
                names_to = c("bands", "stats"),
                cols_vary = "fastest"
            ) |>
            tidyr::pivot_wider(
                names_from = bands
            )
        # To convert split tibbles into matrix
        stats <- lapply(
            split(stats[, bands], stats[["stats"]]), as.matrix
        )
        return(stats)
    }
    .check_null(
        stats,
        msg = paste0(
            "Invalid null parameter.",
            "'stats' must be a valid value."
        )
    )
    bands <- setdiff(colnames(stats), c("stats", "label"))
    # return a matrix with statistics
    lapply(split(stats[, bands], stats[["stats"]]), as.matrix)
}
