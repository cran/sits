#' @title File info API
#' @noRd
#' @author Rolf Simoes, \email{rolfsimoes@@gmail.com}
#' @author Felipe Carvalho, \email{felipe.carvalho@@inpe.br}
#' @author Felipe Carlos, \email{efelipecarlos@@gmail.com}
#'
#' @description
#' Set of functions for handling `file_info`.
#'
NULL
#' @title Get `file_info` from a given tile.
#' @noRd
#' @param tile  A tile.
#' @returns A `file_info` tibble.
.fi <- function(tile) {
    fi <- tile[["file_info"]][[1L]]
    fi
}
#' @title Set `file_info` into a given tile.
#' @noRd
#' @param tile  A tile.
#' @param value  A `file_info` to be set.
#' @returns An updated tile tibble.
`.fi<-` <- function(tile, value) {
    tile <- .tile(tile)
    tile[["file_info"]] <- list(value)
    tile
}
#' @title Get the type of the cube from `file_info`
#' @noRd
#' @param fi   file_info
#' @returns Data cube type (eo_cube or derived_cube)
.fi_type <- function(fi) {
    if ("date" %in% names(fi)) {
        "eo_cube"
    } else if (all(c("start_date", "end_date") %in% names(fi))) {
        "derived_cube"
    } else {
        stop(.conf("messages", ".fi_type"))
    }
}
#' @title Switch between `file_info` types
#' @noRd
#' @param fi   file_info
#' @returns Data cube type (eo_cube or derived_cube)
.fi_switch <- function(fi, ...) {
    switch(.fi_type(fi),
        ...
    )
}
#' @title Create a file_info for a new eo_cube
#' @noRd
#' @param fid file_info id
#' @param band band
#' @param date date of the image
#' @param ncols number of cols in the image
#' @param nrows number of rows in the image
#' @param xres  spatial resolution of X dimension
#' @param yres spatial resolution of Y dimension
#' @param xmin smallest X coordinate
#' @param xmax largest X coordinate
#' @param ymin smallest Y coordinate
#' @param ymax largest Y coordinate
#' @param crs  coordinate reference system
#' @param path location of the data
#' @returns  eo_cube tibble
.fi_eo <- function(fid, band, date, ncols, nrows, xres, yres, xmin, xmax,
                   ymin, ymax, crs, path) {
    # Create a new eo file_info
    tibble::tibble(
        fid = fid,
        band = .band_eo(band),
        date = date,
        ncols = ncols,
        nrows = nrows,
        xres = xres,
        yres = yres,
        xmin = xmin,
        xmax = xmax,
        ymin = ymin,
        ymax = ymax,
        crs = crs,
        path = path
    )
}
#' @title Create a new eo_cube file_info from existing files
#' @noRd
#' @param files image files to be included
#' @param fid file_info ids
#' @param bands bands
#' @param date date of the images
.fi_eo_from_files <- function(files, fid, bands, date) {
    # set caller to show in errors
    .check_set_caller(".fi_eo_from_files")
    # precondition
    .check_that(length(files) == length(bands))
    files <- .file_path_expand(files)
    rast <- .raster_open_rast(files)
    .fi_eo(
        fid = fid[[1L]],
        band = bands,
        date = date[[1L]],
        ncols = .raster_ncols(rast),
        nrows = .raster_nrows(rast),
        xres = .raster_xres(rast),
        yres = .raster_yres(rast),
        xmin = .raster_xmin(rast),
        xmax = .raster_xmax(rast),
        ymin = .raster_ymin(rast),
        ymax = .raster_ymax(rast),
        crs = .raster_crs(rast),
        path = files
    )
}
#' @title Create a file_info for a new derived_cube
#' @noRd
#' @param band band
#' @param start_date start date of the image
#' @param end_date end date of the image
#' @param ncols number of cols in the image
#' @param nrows number of rows in the image
#' @param xres  spatial resolution of X dimension
#' @param yres spatial resolution of Y dimension
#' @param xmin smallest X coordinate
#' @param xmax largest X coordinate
#' @param ymin smallest Y coordinate
#' @param ymax largest Y coordinate
#' @param path location of the data
#' @returns  eo_cube tibble
.fi_derived <- function(band, start_date, end_date, ncols, nrows, xres, yres,
                        xmin, xmax, ymin, ymax, path) {
    # Create a new derived file_info
    tibble::tibble(
        band = .band_derived(band),
        start_date = start_date,
        end_date = end_date,
        ncols = ncols,
        nrows = nrows,
        xres = xres,
        yres = yres,
        xmin = xmin,
        xmax = xmax,
        ymin = ymin,
        ymax = ymax,
        path = path
    )
}
#' @title Create a new derived_cube file_info from existing files
#' @noRd
#' @param file image file to be included
#' @param band band
#' @param start_date start date of the image
#' @param end_date end date of the image
.fi_derived_from_file <- function(file, band, start_date, end_date) {
    file <- .file_path_expand(file)
    rast <- .raster_open_rast(file)
    .fi_derived(
        band = band,
        start_date = start_date,
        end_date = end_date,
        ncols = .raster_ncols(rast),
        nrows = .raster_nrows(rast),
        xres = .raster_xres(rast),
        yres = .raster_yres(rast),
        xmin = .raster_xmin(rast),
        xmax = .raster_xmax(rast),
        ymin = .raster_ymin(rast),
        ymax = .raster_ymax(rast),
        path = file
    )
}

#' @title Get file_info id
#' @noRd
#' @param fi   file_info
#' @returns file_info id
.fi_fid <- function(fi) {
    .as_chr(fi[["fid"]])
}
#' @title Get file_info cloud cover values
#' @noRd
#' @param fi   file_info
#' @returns values of cloud cover
.fi_cloud_cover <- function(fi) {
    .as_dbl(fi[["cloud_cover"]])
}
#' @title Get file_info date with least cloud cover
#' @noRd
#' @param fi   file_info
#' @returns  date with smallest values of cloud cover
.fi_date_least_cloud_cover <- function(fi) {
    if ("cloud_cover" %in% colnames(fi)) {
        image <- fi |>
            dplyr::arrange(.data[["cloud_cover"]]) |>
            dplyr::slice(1L)
        as.Date(image[["date"]])
    } else {
        as.Date(.fi_timeline(fi))
    }
}
#' @title Filter file_info for a file_info ID
#' @noRd
#' @param fi   file_info
#' @param fid  file_info ID
#' @returns file_info for the selected fid
.fi_filter_fid <- function(fi, fid) {
    .fi_switch(
        fi = fi,
        eo_cube = {
            fid_in_fi <- fid %in% .fi_fid(fi)
            if (!all(fid_in_fi)) {
                miss_fid <- paste0("'", fid[!fid_in_fi], "'", collapse = ",")
                stop("fid(s) ", miss_fid, " not found")
            }
            fi[.fi_fid(fi) %in% .as_chr(fid), ]
        }
    )
}
#' @title Get file_info bands
#' @noRd
#' @param fi   file_info
#' @returns band values
.fi_bands <- function(fi) {
    .as_chr(fi[["band"]])
}
#' @title Rename tbands of a file_info
#' @noRd
#' @param fi   file_info
#' @param rename  new band names
#' @returns file_info with new band names
.fi_rename_bands <- function(fi, rename) {
    .check_set_caller(".fi_rename_bands")
    .check_chr_within(
        .fi_bands(fi),
        within = names(rename)
    )
    fi[["band"]] <- unname(rename[.fi_bands(fi)])
    fi
}
#' @title Filter file_info for bands
#' @noRd
#' @param fi   file_info
#' @param bands  selected bands
#' @returns file_info filtered for the chosen bands
.fi_filter_bands <- function(fi, bands) {
    bands_in_fi <- bands %in% .fi_bands(fi)
    if (!all(bands_in_fi)) {
        miss_bands <- paste0("'", bands[!bands_in_fi], "'", collapse = ",")
        stop("band(s) ", miss_bands, " not found")
    }
    fi[.fi_bands(fi) %in% bands, ]
}
#' @title Get file_info minimum date
#' @noRd
#' @param fi   file_info
#' @returns first date
.fi_min_date <- function(fi) {
    .fi_switch(
        fi = fi,
        eo_cube = min(.as_date(fi[["date"]])),
        derived_cube = min(.as_date(fi[["start_date"]]))
    )
}
#' @title Get file_info final date
#' @noRd
#' @param fi   file_info
#' @returns final date
.fi_max_date <- function(fi) {
    .fi_switch(
        fi = fi,
        eo_cube = max(.as_date(fi[["date"]])),
        derived_cube = max(.as_date(fi[["end_date"]]))
    )
}
#' @title Get file_info timeline
#' @noRd
#' @param fi   file_info
#' @returns timeline
.fi_timeline <- function(fi) {
    .fi_switch(
        fi = fi,
        eo_cube = sort(.as_date(fi[["date"]])),
        derived_cube = .as_date(c(fi[["start_date"]], fi[["end_date"]]))
    )
}
#' @title Get file_info file paths
#' @noRd
#' @param fi   file_info
#' @returns file paths
.fi_paths <- function(fi) {
    .as_chr(fi[["path"]])
}
#' @title Get first file_info file path
#' @noRd
#' @param fi   file_info
#' @returns first file path
.fi_path <- function(fi) {
    .as_chr(fi[["path"]][[1L]])
}
#' @title Filter file_info for a temporal interval
#' @noRd
#' @param fi   file_info
#' @param start_date start date of the interval
#' @param end_date end date of the interval
#' @returns file_info for the chosen interval
.fi_during <- function(fi, start_date, end_date) {
    fi_tl <- .fi_timeline(fi)
    .fi_switch(
        fi = fi,
        eo_cube = .between(fi_tl, start_date[[1L]], end_date[[1L]]),
        derived_cube = all(.between(fi_tl, start_date[[1L]], end_date[[1L]]))
    )
}
#' @title Filter file_info for a temporal interval
#' @noRd
#' @param fi   file_info
#' @param start_date start date of the interval
#' @param end_date end date of the interval
#' @returns file_info for the chosen interval
.fi_filter_interval <- function(fi, start_date, end_date) {
    if (.has_not(start_date)) {
        start_date <- .fi_min_date(fi)
    }
    if (.has_not(end_date)) {
        end_date <- .fi_max_date(fi)
    }
    dates_in_fi <- .fi_during(
        fi = fi, start_date = start_date, end_date = end_date
    )
    if (!any(dates_in_fi)) {
        stop(
            .conf("messages", ".fi_filter_interval"),
            start_date[[1L]], end_date[[1L]]
        )
    }
    fi[dates_in_fi, ]
}
#' @title Filter file_info for a set of dates
#' @noRd
#' @param fi   file_info
#' @param dates selected dates
#' @returns file_info for the chosen set of dates
.fi_filter_dates <- function(fi, dates) {
    dates <- .as_date(dates)
    dates_in_fi <- dates %in% .fi_timeline(fi)
    if (!all(dates_in_fi)) {
        miss_dates <- paste0("'", dates[!dates_in_fi], "'", collapse = ",")
        stop("date(s) ", miss_dates, " not found")
    }
    fi[.fi_timeline(fi) %in% dates, ]
}
#' @title Read a block based in a file info
#' @noRd
#' @param fi   file_info
#' @param band selected band
#' @param block selected block
#' @returns image values for the selected band and block
.fi_read_block <- function(fi, band, block) {
    band <- band[[1L]]
    # Stops if no band is found
    fi <- .fi_filter_bands(fi = fi, bands = band)
    files <- .fi_paths(fi)
    # Log here
    .debug_log(
        event = "start_block_data_read",
        key = "band",
        value = band
    )
    # Read values from all files in file_info
    values <- .raster_read_rast(files = files, block = block)
    # Log here
    .debug_log(
        event = "end_block_data_read",
        key = "band",
        value = band
    )
    # Return values
    values
}
#' @title Does file_info include cloud band?
#' @noRd
#' @param fi   file_info
#' @returns TRUE/FALSE
.fi_contains_cloud <- function(fi) {
    .band_cloud() %in% .fi_bands(fi)
}
#' @title Is file_info complete?
#' @noRd
#' @param fi   file_info
#' @returns TRUE/FALSE
.fi_is_complete <- function(fi) {
    length(unique(.by(fi, col = "band", .fi_timeline))) <= 1L
}
