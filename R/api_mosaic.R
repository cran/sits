.mosaic_split_band_date <- function(cube) {
    UseMethod(".mosaic_split_band_date", cube)
}

#' @export
.mosaic_split_band_date.raster_cube <- function(cube) {
    data <- tidyr::unnest(
        cube,
        cols = "file_info",
        names_sep = "."
    )
    data <- dplyr::mutate(
        data,
        job_date = .data[["file_info.date"]],
        job_band = .data[["file_info.band"]]
    )
    data <- dplyr::group_by(
        data,
        .data[["job_date"]],
        .data[["job_band"]]
    )
    data <- tidyr::nest(
        data,
        file_info = dplyr::starts_with("file_info"),
        .names_sep = "."
    )
    data <- .set_class(data, class(cube))
    data <- tidyr::nest(
        data,
        cube = -c("job_date", "job_band")
    )
    data
}

#' @export
.mosaic_split_band_date.derived_cube <- function(cube) {
    data <- tidyr::unnest(
        cube,
        cols = "file_info",
        names_sep = "."
    )
    data <- dplyr::mutate(
        data,
        job_start_date = .data[["file_info.start_date"]],
        job_end_date = .data[["file_info.end_date"]],
        job_band = .data[["file_info.band"]]
    )
    data <- dplyr::group_by(
        data,
        .data[["job_start_date"]],
        .data[["job_end_date"]],
        .data[["job_band"]]
    )
    data <- tidyr::nest(
        data,
        file_info = dplyr::starts_with("file_info"),
        .names_sep = "."
    )
    data <- .set_class(data, class(cube))
    data <- tidyr::nest(
        data,
        cube = -c("job_start_date", "job_end_date", "job_band")
    )
    data
}

.mosaic_merge_tiles <- function(cube,
                                crs,
                                output_dir,
                                multicores,
                                version,
                                progress) {
    # Create band date as jobs
    band_date_cube <- .mosaic_split_band_date(cube)
    # Process jobs in parallel
    mosaic_cube <- .jobs_map_parallel_dfr(band_date_cube, function(job) {
        cube <- job[["cube"]][[1]]
        # Get cube file paths
        cube_files <- unlist(.cube_paths(cube))
        # Get a template tile
        base_tile <- .tile(cube)
        # Update tile name
        .tile_name(base_tile) <- "MOSAIC"
        out_file <- .file_mosaic_name(
            tile = base_tile,
            band = .tile_bands(base_tile),
            version = version,
            output_dir = output_dir
        )
        # Resume feature
        if (.raster_is_valid(out_file, output_dir = output_dir)) {
            if (.check_messages()) {
                message("Recovery: file '", out_file, "' already exists.")
                message("(If you want to produce a new cropped image, please ",
                        "change 'version' or 'output_dir' parameter)")
            }
            base_tile <- .tile_from_file(
                file = out_file, base_tile = base_tile,
                band = .tile_bands(base_tile), update_bbox = TRUE,
                labels = .tile_labels(base_tile)
            )
            return(base_tile)
        }

        # Generate raster mosaic
        .gdal_warp(
            file = out_file,
            base_files = cube_files,
            params = list(
                "-ot" = .gdal_data_type[["INT1U"]],
                "-of" = .conf("gdal_presets", "image", "of"),
                "-co" = .conf("gdal_presets", "image", "co"),
                "-t_srs" = .as_crs(crs),
                "-wo" = paste0("NUM_THREADS=", multicores),
                "-multi" = TRUE,
                "-srcnodata" = 255
            ),
            quiet = TRUE
        )
        # Create COG overviews
        .gdal_addo(base_file = out_file)
        # Create tile based on template
        base_tile <- .tile_from_file(
            file = out_file, base_tile = base_tile,
            band = .tile_bands(base_tile), update_bbox = TRUE,
            labels = .tile_labels(base_tile)
        )
        # Delete cube files
        unlink(cube_files)
        # Return cube
        return(base_tile)
    }, progress = progress)
    # Join output assets as a cube and return it
    .cube_merge_tiles(mosaic_cube)
}

.mosaic_crop_asset <- function(asset, crs, roi, output_dir, version) {
    # Get asset file path
    file <- .tile_path(asset)
    # Create output file name
    out_file <- .file_crop_name(
        tile = asset, band = .tile_bands(asset),
        version = version, output_dir = output_dir
    )
    # Resume feature
    if (.raster_is_valid(out_file, output_dir = output_dir)) {
        if (.check_messages()) {
            message("Recovery: file '", out_file, "' already exists.")
            message("(If you want to produce a new cropped image, please ",
                    "change 'version' or 'output_dir' parameter)")
        }
        asset <- .tile_from_file(
            file = out_file, base_tile = asset,
            band = .tile_bands(asset), update_bbox = TRUE,
            labels = .tile_labels(asset)
        )
        return(asset)
    }
    # Get band configs from tile
    band_conf <- .tile_band_conf(asset, band = .tile_bands(asset))
    # Scaling image to byte
    .gdal_scale(
        file = file,
        out_file = out_file,
        src_min = .min_value(band_conf),
        src_max = .max_value(band_conf),
        dst_min = 0,
        dst_max = 254,
        miss_value = 255,
        data_type = "INT1U"
    )
    # If the asset is fully contained in roi it's not necessary to crop it
    if (.has(roi)) {
        # Is asset within in roi?
        is_within <- .tile_within(asset, roi)
        if (is_within) {
            # Reproject tile for its crs
            .gdal_reproject_image(
                file = out_file, out_file = out_file,
                crs = .as_crs(.tile_crs(asset)),
                as_crs = .mosaic_crs(tile = asset, as_crs = crs),
                miss_value = 255,
                data_type = "INT1U",
                multicores = 1,
                overwrite = TRUE
            )
            asset <- .tile_from_file(
                file = out_file, base_tile = asset,
                band = .tile_bands(asset), update_bbox = FALSE,
                labels = .tile_labels(asset)
            )
            return(asset)
        }
        # Write roi in a temporary file
        roi <- .roi_write(
            roi = roi,
            output_file = tempfile(fileext = ".shp"),
            quiet = TRUE
        )
    }
    # Crop and reproject tile image
    out_file <- .gdal_crop_image(
        file = out_file,
        out_file = out_file,
        roi_file = roi,
        as_crs = .mosaic_crs(tile = asset, as_crs = crs),
        miss_value = 255,
        data_type = "INT1U",
        multicores = 1,
        overwrite = TRUE
    )
    # Delete temporary roi file
    .mosaic_del_roi(roi)
    # Update asset metadata
    update_bbox <- if (.has(roi)) TRUE else FALSE
    asset <- .tile_from_file(
        file = out_file, base_tile = asset,
        band = .tile_bands(asset), update_bbox = update_bbox,
        labels = .tile_labels(asset)
    )
    return(asset)
}

.mosaic_del_roi <- function(roi) {
    if (is.null(roi)) {
        return(roi)
    }
    dir_name <- dirname(roi)
    file_name <- .file_sans_ext(roi)
    shp_exts <- c(".shp", ".shx", ".dbf", ".prj")
    unlink(paste0(file.path(dir_name, file_name), shp_exts))
}

.mosaic_type <- function(tile) {
    if (.cube_source(tile) %in% "BDC") {
        return("BDC")
    }
    return("RASTER")
}

.mosaic_switch <- function(tile, ...) {
    switch(.mosaic_type(tile), ...)
}

.mosaic_crs <- function(tile, as_crs) {
    .mosaic_switch(
        tile,
        "BDC" = .as_crs("+proj=aea
                        +lat_0=-12 +lon_0=-54 +lat_1=-2 +lat_2=-22
                        +x_0=5000000 +y_0=10000000
                        +ellps=GRS80 +units=m +no_defs "),
        "RASTER" = .as_crs(as_crs)
    )
}