#include <Rcpp.h>
#include <stdio.h>
using namespace Rcpp;

// This function calculates the average of probs cubs

// [[Rcpp::export]]

NumericMatrix average_probs(const List& data_lst) {

    int n_classifiers = data_lst.length();
    NumericMatrix mat    = data_lst[0];
    int nrows = mat.nrow();
    int ncols = mat.ncol();

    NumericMatrix new_data(nrows, ncols);

    for (int c = 0; c < n_classifiers; c++){
        NumericMatrix mat1 = data_lst[c];
        for (int i = 0; i < nrows; i++)
            for (int j = 0; j < ncols; j++)
                new_data(i,j) = new_data(i,j) + mat(i,j);
    }
    for (int i = 0; i < nrows; i++)
        for (int j = 0; j < ncols; j++)
            new_data(i,j) = new_data(i,j)/n_classifiers;

    return new_data;
}

// This function calculates the weighted average of probs cubs

// [[Rcpp::export]]

NumericMatrix weighted_probs(const List& data_lst, const NumericVector& weights) {

    int n_classifiers = data_lst.length();
    NumericMatrix mat    = data_lst[0];
    int nrows = mat.nrow();
    int ncols = mat.ncol();

    NumericMatrix new_data(nrows, ncols);

    for (int c = 0; c < n_classifiers; c++){
        NumericMatrix mat1 = data_lst[c];
        for (int i = 0; i < nrows; i++)
            for (int j = 0; j < ncols; j++)
                new_data(i,j) = new_data(i,j) + weights(c)*mat(i,j);
    }

    return new_data;
}

// This function calculates the weighted average of probs cubs
// considering its uncertainty values

// [[Rcpp::export]]

NumericMatrix weighted_uncert_probs(const List& data_lst, const List& unc_lst) {

    int n_classifiers = data_lst.length();
    NumericMatrix mat    = data_lst[0];
    int nrows = mat.nrow();
    int ncols = mat.ncol();

    NumericMatrix new_data(nrows, ncols);
    NumericVector sum_unc(nrows);
    NumericMatrix weights(nrows, n_classifiers);


    for (int c = 0; c < n_classifiers; c++){
        NumericMatrix unc = unc_lst[c];  // uncert for classifier c
        for (int i = 0; i < nrows; i++) {
            sum_unc(i) += 1 - unc(i,0);
        }
    }
    for (int c = 0; c < n_classifiers; c++){
        NumericMatrix unc = unc_lst[c];  // uncert for classifier c
        for (int i = 0; i < nrows; i++) {
            weights(i,c) = (1 - unc(i,0))/sum_unc(i);
        }
    }
    for (int c = 0; c < n_classifiers; c++){
        for (int i = 0; i < nrows; i++)
            for (int j = 0; j < ncols; j++)
                new_data(i,j) = new_data(i,j) + weights(i,c)*mat(i,j);
    }

    return new_data;
}
