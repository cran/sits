test_that("Segmentation", {
    # Example of classification of a data cube
    # Create a data cube from local files
    set.seed(29031956)
    data_dir <- system.file("extdata/raster/mod13q1", package = "sits")
    cube <- sits_cube(
        source = "BDC",
        collection = "MOD13Q1-6",
        data_dir = data_dir,
        progress = FALSE
    )
    # Segment the cube
    segments <- sits_segment(
        cube = cube,
        output_dir = tempdir(),
        multicores = 6,
        memsize = 24
    )
    expect_s3_class(object = segments, class = "vector_cube")
    expect_true("vector_info" %in% colnames(segments))
    # Read segments as sf object
    vector_segs <- .segments_read_vec(segments)
    expect_equal(
        as.character(unique(sf::st_geometry_type(vector_segs))),
        expected = "POLYGON"
    )
    p1 <- plot(segments)
    expect_equal(p1[[1]]$shp_name, "stars_obj")
    expect_equal(p1$tm_grid$grid.projection, 4326)
    expect_equal(p1$tm_layout$legend.bg.alpha, 0.5)

    # Train a rf model
    rf_model <- sits_train(samples_modis_ndvi, ml_method = sits_rfor)
    # Create a probability vector cube
    probs_segs <- sits_classify(
        data = segments,
        ml_model = rf_model,
        output_dir = tempdir(),
        n_sam_pol = 20,
        multicores = 6,
        memsize = 24
    )
    p2 <- plot(probs_segs)
    expect_equal(p2$tm_shape$shp_name, "sf_seg")
    expect_equal(ncol(p2$tm_shape$shp), 9)
    expect_equal(p2$tm_layout$asp, 0)

    expect_s3_class(object = probs_segs, class = "probs_vector_cube")
    expect_true(
        "vector_info" %in% colnames(probs_segs)
    )
    # Read segments of a probability cube
    vector_probs <- .segments_read_vec(probs_segs)
    expect_true(
        all(sits_labels(probs_segs) %in% colnames(vector_probs))
    )
    # Create a classified vector cube
    class_segs <- sits_label_classification(
        cube = probs_segs,
        output_dir = tempdir(),
        multicores = 2,
        memsize = 4
    )
    expect_s3_class(object = class_segs, class = "class_vector_cube")
    expect_true(
        "vector_info" %in% colnames(class_segs)
    )
    # Read segments of a classified cube
    vector_class <- .segments_read_vec(class_segs)
    expect_true(
        "class" %in% colnames(vector_class)
    )
    p3 <- plot(class_segs)
    expect_equal(p3$tm_shape$shp_name, "sf_seg")
    expect_equal(ncol(p3$tm_shape$shp), 2)
    expect_equal(p2$tm_compass$compass.show.labels, 1)
})
