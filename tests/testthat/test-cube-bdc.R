test_that("Creating cubes from BDC - CBERS-WFI-16D", {
    tiles <- c("007004", "007005")
    start_date <- "2021-09-01"
    end_date <- "2021-09-30"
    bands <- c("NDVI", "EVI", "B13", "B14", "B15", "B16", "CLOUD")
    # create a raster cube
    cbers_cube_16d <- .try(
        {
            sits_cube(
                source = "BDC",
                collection = "CBERS-WFI-16D",
                tiles = tiles,
                start_date = start_date,
                end_date = end_date,
                progress = FALSE
            )
        },
        .default = NULL
    )
    testthat::skip_if(purrr::is_null(cbers_cube_16d),
        message = "BDC is not accessible"
    )
    # test bands and bbox
    expect_true(all(sits_bands(cbers_cube_16d) %in% bands))
    bbox <- sits_bbox(cbers_cube_16d)
    int_bbox <- .bbox_intersection(bbox, .tile_bbox(cbers_cube_16d))
    expect_true(all(int_bbox == sits_bbox(.tile(cbers_cube_16d))))
    # test timeline
    timeline <- sits_timeline(cbers_cube_16d)
    expect_true(timeline[1] <= as.Date(start_date))
    expect_true(timeline[length(timeline)] <= as.Date(end_date))
    # test raster obj
    rast <- .raster_open_rast(cbers_cube_16d$file_info[[1]]$path[1])
    cube_nrows <- .tile_nrows(cbers_cube_16d)
    expect_true(.raster_nrows(rast) == cube_nrows)
})

test_that("Creating cubes from BDC - CBERS-WFI-8D", {
    tiles <- c("007004", "007005")
    start_date <- "2022-05-01"
    end_date <- "2022-08-29"
    bands <- c("NDVI", "EVI", "B13", "B14", "B15", "B16", "CLOUD")
    # create a raster cube file from BDC
    cbers_cube_8d <- .try(
        {
            sits_cube(
                source = "BDC",
                collection = "CBERS-WFI-8D",
                tiles = tiles,
                start_date = start_date,
                end_date = end_date,
                progress = FALSE
            )
        },
        .default = NULL
    )
    testthat::skip_if(purrr::is_null(cbers_cube_8d),
        message = "BDC is not accessible"
    )
    expect_true(all(sits_bands(cbers_cube_8d) %in% bands))
    bbox <- sits_bbox(cbers_cube_8d)
    int_bbox <- .bbox_intersection(bbox, .tile_bbox(cbers_cube_8d))
    expect_true(all(int_bbox == sits_bbox(.tile(cbers_cube_8d))))

    timeline <- sits_timeline(cbers_cube_8d)
    expect_true(timeline[1] <= as.Date(start_date))
    expect_true(timeline[length(timeline)] <= as.Date(end_date))

    rast <- .raster_open_rast(cbers_cube_8d$file_info[[1]]$path[1])
    cube_nrows <- .tile_nrows(cbers_cube_8d)
    expect_true(.raster_nrows(rast) == cube_nrows)
})

test_that("Creating cubes from BDC - MOD13Q1-6.1 based on ROI using sf", {
    shp_file <- system.file(
        "extdata/shapefiles/mato_grosso/mt.shp",
        package = "sits"
    )
    sf_mt <- sf::read_sf(shp_file)
    # create a raster cube file based on the information about the files
    modis_cube <- .try(
        {
            sits_cube(
                source = "BDC",
                collection = "MOD13Q1-6.1",
                bands = c("NDVI", "EVI"),
                roi = sf_mt,
                start_date = "2018-09-01",
                end_date = "2019-08-29",
                progress = FALSE
            )
        },
        .default = NULL
    )
    testthat::skip_if(purrr::is_null(modis_cube),
        message = "BDC is not accessible"
    )
    expect_true(all(sits_bands(modis_cube) %in% c("NDVI", "EVI")))
    bbox <- sits_bbox(modis_cube, as_crs = "EPSG:4326")
    bbox_shp <- sf::st_bbox(sf_mt)
    expect_lt(bbox["xmin"], bbox_shp["xmin"])
    expect_lt(bbox["ymin"], bbox_shp["ymin"])
    expect_gt(bbox["xmax"], bbox_shp["xmax"])
    expect_gt(bbox["ymax"], bbox_shp["ymax"])
    intersects <- .cube_intersects(modis_cube, sf_mt)
    expect_true(all(intersects))
})
test_that("Creating cubes from BDC - MOD13Q1-6.1 invalid roi", {
    expect_error(
        object = sits_cube(
            source = "BDC",
            collection = "MOD13Q1-6.1",
            bands = c("NDVI", "EVI"),
            roi = c(TRUE, FALSE),
            start_date = "2018-09-01",
            end_date = "2019-08-29",
            progress = FALSE
        )
    )
    expect_error(
        object = sits_cube(
            source = "BDC",
            collection = "MOD13Q1-6.1",
            bands = c("NDVI", "EVI"),
            roi = c(
                lon_min = -55.20997,
                lat_min = 15.40554,
                lon_max = -55.19883,
                lat_max = -15.39179
            ),
            tiles = "012010",
            start_date = "2018-09-01",
            end_date = "2019-08-29",
            progress = FALSE
        )
    )
})
test_that("Creating cubes from BDC - LANDSAT per tile", {
    tile <- "006008"
    start_date <- "2021-05-01"
    end_date <- "2021-09-30"
    bands <- c("NDVI", "EVI")
    # create a raster cube file based on the information about the files
    bdc_l8_cube <- .try(
        {
            sits_cube(
                source = "BDC",
                collection = "LANDSAT-OLI-16D",
                bands = bands,
                tiles = tile,
                start_date = start_date,
                end_date = end_date,
                progress = FALSE
            )
        },
        .default = NULL
    )

    testthat::skip_if(purrr::is_null(bdc_l8_cube),
        message = "BDC cube LANDSAT-OLI-16D is not accessible"
    )
    expect_equal(bdc_l8_cube$tile, tile)
    expect_true(all(sits_bands(bdc_l8_cube) %in% bands))
    # test timeline
    timeline <- sits_timeline(bdc_l8_cube)
    expect_true(timeline[1] <= as.Date(start_date))
    expect_true(timeline[length(timeline)] <= as.Date(end_date))
    # test raster obj
    rast <- .raster_open_rast(bdc_l8_cube$file_info[[1]]$path[1])
    cube_nrows <- .tile_nrows(bdc_l8_cube)
    expect_true(.raster_nrows(rast) == cube_nrows)
})

test_that("Creating cubes from BDC - LANDSAT per roi", {
    roi <- c(
        lon_min = -53.9311, lat_min = -13.2697,
        lon_max = -53.0595, lat_max = -12.6704
    )
    start_date <- "2021-05-01"
    end_date <- "2021-09-30"
    bands <- c("NDVI", "EVI")
    # create a raster cube file based on the information about the files
    bdc_l8_cube <- .try(
        {
            sits_cube(
                source = "BDC",
                collection = "LANDSAT-OLI-16D",
                bands = bands,
                roi = roi,
                start_date = start_date,
                end_date = end_date,
                progress = FALSE
            )
        },
        .default = NULL
    )

    testthat::skip_if(purrr::is_null(bdc_l8_cube),
        message = "BDC cube LANDSAT-OLI-16D is not accessible"
    )
    expect_true(all(sits_bands(bdc_l8_cube) %in% bands))
    bbox_cube <- sits_bbox(bdc_l8_cube, as_crs = "EPSG:4326")
    intersects <- .cube_intersects(bdc_l8_cube, roi)
    expect_true(all(intersects))
    # test timeline
    timeline <- sits_timeline(bdc_l8_cube)
    expect_true(timeline[1] <= as.Date(start_date))
    expect_true(timeline[length(timeline)] <= as.Date(end_date))
    # test raster obj
    rast <- .raster_open_rast(bdc_l8_cube$file_info[[1]]$path[1])
    cube_nrows <- .tile_nrows(bdc_l8_cube)
    expect_true(.raster_nrows(rast) == cube_nrows)
})

test_that("Creating cubes from BDC - SENTINEL-2 - roi", {
    roi <- c(
        lon_min = -53.9311, lat_min = -13.2697,
        lon_max = -53.0595, lat_max = -12.6704
    )
    start_date <- "2021-05-01"
    end_date <- "2021-09-30"
    bands <- c("NDVI", "EVI")
    # create a raster cube
    bdc_s2_cube <- .try(
        {
            sits_cube(
                source = "BDC",
                collection = "SENTINEL-2-16D",
                bands = bands,
                roi = roi,
                start_date = start_date,
                end_date = end_date,
                progress = FALSE
            )
        },
        .default = NULL
    )
    testthat::skip_if(purrr::is_null(bdc_s2_cube),
        message = "BDC cube SENTINEL-2-16D is not accessible"
    )
    expect_true(all(sits_bands(bdc_s2_cube) %in% c("NDVI", "EVI")))
    bbox_cube <- sits_bbox(bdc_s2_cube, as_crs = "EPSG:4326")
    intersects <- .cube_intersects(bdc_s2_cube, roi)
    expect_true(all(intersects))
    # test timeline
    timeline <- sits_timeline(bdc_s2_cube)
    expect_true(timeline[1] <= as.Date(start_date))
    expect_true(timeline[length(timeline)] <= as.Date(end_date))
    # test raster obj
    rast <- .raster_open_rast(bdc_s2_cube$file_info[[1]]$path[1])
    cube_nrows <- .tile_nrows(bdc_s2_cube)
    expect_true(.raster_nrows(rast) == cube_nrows)
})

test_that("Creating cubes from BDC - SENTINEL-2 - tile", {
    start_date <- "2021-05-01"
    end_date <- "2021-09-30"
    bands <- c("NDVI", "EVI")
    tiles <- "021019"
    # create a raster cube file
    bdc_s2_cube_t <- .try(
        {
            sits_cube(
                source = "BDC",
                collection = "SENTINEL-2-16D",
                bands = bands,
                tiles = tiles,
                start_date = start_date,
                end_date = end_date,
                progress = FALSE
            )
        },
        .default = NULL
    )

    testthat::skip_if(purrr::is_null(bdc_s2_cube_t),
        message = "BDC cube SENTINEL-2-16D is not accessible"
    )
    expect_true(all(sits_bands(bdc_s2_cube_t) %in% c("NDVI", "EVI")))
    # test timeline
    timeline <- sits_timeline(bdc_s2_cube_t)
    expect_true(timeline[1] <= as.Date(start_date))
    expect_true(timeline[length(timeline)] <= as.Date(end_date))
    # test raster obj
    rast <- .raster_open_rast(bdc_s2_cube_t$file_info[[1]]$path[1])
    cube_nrows <- .tile_nrows(bdc_s2_cube_t)
    expect_true(.raster_nrows(rast) == cube_nrows)
})
test_that("Downloading and cropping cubes from BDC", {
    cbers_cube <- tryCatch(
        {
            sits_cube(
                source = "BDC",
                collection = "CBERS-WFI-16D",
                tiles = c("007004", "007005"),
                bands = c("B15", "CLOUD"),
                start_date = "2018-01-01",
                end_date = "2018-01-12",
                progress = FALSE
            )
        },
        error = function(e) {
            return(NULL)
        }
    )
    testthat::skip_if(
        purrr::is_null(cbers_cube),
        "BDC is not accessible"
    )
    roi_xy <- c(
        xmin = 5800000,
        xmax = 5900000,
        ymin = 9600000,
        ymax = 9700000
    )

    cube_local_roi <- sits_cube_copy(
        cube = cbers_cube,
        output_dir = tempdir(),
        roi = roi_xy,
        multicores = 1,
        progress = FALSE
    )
    # Comparing tiles
    expect_true(nrow(cbers_cube) >= nrow(cube_local_roi))
    bbox_tile <- sits_bbox(cbers_cube)
    bbox_crop <- sits_bbox(cube_local_roi)
    # Comparing bounding boxes
    expect_lt(bbox_tile[["xmin"]], bbox_crop[["xmin"]])
    expect_lt(bbox_tile[["ymin"]], bbox_crop[["ymin"]])
    expect_gt(bbox_tile[["xmax"]], bbox_crop[["xmax"]])
    expect_gt(bbox_tile[["ymax"]], bbox_crop[["ymax"]])
    # Comparing classes
    expect_equal(class(cbers_cube), class(cube_local_roi))
    # Comparing timelines
    expect_equal(sits_timeline(cbers_cube), sits_timeline(cube_local_roi))
    # Comparing X resolution
    expect_equal(
        cbers_cube[["file_info"]][[1]][["xres"]][[1]],
        cube_local_roi[["file_info"]][[1]][["xres"]][[1]]
    )
    # Comparing Y resolution
    expect_equal(
        cbers_cube[["file_info"]][[1]][["yres"]][[1]],
        cube_local_roi[["file_info"]][[1]][["yres"]][[1]]
    )
    files <- cube_local_roi$file_info[[1]]$path
    unlink(files)

    roi_ll <- .roi_as_sf(roi_xy,
        default_crs = cbers_cube$crs[[1]],
        as_crs = 4326
    )

    cube_local_roi_ll <- sits_cube_copy(
        cube = cbers_cube,
        output_dir = tempdir(),
        roi = roi_ll,
        multicores = 1,
        progress = FALSE
    )
    # Comparing tiles
    expect_true(nrow(cbers_cube) >= nrow(cube_local_roi_ll))
    bbox_tile <- sits_bbox(cbers_cube)
    bbox_crop <- sits_bbox(cube_local_roi_ll)
    # Comparing bounding boxes
    expect_lt(bbox_tile[["xmin"]], bbox_crop[["xmin"]])
    expect_lt(bbox_tile[["ymin"]], bbox_crop[["ymin"]])
    expect_gt(bbox_tile[["xmax"]], bbox_crop[["xmax"]])
    expect_gt(bbox_tile[["ymax"]], bbox_crop[["ymax"]])
    # Comparing classes
    expect_equal(class(cbers_cube), class(cube_local_roi_ll))
    # Comparing timelines
    expect_equal(sits_timeline(cbers_cube), sits_timeline(cube_local_roi_ll))
    # Comparing X resolution
    expect_equal(
        cbers_cube[["file_info"]][[1]][["xres"]][[1]],
        cube_local_roi_ll[["file_info"]][[1]][["xres"]][[1]]
    )
    # Comparing Y resolution
    expect_equal(
        cbers_cube[["file_info"]][[1]][["yres"]][[1]],
        cube_local_roi_ll[["file_info"]][[1]][["yres"]][[1]]
    )
    files <- cube_local_roi_ll$file_info[[1]]$path
    unlink(files)

    bbox_ll <- .bbox(roi_ll)

    roi_ll_bbox <- c(
        "lon_min" = bbox_ll[["xmin"]],
        "lon_max" = bbox_ll[["xmax"]],
        "lat_min" = bbox_ll[["ymin"]],
        "lat_max" = bbox_ll[["ymax"]]
    )

    cube_local_roi_tr <- sits_cube_copy(
        cube = cbers_cube,
        output_dir = tempdir(),
        res = 128,
        roi = roi_ll_bbox,
        multicores = 1,
        progress = FALSE
    )

    # Comparing tiles
    expect_true(nrow(cbers_cube) >= nrow(cube_local_roi_tr))
    # Comparing bounding boxes
    bbox_roi_tr <- sits_bbox(cube_local_roi_tr)
    expect_lt(bbox_tile[["xmin"]], bbox_roi_tr[["xmin"]])
    expect_lt(bbox_tile[["ymin"]], bbox_roi_tr[["ymin"]])
    expect_gt(bbox_tile[["xmax"]], bbox_roi_tr[["xmax"]])
    expect_gt(bbox_tile[["ymax"]], bbox_roi_tr[["ymax"]])
    # Comparing classes
    expect_equal(class(cbers_cube), class(cube_local_roi_tr))
    # Comparing timelines
    expect_equal(sits_timeline(cbers_cube), sits_timeline(cube_local_roi_tr))
    # Comparing X resolution
    expect_lt(
        cbers_cube[["file_info"]][[1]][["xres"]][[1]],
        cube_local_roi_tr[["file_info"]][[1]][["xres"]][[1]]
    )
    # Comparing Y resolution
    expect_lt(
        cbers_cube[["file_info"]][[1]][["yres"]][[1]],
        cube_local_roi_tr[["file_info"]][[1]][["yres"]][[1]]
    )
    files <- cube_local_roi_tr$file_info[[1]]$path
    unlink(files)
})
test_that("One-year, multi-core classification in parallel", {
    roi <- c(
        "lon_min" = -65.2313, "lat_min" = -10.5411,
        "lon_max" = -64.6915, "lat_max" = -10.3122
    )
    l8_cube <- tryCatch(
        {
            sits_cube(
                source = "BDC",
                collection = "LANDSAT-OLI-16D",
                roi = roi,
                bands = c("NDVI", "EVI"),
                start_date = "2018-07-12",
                end_date = "2019-07-28",
                progress = FALSE
            )
        },
        error = function(e) {
            return(NULL)
        }
    )

    testthat::skip_if(purrr::is_null(l8_cube),
        message = "BDC is not accessible"
    )

    rfor_model <- sits_train(samples_l8_rondonia_2bands, sits_rfor())

    dir_images <- paste0(tempdir(), "/images/")
    if (!dir.exists(dir_images)) {
        suppressWarnings(dir.create(dir_images))
    }
    unlink(list.files(dir_images,
        pattern = "\\.tif$",
        full.names = TRUE
    ))


    l8_probs <- sits_classify(l8_cube,
        rfor_model,
        roi = roi,
        memsize = 8,
        multicores = 2,
        output_dir = dir_images,
        progress = FALSE
    )
    rast <- .raster_open_rast(.tile_path(l8_probs))

    expect_true(l8_probs[["xmin"]] >= l8_cube[["xmin"]])
    expect_true(l8_probs[["xmax"]] <= l8_cube[["xmax"]])

    expect_true(.raster_nrows(rast) < .tile_nrows(l8_cube))

    expect_equal(.raster_nrows(rast), .tile_nrows(l8_probs))

    max_lyr2 <- max(.raster_get_values(rast)[, 2], na.rm = TRUE)
    expect_true(max_lyr2 <= 10000)

    max_lyr3 <- max(.raster_get_values(rast)[, 3], na.rm = TRUE)
    expect_true(max_lyr3 <= 10000)

    min_lyr3 <- min(.raster_get_values(rast)[, 3], na.rm = TRUE)
    expect_true(min_lyr3 >= 0)

    # Test sits get probs
    probs <- sits_get_probs(
        cube = l8_probs,
        samples = samples_l8_rondonia_2bands
    )
    expect_true(all(names(probs) %in%
                    c("longitude", "latitude", "start_date", "end_date",
                      "label", "cube", "time_series", "X", "Y",
                      "Deforestation","Forest" ,"NatNonForest", "Pasture")))
    expect_equal(nrow(probs), 17)

    samples_sf <- sits_as_sf(samples_l8_rondonia_2bands)
    probs_sf <- sits_get_probs(
        cube = l8_probs,
        samples = samples_sf
    )
    expect_true(all(
        names(probs_sf) %in%
            c("longitude", "latitude", "start_date", "end_date",
              "label", "cube", "time_series", "X", "Y",
              "Deforestation","Forest" ,"NatNonForest", "Pasture")))
    expect_equal(nrow(probs), 17)

    samples_shp <- sf::st_write(samples_sf[, 1:7],
                                file.path(tempdir(), "ro.shp"))
    probs_shp <- sits_get_probs(
        cube = l8_probs,
        samples = samples_shp
    )
    expect_true(all(
        names(probs_shp) %in%
            c("longitude", "latitude", "start_date", "end_date",
              "label", "cube", "time_series", "X", "Y",
              "Deforestation","Forest" ,"NatNonForest", "Pasture")))
    expect_equal(nrow(probs), 17)

    l8_class <- sits_label_classification(l8_probs,
                              memsize = 8,
                              multicores = 2,
                              output_dir = dir_images,
                              progress = FALSE
    )
    class_pts <- sits_get_class(
        cube = l8_class,
        samples = samples_l8_rondonia_2bands
    )
    expect_true(all(
        names(class_pts) %in%
            c("longitude", "latitude", "label")
    ))
    expect_equal(nrow(class_pts), 17)
    class_sf <- sf::st_as_sf(class_pts,
                             coords = c("longitude", "latitude"))
    class_pts_sf <- sits_get_class(
        cube = l8_class,
        samples = class_sf
    )
    expect_true(all(
        names(class_pts_sf) %in%
            c("longitude", "latitude", "label")
    ))
    expect_equal(nrow(class_pts_sf), 17)

    class_shp <- sf::st_write(class_sf,
                              file.path(tempdir(), "ro_class.shp"))
    class_pts_shp <- sits_get_class(
        cube = l8_class,
        samples = class_shp
    )
    expect_true(all(
        names(class_pts_shp) %in%
            c("longitude", "latitude", "label")
    ))
    expect_equal(nrow(class_pts_shp), 17)

    # cleanup
    unlink(l8_class$file_info[[1]]$path)
    unlink(l8_probs$file_info[[1]]$path)

    expect_error(.parallel_reset_node(1))
})
