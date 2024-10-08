.reg_cube <- function(cube, res, roi, period, output_dir, progress) {
    # Save input cube class
    cube_class <- class(cube)
    # Create assets as jobs
    cube_assets <- .reg_cube_split_assets(cube = cube, period = period)

    # Process each tile sequentially
    cube_assets <- .jobs_map_parallel_dfr(cube_assets, function(asset) {
        .reg_merge_asset(
            asset = asset,
            res = res,
            roi = roi,
            output_dir = output_dir
        )
    }, progress = progress)
    # Check result
    .check_empty_data_frame(cube_assets)
    # Prepare cube output
    cube <- .cube_merge_tiles(cube_assets)
    .set_class(cube, cube_class)
}

#' @title create assets for a data cube by assigning a unique ID using a period
#' @noRd
#' @param  cube  data cube
#' @param  period period
#' @return a data cube with assets of the same period (file ID)
.reg_cube_split_assets <- function(cube, period) {
    # Get timeline for the
    timeline <- .gc_get_valid_timeline(
        cube = cube, period = period, extra_date_step = TRUE
    )
    # Create assets data cube
    .cube_foreach_tile(cube, function(tile) {
        fi <- .fi_filter_interval(
            fi = .fi(tile),
            start_date = timeline[[1]],
            end_date = timeline[[length(timeline)]] - 1
        )
        groups <- cut(
            x = .fi_timeline(fi),
            breaks = timeline,
            labels = FALSE
        )
        fi_groups <- unname(split(fi, groups))
        assets <- .common_size(
            .discard(tile, "file_info"),
            feature = timeline[unique(groups)],
            file_info = fi_groups
        )
        assets <- assets[, c("tile", "feature", "file_info")]
        assets <- tidyr::unnest(assets, "file_info")
        assets[["asset"]] <- assets[["band"]]
        assets <- tidyr::nest(
            assets,
            file_info = -c("tile", "feature", "asset")
        )
        .common_size(
            .discard(tile, "file_info"),
            .discard(assets, "tile")
        )
    })
}
#' @title merges assets of a asset data cube
#' @noRd
#' @param  asset  assets data cube
#' @param  period period
#' @return a data cube with assets of the same period (file ID)
.reg_merge_asset <- function(asset, res, roi, output_dir) {
    # Get band conf missing value
    band_conf <- .tile_band_conf(asset, band = asset[["asset"]])
    # Prepare output file name
    out_file <- .file_eo_name(
        tile = asset,
        band = asset[["asset"]],
        date = asset[["feature"]],
        output_dir = output_dir
    )
    fid_name <- paste(
        asset[["satellite"]], asset[["sensor"]], asset[["feature"]], sep = "_"
    )
    # Resume feature
    if (file.exists(out_file)) {
        .check_recovery(asset[["tile"]])
        asset <- .tile_eo_from_files(
            files = out_file,
            fid = fid_name,
            bands = asset[["asset"]],
            date = asset[["feature"]],
            base_tile = .discard(asset, cols = c("asset", "feature")),
            update_bbox = TRUE
        )
        return(asset)
    }

    # Create template based on tile metadata
    if (.has_not(roi)) {
        roi <- .bbox_as_sf(.tile_bbox(asset))
    }
    roi_bbox <- .bbox(sf::st_intersection(
        x = .roi_as_sf(roi, as_crs = .crs(asset)),
        y = .bbox_as_sf(.bbox(asset))
    ))
    block <- list(ncols = floor((.xmax(roi_bbox) - .xmin(roi_bbox)) / res),
                  nrows = floor((.ymax(roi_bbox) - .ymin(roi_bbox)) / res))
    bbox <- list(xmin = .xmin(roi_bbox),
                 xmax = .xmin(roi_bbox) + .ncols(block) * res,
                 ymin = .ymax(roi_bbox) - .nrows(block) * res,
                 ymax = .ymax(roi_bbox),
                 crs = .crs(roi_bbox))
    out_file <- .gdal_template_block(
        block = block,
        bbox = bbox,
        file = out_file,
        nlayers = 1,
        miss_value = .miss_value(band_conf),
        data_type = .data_type(band_conf)
    )
    # Merge source files into template
    out_file <- .gdal_merge_into(
        file = out_file,
        base_files = .tile_paths(asset, bands = asset[["asset"]]),
        multicores = 2,
        roi = roi
    )
    .tile_eo_from_files(
        files = out_file,
        fid = fid_name,
        bands = asset[["asset"]],
        date = asset[["feature"]],
        base_tile = .discard(asset, cols = c("asset", "feature")),
        update_bbox = TRUE
    )
}
#' @title Convert a SAR cube to MGRS tiling system
#' @name  .reg_s2tile_convert
#' @noRd
#' @description   Produces the metadata description for a data cube
#'                to be produced by converting SAR data to MGRS tiling system
#' @param  cube   SAR data cube
#' @param  roi    Region of interest
#' @param  tiles  List of MGRS tiles
#' @return a data cube of MGRS tiles
.reg_s2tile_convert <- function(cube, roi = NULL, tiles = NULL) {
    UseMethod(".reg_s2tile_convert", cube)
}
#' @noRd
#' @export
#'
.reg_s2tile_convert.grd_cube <- function(cube, roi = NULL, tiles = NULL) {

    # generate Sentinel-2 tiles and intersects it with doi
    tiles_mgrs <- .s2tile_open(roi, tiles)

    # prepare a sf object representing the bbox of each image in file_info
    fi_bbox <- .bbox_as_sf(.bbox(
        x = cube[["file_info"]][[1]],
        default_crs = .crs(cube),
        by_feature = TRUE
    ))

    # create a new cube according to Sentinel-2 MGRS
    cube_class <- .cube_s3class(cube)
    cube <- tiles_mgrs |>
        dplyr::rowwise() |>
        dplyr::group_map(~{
            file_info <- .fi(cube)[.intersects({{fi_bbox}}, .x), ]
            .cube_create(
                source = .tile_source(cube),
                collection = .tile_collection(cube),
                satellite = .tile_satellite(cube),
                sensor = .tile_sensor(cube),
                tile = .x[["tile_id"]],
                xmin = .xmin(.x),
                xmax = .xmax(.x),
                ymin = .ymin(.x),
                ymax = .ymax(.x),
                crs = paste0("EPSG:", .x[["epsg"]]),
                file_info = file_info
            )
        }) |>
        dplyr::bind_rows()

    # Filter non-empty file info
    cube <- .cube_filter_nonempty(cube)

    # Finalize customizing cube class
    cube_class <- c(cube_class[[1]], "sar_cube", cube_class[-1])
    .cube_set_class(cube, cube_class)
}
#' @noRd
#' @export
#'
.reg_s2tile_convert.rtc_cube <- function(cube, roi = NULL, tiles = NULL) {

    # generate Sentinel-2 tiles and intersects it with doi
    tiles_mgrs <- .s2tile_open(roi, tiles)

    # create a new cube according to Sentinel-2 MGRS
    cube_class <- .cube_s3class(cube)

    cube <- tiles_mgrs |>
        dplyr::rowwise() |>
        dplyr::group_map(~{
            # prepare a sf object representing the bbox of each image in file_info
            cube_crs <- dplyr::filter(cube, .data[["crs"]] == .x[["crs"]])
            if (nrow(cube_crs) == 0) {
                cube_crs <- cube
            }
            fi_bbox <- .bbox_as_sf(.bbox(
                x = .fi(cube_crs),
                default_crs = .crs(cube_crs),
                by_feature = TRUE
            ))
            file_info <- .fi(cube_crs)[.intersects({{fi_bbox}}, .x), ]
            .cube_create(
                source = .tile_source(cube_crs),
                collection = .tile_collection(cube_crs),
                satellite = .tile_satellite(cube_crs),
                sensor = .tile_sensor(cube_crs),
                tile = .x[["tile_id"]],
                xmin = .xmin(.x),
                xmax = .xmax(.x),
                ymin = .ymin(.x),
                ymax = .ymax(.x),
                crs = paste0("EPSG:", .x[["epsg"]]),
                file_info = file_info
            )
        }) |>
        dplyr::bind_rows()

    # Filter non-empty file info
    cube <- .cube_filter_nonempty(cube)

    # Finalize customizing cube class
    cube_class <- c(cube_class[[1]], "sar_cube", cube_class[-1])
    .cube_set_class(cube, cube_class)
}
#' @noRd
#' @export
#'
.reg_s2tile_convert.dem_cube<- function(cube, roi = NULL, tiles = NULL) {
    # generate Sentinel-2 tiles and intersects it with doi
    tiles_mgrs <- .s2tile_open(roi, tiles)

    # create a new cube according to Sentinel-2 MGRS
    cube_class <- .cube_s3class(cube)

    cube <- tiles_mgrs |>
        dplyr::rowwise() |>
        dplyr::group_map(~{
            # prepare a sf object representing the bbox of each image in
            # file_info
            cube_crs <- dplyr::filter(cube, .data[["crs"]] == .x[["crs"]])
            if (nrow(cube_crs) == 0) {
                cube_crs <- cube
            }
            fi_bbox <- .bbox_as_sf(.bbox(
                x = .fi(cube_crs),
                default_crs = .crs(cube_crs),
                by_feature = TRUE
            ))
            file_info <- .fi(cube_crs)[.intersects({{fi_bbox}}, .x), ]
            .cube_create(
                source = .tile_source(cube_crs),
                collection = .tile_collection(cube_crs),
                satellite = .tile_satellite(cube_crs),
                sensor = .tile_sensor(cube_crs),
                tile = .x[["tile_id"]],
                xmin = .xmin(.x),
                xmax = .xmax(.x),
                ymin = .ymin(.x),
                ymax = .ymax(.x),
                crs = paste0("EPSG:", .x[["epsg"]]),
                file_info = file_info
            )
        }) |>
        dplyr::bind_rows()

    # Filter non-empty file info
    cube <- .cube_filter_nonempty(cube)

    # Finalize customizing cube class
    cube_class <- c(cube_class[[1]], "dem_cube", cube_class[-1])
    .cube_set_class(cube, cube_class)
}
