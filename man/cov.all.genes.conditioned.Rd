% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/gp.r
\name{cov.all.genes.conditioned}
\alias{cov.all.genes.conditioned}
\title{Calculate covariances for all genes when conditioned on data at
estimated pseudotimes.}
\usage{
cov.all.genes.conditioned(dl, cov.fn = NULL, tau = tau.for.sample(dl))
}
\arguments{
\item{dl}{de.lorean object}

\item{cov.fn}{Covariance function (defaults to cov.matern.32)}

\item{tau}{The pseudotimes to use}
}
\description{
Calculate covariances for all genes when conditioned on data at
estimated pseudotimes.
}
