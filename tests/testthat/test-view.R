test_that("View", {
    v1 <- sits_view(cerrado_2classes)
    lf <- sits:::sits_env$leaflet
    expect_equal(lf$overlay_groups, "samples")

    # create a data cube
    data_dir <- system.file("extdata/raster/mod13q1", package = "sits")
    modis_cube <- sits_cube(
        source = "BDC",
        collection = "MOD13Q1-6.1",
        data_dir = data_dir,
        progress = FALSE
    )
    timeline <- sits_timeline(modis_cube)

    # view the data cube
    v2 <- sits_view(modis_cube,
        band = "NDVI",
        dates = timeline[[1]],
        palette = "RdYlGn"
    )
    expect_true("leaflet" %in% class(v2))
    lf <- sits:::sits_env$leaflet
    expect_equal(lf$overlay_groups, "012010 2013-09-14 NDVI")

    # create a probs cube
    rf_model <- sits_train(samples_modis_ndvi, sits_rfor())
    modis_probs <- sits_classify(
        data = modis_cube,
        ml_model = rf_model,
        output_dir = tempdir(),
        memsize = 4,
        multicores = 1,
        progress = FALSE,
        version = "v_2"
    )
    vp <- sits_view(modis_probs)
    expect_true("leaflet" %in% class(vp))
    lf <- sits:::sits_env$leaflet
    expect_equal(lf$overlay_groups, "012010 probs Cerrado")

    # create a class cube
    modis_label <- sits_label_classification(modis_probs,
        output_dir = tempdir(),
        progress = FALSE,
        version = "v2"
    )
    v3 <- sits_view(modis_label)
    expect_true(grepl("EPSG3857", v3$x$options$crs$crsClass))

    # view false color data cube and class cube together
    v4 <- sits_view(modis_cube,
        band = "NDVI",
        class_cube = modis_label,
        dates = timeline[[1]]
    )
    expect_true(grepl("EPSG3857", v4$x$options$crs$crsClass))
    expect_equal(v4$x$calls[[1]]$method, "addProviderTiles")

    # view RGB data cube and class cube together
    v4rgb <- sits_view(modis_cube,
        band = "NDVI",
        dates = timeline[[1]]
    )
    expect_true(grepl("EPSG3857", v4rgb$x$options$crs$crsClass))
    expect_equal(v4rgb$x$calls[[1]]$method, "addProviderTiles")

    # view RGB data cube and class cube together
    v4rgb_class <- sits_view(modis_label, add = TRUE)

    # create uncert cube
    modis_uncert <- sits_uncertainty(
        cube = modis_probs,
        output_dir = tempdir(),
        memsize = 4,
        multicores = 1,
        progress = FALSE
    )
    v5 <- sits_view(modis_uncert)
    expect_true(grepl("EPSG3857", v5$x$options$crs$crsClass))
    expect_equal(v5$x$calls[[1]]$method, "addProviderTiles")
    expect_equal(v5$x$calls[[6]]$args[[2]], "012010 entropy")

    # view uncert cube and class cube
    v6 <- sits_view(modis_label, add = TRUE)
    expect_true(grepl("EPSG3857", v6$x$options$crs$crsClass))
    expect_equal(v6$x$calls[[1]]$method, "addProviderTiles")
    expect_equal(v6$x$calls[[1]]$args[[1]], "Esri.WorldImagery")

    # segmentation
    # segment the image
    segments <- sits_segment(
        cube = modis_cube,
        seg_fn = sits_slic(
            step = 5,
            compactness = 1,
            dist_fun = "euclidean",
            avg_fun = "median",
            iter = 50,
            minarea = 10,
            verbose = FALSE
        ),
        output_dir = tempdir()
    )
    v7 <- sits_view(segments, band = "NDVI")
    expect_true(grepl("EPSG3857", v7$x$options$crs$crsClass))
    expect_equal(v7$x$calls[[1]]$method, "addProviderTiles")
    expect_equal(v7$x$calls[[1]]$args[[1]], "Esri.WorldImagery")
    expect_equal(v7$x$calls[[5]]$method, "addLayersControl")


    probs_segs <- sits_classify(
        data = segments,
        ml_model = rf_model,
        output_dir = tempdir(),
        aggreg_fn = NULL,
        version = "vsegs_test",
        n_sam_pol = 20,
        multicores = 4
    )

    # Create a classified vector cube
    class_segs <- sits_label_classification(
        cube = probs_segs,
        output_dir = tempdir(),
        multicores = 2,
        memsize = 4,
        version = "v_segs_test"
    )

    v9 <- sits_view(class_segs, band = "NDVI")
    expect_true(grepl("EPSG3857", v9$x$options$crs$crsClass))
    expect_identical(v9$x$calls[[1]]$method, "addProviderTiles")
    expect_identical(v9$x$calls[[1]]$args[[1]], "Esri.WorldImagery")
    expect_identical(v9$x$calls[[5]]$method, "addLayersControl")

    expect_true(all(file.remove(unlist(modis_uncert$file_info[[1]][["path"]]))))
    expect_true(all(file.remove(unlist(modis_probs$file_info[[1]][["path"]]))))
    expect_true(all(file.remove(unlist(modis_label$file_info[[1]][["path"]]))))
})

test_that("View class cube from STAC", {
    cube_roi <- c(
        "lon_min" = -62.7, "lon_max" = -62.5,
        "lat_min" = -8.83, "lat_max" = -8.70
    )

    # load cube from stac
    to_class <- sits_cube(
        source     = "TERRASCOPE",
        collection = "WORLD-COVER-2021",
        roi        = cube_roi,
        progress   = FALSE
    )
    testthat::skip_if(purrr::is_null(to_class),
        message = "TERRASCOPE is not accessible"
    )
    v1 <- sits_view(to_class)
    expect_true("leaflet" %in% class(v1))
})

test_that("View BDC cube", {
    cbers_cube <- tryCatch(
        {
            sits_cube(
                source = "BDC",
                collection = "CBERS-WFI-16D",
                bands = c("B13", "B14", "B15", "B16"),
                tiles = c("007004", "007005"),
                start_date = "2018-09-01",
                end_date = "2018-09-28",
                progress = FALSE
            )
        },
        error = function(e) {
            return(NULL)
        }
    )

    testthat::skip_if(purrr::is_null(cbers_cube),
        message = "BDC is not accessible"
    )
    v_cb <- sits_view(cbers_cube)

    expect_identical(v_cb$x$options$crs$crsClass, "L.CRS.EPSG3857")
    expect_identical(v_cb$x$calls[[1]]$args[[1]], "Esri.WorldImagery")
    expect_identical(v_cb$x$calls[[5]]$method, "addLayersControl")
})

test_that("View SOM map", {
    set.seed(2903)
    doc_mode <- Sys.getenv("SITS_DOCUMENTATION_MODE")
    Sys.setenv("SITS_DOCUMENTATION_MODE" = "FALSE")
    expect_warning({
        som_map <- sits_som_map(
            samples_modis_ndvi,
            grid_xdim = 4,
            grid_ydim = 4
        )
    })
    Sys.setenv("SITS_DOCUMENTATION_MODE" = doc_mode)
    v <- sits_view(som_map, id_neurons = 1:5)

    expect_true(grepl("EPSG3857", v[["x"]][["options"]][["crs"]][["crsClass"]]))
    expect_identical(v[["x"]][["calls"]][[1]][["method"]], "addProviderTiles")
})
