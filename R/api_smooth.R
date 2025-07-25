#' @title Smooth a tile
#' @name .smooth_tile
#' @keywords internal
#' @noRd
#' @author Rolf Simoes, \email{rolfsimoes@@gmail.com}
#'
#' @param  tile            Subset of a data cube containing one tile
#' @param  band            Band to be processed
#' @param  block           Individual block that will be processed
#' @param  overlap         Overlap between tiles (if required)
#' @param  smooth_fn       Smoothing function
#' @param  output_dir      Directory where image will be save
#' @param  version         Version of result
#' @param  progress        Check progress bar?
#' @return                 Smoothed tile-band combination
.smooth_tile <- function(tile,
                         band,
                         block,
                         overlap,
                         exclusion_mask,
                         smooth_fn,
                         output_dir,
                         version,
                         progress) {
    # Output file
    out_file <- .file_derived_name(
        tile = tile, band = band, version = version,
        output_dir = output_dir
    )
    # Resume feature
    if (file.exists(out_file)) {
        .check_recovery()
        probs_tile <- .tile_derived_from_file(
            file = out_file,
            band = band,
            base_tile = tile,
            labels = .tile_labels(tile),
            derived_class = "probs_cube",
            update_bbox = FALSE
        )
        return(probs_tile)
    }
    # Create chunks as jobs
    chunks <- .tile_chunks_create(tile = tile, overlap = overlap, block = block)
    # Calculate exclusion mask
    if (.has(exclusion_mask)) {
        # Remove chunks within the exclusion mask
        chunks <- .chunks_filter_mask(
            chunks = chunks,
            mask = exclusion_mask
        )
        exclusion_mask <- .chunks_crop_mask(
            chunks = chunks,
            mask = exclusion_mask
        )
    }
    # Process jobs in parallel
    block_files <- .jobs_map_parallel_chr(chunks, function(chunk) {
        # Job block
        block <- .block(chunk)
        # Block file name
        block_file <- .file_block_name(
            pattern = .file_pattern(out_file),
            block = block,
            output_dir = output_dir
        )
        # Resume processing in case of failure
        if (.raster_is_valid(block_file)) {
            return(block_file)
        }
        # Read and preprocess values
        values <- .tile_read_block(
            tile = tile, band = .tile_bands(tile), block = block
        )
        # Apply the probability function to values
        values <- smooth_fn(values = values, block = block)
        # Prepare probability to be saved
        band_conf <- .conf_derived_band(
            derived_class = "probs_cube", band = band
        )
        offset <- .offset(band_conf)
        if (.has(offset) && offset != 0.0) {
            values <- values - offset
        }
        scale <- .scale(band_conf)
        if (.has(scale) && scale != 1.0) {
            values <- values / scale
        }
        # Job crop block
        crop_block <- .block(.chunks_no_overlap(chunk))
        # Prepare and save results as raster
        .raster_write_block(
            files = block_file, block = block, bbox = .bbox(chunk),
            values = values, data_type = .data_type(band_conf),
            missing_value = .miss_value(band_conf),
            crop_block = crop_block
        )
        # Free memory
        gc()
        # Return block file
        block_file
    }, progress = progress)
    # Check if there is a exclusion_mask
    # If exclusion_mask exists, blocks are merged to a different directory
    # than output_dir, which is used to save the final cropped version
    merge_out_file <- out_file
    if (.has(exclusion_mask)) {
        merge_out_file <- .file_derived_name(
            tile = tile,
            band = band,
            version = version,
            output_dir = file.path(output_dir, ".sits")
        )
    }
    # Merge blocks into a new probs_cube tile
    probs_tile <- .tile_derived_merge_blocks(
        file = merge_out_file,
        band = band,
        labels = .tile_labels(tile),
        base_tile = tile,
        block_files = block_files,
        derived_class = "probs_cube",
        multicores = .jobs_multicores(),
        update_bbox = FALSE
    )
    # Exclude masked areas
    if (.has(exclusion_mask)) {
        # crop
        probs_tile_crop <- .crop(
            cube = probs_tile,
            roi = exclusion_mask,
            output_dir = output_dir,
            multicores = 1L,
            overwrite = TRUE,
            progress = progress
        )

        # delete old files
        unlink(.fi_paths(.fi(probs_tile)))

        # assign new cropped value in the old probs variable
        probs_tile <- probs_tile_crop
    }
    # Return probs tile
    probs_tile
}

#---- Bayesian smoothing ----
#' @title Smooth probability cubes with spatial predictors
#' @noRd
#' @param  cube              Probability data cube.
#' @param  block             Individual block that will be processed
#' @param  window_size       Size of the neighborhood.
#' @param  neigh_fraction    Fraction of neighbors with high probabilities
#'                           to be used in Bayesian inference.
#' @param  smoothness        Estimated variance of logit of class probabilities
#'                           (Bayesian smoothing parameter). It can be either
#'                           a vector or a scalar.
#' @param  multicores        Number of cores to run the smoothing function
#' @param  memsize           Maximum overall memory (in GB) to run the
#'                           smoothing.
#' @param  output_dir        Output directory for image files
#' @param  version           Version of resulting image
#'                           (in the case of multiple tests)
#' @param  progress          Check progress bar?
#' @return                   Smoothed data cube
#'
.smooth <- function(cube,
                    block,
                    window_size,
                    neigh_fraction,
                    smoothness,
                    exclusion_mask,
                    multicores,
                    memsize,
                    output_dir,
                    version,
                    progress) {
    # Smooth parameters checked in smooth function creation
    # Create smooth function
    smooth_fn <- .smooth_fn_bayes(
        window_size = window_size,
        neigh_fraction = neigh_fraction,
        smoothness = smoothness
    )
    # Overlapping pixels
    overlap <- ceiling(window_size / 2L) - 1L
    # Smoothing
    # Process each tile sequentially
    .cube_foreach_tile(cube, function(tile) {
        # Smooth the data
        .smooth_tile(
            tile = tile,
            band = "bayes",
            block = block,
            overlap = overlap,
            exclusion_mask = exclusion_mask,
            smooth_fn = smooth_fn,
            output_dir = output_dir,
            version = version,
            progress = progress
        )
    })
}
#' @title Define smoothing function
#' @noRd
#' @param  window_size       Size of the neighborhood.
#' @param  neigh_fraction    Fraction of neighbors with high probabilities
#'                           to be used in Bayesian inference.
#' @param  smoothness        Estimated variance of logit of class probabilities
#'                           (Bayesian smoothing parameter). It can be either
#'                           a vector or a scalar.
#' @return Function to be applied to smoothen data
.smooth_fn_bayes <- function(window_size,
                             neigh_fraction,
                             smoothness) {
    # Check window size
    .check_int_parameter(window_size, min = 5L, is_odd = TRUE)
    # Check neigh_fraction
    .check_num_parameter(neigh_fraction, exclusive_min = 0.0, max = 1.0)

    # Define smooth function
    smooth_fn <- function(values, block) {
        # Check values length
        input_pixels <- nrow(values)
        # Compute logit
        # adjust values to avoid -Inf or +Inf in logits
        values[values == 1.0] <- 0.999999
        values[values == 0.0] <- 0.000001
        # tranform to logits
        values <- log(values / (rowSums(values) - values))
        # Process Bayesian
        values <- bayes_smoother_fraction(
            logits = values,
            nrows = .nrows(block),
            ncols = .ncols(block),
            window_size = window_size,
            smoothness = smoothness,
            neigh_fraction = neigh_fraction
        )
        # Compute inverse logit
        values <- exp(values) / (exp(values) + 1.0)
        # Are the results consistent with the data input?
        .check_processed_values(values, input_pixels)
        # Return values
        values
    }
    # Return a closure
    smooth_fn
}
