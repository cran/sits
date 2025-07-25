#' @title Organize samples into training and test
#' @name .torch_train_test_samples
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#' @keywords internal
#' @noRd
#'
#' @return List with training samples and test samples
#'
.torch_train_test_samples <- function(samples,
                                      samples_validation,
                                      ml_stats,
                                      labels,
                                      code_labels,
                                      timeline,
                                      bands,
                                      validation_split) {
    # Data normalization
    ml_stats <- .samples_stats(samples)
    train_samples <- .predictors(samples)
    train_samples <- .pred_normalize(pred = train_samples, stats = ml_stats)
    # Post condition: is predictor data valid?
    .check_predictors(pred = train_samples, samples = samples)
    # Are there samples for validation?
    if (!is.null(samples_validation)) {
        .check_samples_validation(
            samples_validation = samples_validation, labels = labels,
            timeline = timeline, bands = bands
        )
        # Test samples are extracted from validation data
        test_samples <- .predictors(samples_validation)
        test_samples <- .pred_normalize(
            pred = test_samples, stats = ml_stats
        )
    } else {
        # Split the data into training and validation data sets
        # Create partitions different splits of the input data
        test_samples <- .pred_sample(
            pred = train_samples, frac = validation_split
        )
        # Remove the lines used for validation
        sel <- !train_samples[["sample_id"]] %in%
            test_samples[["sample_id"]]
        train_samples <- train_samples[sel, ]
    }
    # Shuffle the data
    train_samples <- train_samples[sample(
        nrow(train_samples), nrow(train_samples)
    ), ]
    test_samples <- test_samples[sample(
        nrow(test_samples), nrow(test_samples)
    ), ]
    list(
        train_samples = train_samples,
        test_samples = test_samples
    )
}
#' @title Serialize torch model
#' @name .torch_serialize_model
#' @author Rolf Simoes, \email{rolfsimoes@@gmail.com}
#' @keywords internal
#' @noRd
#' @description Serializes a torch model to be used in parallel processing
#' @param model        Torch model
#' @return serialized model
.torch_serialize_model <- function(model) {
    # Open raw connection
    con <- rawConnection(raw(), open = "wr")
    # Close connection on exit
    on.exit(close(con), add = TRUE)
    # Serialize and save torch model on connection
    torch::torch_save(model, con)
    # Read serialized model and return
    rawConnectionValue(con)
}
#' @title Unserialize torch model
#' @name .torch_unserialize_model
#' @author Rolf Simoes, \email{rolfsimoes@@gmail.com}
#' @keywords internal
#' @noRd
#' @description Unserializes a torch model
#' @param raw     Serialized Torch model
#' @return Torch model
.torch_unserialize_model <- function(raw) {
    # Open raw connection to read model
    con <- rawConnection(raw)
    # Close connection on exit
    on.exit(close(con), add = TRUE)
    # Unserialize and load torch model from connection and return
    torch::torch_load(con)
}
#' @title Torch module for Conv1D + Batch Norm + Relu + Dropout
#' @name .torch_conv1D_batch_norm_relu_dropout
#'
#' @author Charlotte Pelletier, \email{charlotte.pelletier@@univ-ubs.fr}
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#' @author Rolf Simoes, \email{rolfsimoes@@gmail.com}
#' @author Felipe Souza, \email{lipecaso@@gmail.com}
#' @keywords internal
#' @noRd
#' @description Defines a torch conv1d module composed of:
#' (a) 1d convolution; (b) batch normalization;
#' (c) relu activation; (d) dropout;
#'
#' @param input_dim         Input dimension of neural net.
#' @param output_dim        Output dimension of neural net.
#' @param kernel_size       Size of 1D convolutional kernel.
#' @param padding           Padding added to both sides of the input.
#' @param dropout_rate      Dropout rate for linear module.
#'
#' @return A conv1D tensor block.
#'
# module for 1D convolution with batch normalization and dropout
.torch_conv1D_batch_norm_relu_dropout <- torch::nn_module(
    classname = "conv1D_batch_norm_relu_dropout",
    initialize = function(input_dim,
                          output_dim,
                          kernel_size,
                          padding,
                          dropout_rate) {
        self$block <- torch::nn_sequential(
            torch::nn_conv1d(
                in_channels = input_dim,
                out_channels = output_dim,
                kernel_size = kernel_size,
                padding = padding
            ),
            torch::nn_batch_norm1d(num_features = output_dim),
            torch::nn_relu(),
            torch::nn_dropout(p = dropout_rate)
        )
    },
    forward = function(x) {
        self$block(x)
    }
)

#' @title Torch module for Conv1D + Batch Norm + Relu
#' @name .torch_conv1D_batch_norm_relu
#'
#' @author Charlotte Pelletier, \email{charlotte.pelletier@@univ-ubs.fr}
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#' @author Rolf Simoes, \email{rolfsimoes@@gmail.com}
#' @author Felipe Souza, \email{lipecaso@@gmail.com}
#' @keywords internal
#' @noRd
#' @description Defines a torch conv1d module composed of:
#' (a) 1d convolution; (b) batch normalization;
#' (c) relu activation
#'
#' @param input_dim         Input dimension of neural net.
#' @param output_dim        Output dimension of neural net.
#' @param kernel_size       Size of 1D convolutional kernel.
#' @param padding           Padding added to both sides of the input.
#'
#' @return A conv1D tensor block.
#'
# module for 1D convolution with batch normalization and dropout
.torch_conv1D_batch_norm_relu <- torch::nn_module(
    classname = "conv1D_batch_norm_relu",
    initialize = function(input_dim,
                          output_dim,
                          kernel_size,
                          padding = 0L) {
        self$block <- torch::nn_sequential(
            torch::nn_conv1d(
                in_channels = input_dim,
                out_channels = output_dim,
                kernel_size = kernel_size,
                padding = padding
            ),
            torch::nn_batch_norm1d(num_features = output_dim),
            torch::nn_relu()
        )
    },
    forward = function(x) {
        self$block(x)
    }
)

#' @title Torch module for BatchNorm + Conv1D + Batch Norm + Relu
#' @name .torch_batch_conv1D_batch_norm_relu
#'
#' @author Charlotte Pelletier, \email{charlotte.pelletier@@univ-ubs.fr}
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#' @author Rolf Simoes, \email{rolfsimoes@@gmail.com}
#' @author Felipe Souza, \email{lipecaso@@gmail.com}
#' @keywords internal
#' @noRd
#' @description Defines a torch conv1d module composed of:
#' (a) 1d convolution; (b) batch normalization;
#' (c) relu activation
#'
#' @param input_dim         Input dimension of neural net.
#' @param output_dim        Output dimension of neural net.
#' @param kernel_size       Size of 1D convolutional kernel.
#' @param padding           Padding added to both sides of the input.
#'
#' @return A conv1D tensor block.
#'
# module for 1D convolution with batch normalization and dropout
.torch_batch_conv1D_batch_norm_relu <- torch::nn_module(
    classname = "conv1D_batch_norm_relu",
    initialize = function(input_dim,
                          output_dim,
                          kernel_size,
                          padding = 0L) {
        self$block <- torch::nn_sequential(
            torch::nn_batch_norm1d(num_features = input_dim),
            torch::nn_conv1d(
                in_channels = input_dim,
                out_channels = output_dim,
                kernel_size = kernel_size,
                padding = padding
            ),
            torch::nn_batch_norm1d(num_features = output_dim),
            torch::nn_relu()
        )
    },
    forward = function(x) {
        self$block(x)
    }
)
#' @title Torch module for Conv1D + Batch Norm
#' @name .torch_conv1D_batch_norm
#'
#' @author Charlotte Pelletier, \email{charlotte.pelletier@@univ-ubs.fr}
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#' @author Rolf Simoes, \email{rolfsimoes@@gmail.com}
#' @author Felipe Souza, \email{lipecaso@@gmail.com}
#' @keywords internal
#' @noRd
#' @description Defines a torch conv1d module composed of:
#' (a) 1d convolution; (b) batch normalization.
#'
#' @param input_dim         Input dimension of neural net.
#' @param output_dim        Output dimension of neural net.
#' @param kernel_size       Size of 1D convolutional kernel.
#' @param padding           Padding added to both sides of the input.
#'
#' @return A conv1D tensor block.
#'
# module for 1D convolution with batch normalization and dropout
.torch_conv1D_batch_norm <- torch::nn_module(
    classname = "conv1D_batch_norm",
    initialize = function(input_dim,
                          output_dim,
                          kernel_size,
                          padding = 0L) {
        self$block <- torch::nn_sequential(
            torch::nn_conv1d(
                in_channels = input_dim,
                out_channels = output_dim,
                kernel_size = kernel_size,
                padding = padding
            ),
            torch::nn_batch_norm1d(num_features = output_dim)
        )
    },
    forward = function(x) {
        self$block(x)
    }
)

#' @title Torch module for linear MLP
#' @name .torch_linear_batch_norm_relu_dropout
#'
#' @author Charlotte Pelletier, \email{charlotte.pelletier@@univ-ubs.fr}
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#' @author Rolf Simoes, \email{rolfsimoes@@gmail.com}
#' @author Felipe Souza, \email{lipecaso@@gmail.com}
#' @keywords internal
#' @noRd
#' @description Defines a torch module composed of; (a) linear transformation;
#' (b) batch normalization; (c) relu activation; (d) dropout
#'
#' @param input_dim         Input dimension of neural net.
#' @param output_dim        Output dimension of neural net.
#' @param dropout_rate      Dropout rate for linear module.
#'
#' @return A linear tensor block.
#'

# module for linear transformation with batch normalization and dropout
.torch_linear_batch_norm_relu_dropout <- torch::nn_module(
    classname = "torch_linear_batch_norm_relu_dropout",
    initialize = function(input_dim,
                          output_dim,
                          dropout_rate) {
        self$block <- torch::nn_sequential(
            torch::nn_linear(
                in_features = input_dim,
                out_features = output_dim
            ),
            torch::nn_batch_norm1d(
                num_features = output_dim
            ),
            torch::nn_relu(),
            torch::nn_dropout(
                p = dropout_rate
            )
        )
    },
    forward = function(x) {
        self$block(x)
    }
)
#' @title Torch module for linear transformation with relu activation and
#' dropout
#' @name .torch_linear_relu_dropout
#'
#' @author Charlotte Pelletier, \email{charlotte.pelletier@@univ-ubs.fr}
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#' @author Rolf Simoes, \email{rolfsimoes@@gmail.com}
#' @author Felipe Souza, \email{lipecaso@@gmail.com}
#' @keywords internal
#' @noRd
#' @description Defines a torch module composed of; (a) linear transformation;
#' (b) relu activation; (c) dropout
#'
#' @param input_dim         Input dimension of neural net.
#' @param output_dim        Output dimension of neural net.
#' @param dropout_rate      Dropout rate for linear module.
#'
#' @return A linear tensor block.
#'
#
.torch_linear_relu_dropout <- torch::nn_module(
    classname = "torch_linear_batch_norm_relu_dropout",
    initialize = function(input_dim,
                          output_dim,
                          dropout_rate) {
        self$block <- torch::nn_sequential(
            torch::nn_linear(input_dim, output_dim),
            torch::nn_relu(),
            torch::nn_dropout(dropout_rate)
        )
    },
    forward = function(x) {
        self$block(x)
    }
)
#' @title Torch module for linear MLP
#' @name .torch_linear_batch_norm_relu
#'
#' @author Charlotte Pelletier, \email{charlotte.pelletier@@univ-ubs.fr}
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#' @author Rolf Simoes, \email{rolfsimoes@@gmail.com}
#' @author Felipe Souza, \email{lipecaso@@gmail.com}
#' @keywords internal
#' @noRd
#' @description Defines a torch module composed of; (a) linear transformation;
#' (b) batch normalization; (c) relu activation
#'
#' @param input_dim         Input dimension of neural net.
#' @param output_dim        Output dimension of neural net.
#'
#' @return A linear tensor block.
#'

# module for linear transformation with batch normalization and relu activation
.torch_linear_batch_norm_relu <- torch::nn_module(
    classname = "torch_linear_batch_norm_relu_dropout",
    initialize = function(input_dim,
                          output_dim) {
        self$block <- torch::nn_sequential(
            torch::nn_linear(
                in_features = input_dim,
                out_features = output_dim
            ),
            torch::nn_batch_norm1d(
                num_features = output_dim
            ),
            torch::nn_relu()
        )
    },
    forward = function(x) {
        self$block(x)
    }
)
#' @title Torch module for linear MLP
#' @name .torch_multi_linear_batch_norm_relu
#'
#' @author Charlotte Pelletier, \email{charlotte.pelletier@@univ-ubs.fr}
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#' @author Rolf Simoes, \email{rolfsimoes@@gmail.com}
#' @author Felipe Souza, \email{lipecaso@@gmail.com}
#' @keywords internal
#' @noRd
#' @description Defines a set of torch modules composed of:
#' (a) linear transformation; (b) batch normalization; (c) relu activation
#'
#' @param input_dim         Input dimension of neural net.
#' @param hidden_dims       Hidden dimensions of neural net.
#'
#' @return A linear tensor block.
#'
.torch_multi_linear_batch_norm_relu <- torch::nn_module(
    classname = "torch_multi_linear_batch_norm_relu",
    initialize = function(input_dim, hidden_dims) {
        tensors <- list()
        # input layer
        tensors[[1L]] <- .torch_linear_batch_norm_relu(
            input_dim = input_dim,
            output_dim = hidden_dims[[1L]]
        )
        # if hidden layers is a vector then we add those layers
        if (length(hidden_dims) > 1L) {
            for (i in 2L:length(hidden_dims)) {
                tensors[[length(tensors) + 1L]] <-
                    .torch_linear_batch_norm_relu(
                        input_dim  = hidden_dims[[i - 1L]],
                        output_dim = hidden_dims[[i]]
                    )
            }
        }
        # create a sequential module that calls the layers in the same order.
        self$model <- torch::nn_sequential(!!!tensors)
    },
    forward = function(x) {
        self$model(x)
    }
)
#' @title Verify if GPU classification is available
#' @name .torch_gpu_classification
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#' @keywords internal
#' @noRd
#' @description Find out if CUDA or MPS are available
#'
#' @return TRUE/FALSE
#'
.torch_gpu_classification <- function() {
    torch::cuda_is_available() || torch::backends_mps_is_available()
}

#' @title Verify if CUDA is available
#' @name .torch_cuda_enabled
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#' @keywords internal
#' @noRd
#' @description Find out if CUDA is enabled
#'
#' @param ml_model   ML model
#'
#' @return TRUE/FALSE
#'
.torch_cuda_enabled <- function() {
    torch::cuda_is_available()
}
#' @title Use GPU or CPU training?
#' @name .torch_cpu_train
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#' @keywords internal
#' @noRd
#' @description Use CPU or GPU for torch models depending on
#' availability. Do not use GPU for training in Apple MPS
#' because of bug in the "luz" package
#'
#' @return TRUE/FALSE
#'
.torch_cpu_train <- function() {
    !(torch::cuda_is_available()) &&
        !(torch::backends_mps_is_available())
}
#' @title Transform matrix to torch dataset
#' @name .torch_as_dataset
#' @keywords internal
#' @noRd
#' @description Transform input data to a torch dataset
#' @param x     Input matrix
#'
#' @return A torch dataset
#'
.torch_as_dataset <- torch::dataset(
    "dataset",
    initialize = function(x) {
        self$x <- x
        self$dim <- dim(x)
    },
    .getitem = function(i) {
        if (length(self$dim) == 3L) {
            item_data <- self$x[i, , , drop = FALSE]
        } else {
            item_data <- self$x[i, , drop = FALSE]
        }

        list(torch::torch_tensor(
            array(item_data, dim = c(
                nrow(item_data), self$dim[2L:length(self$dim)]
            ))
        ))
    },
    .getbatch = function(i) {
        self$.getitem(i)
    },
    .length = function() {
        dim(self$x)[[1L]]
    }
)
