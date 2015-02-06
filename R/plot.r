#' Various DeLorean object plots
#'
#' @param dl de.lorean object
#'
#' @export
#'
plot.de.lorean <- function(dl, type="profiles", ...) {
    result <- switch(type,
        profiles=plot.profiles(dl, ...),
        S.posteriors=plot.S.posteriors(dl, ...),
        pseudotime=plot.pseudotime(dl, ...),
        convergence=plot.convergence(dl, ...)
    )
    if (is.null(result)) {
        stop('Unknown plot type')
    }
    result
}

#' Calculate a suitable value for a rug plot given the
#' number of points
#' @param dl de.lorean object
#'
#' @export
#'
alpha.for.rug <- function(n, scale=100) {
    1 / (max(1, n / scale))
}

#' Plot posterior for marginal log likelihoods of expression profiles
#'
#' @param dl de.lorean object
#'
#' @export
#'
plot.marg.like <- function(dl) {
    with(dl, {
        gp <- (ggplot(samples.l$logmarglike %>% left_join(gene.map),
                      aes(x=gene,
                          y=logmarglike,
                          colour=is.held.out),
                      environment=environment())
            + geom_boxplot()
        )
    })
}

#' Plot pseudotime (tau) against observed capture time
#'
#' @param dl de.lorean object
#'
#' @export
#'
plot.pseudotime <- function(dl) {
    with(dl, {
        gp <- (ggplot(samples.l$tau %>% filter(iter == best.sample),
                      aes(x=tau, y=obstime, color=capture),
                      environment=environment())
            + geom_point()
            + scale_x_continuous(name="Pseudotime (tau)")
            + scale_y_continuous(name="Observed (capture) time")
        )
    })
}

#' Plot the Rhat convergence statistics. examine.convergence must be called
#' before this plot can be made.
#'
#' @param dl de.lorean object
#'
#' @export
#'
plot.convergence <- function(dl) {
    with(dl, {
        rhat.df <- data.frame(
            rhat=rhat.sorted,
            param=names(rhat.sorted),
            parameter=str_match(names(rhat.sorted), "^[[:alpha:]]+"))
        gp <- (ggplot(rhat.df,
                      aes(y=rhat, x=parameter),
                      environment=environment())
            + geom_boxplot()
        )
    })
}

#' Plot posterior for cell sizes
#'
#' @param dl de.lorean object
#'
#' @export
#'
plot.S.posteriors <- function(dl) {
    with(dl, {
        gp <- (ggplot(samples.l$S %>% left_join(cell.map),
                      aes(x=factor(cell,
                                   levels=arrange(cell.map, capture)$cell),
                          y=S,
                          color=capture),
                      environment=environment())
            + geom_boxplot()
        )
    })
}

#' Plot a comparison of the profiles from several de.lorean objects
#'
#' @param ... Named de.lorean objects
#' @param genes Genes to plot (defaults to genes.high.psi of first de.lorean
#'   object)
#' @param sample.iter Which sample to plot
#'
#' @export
#'
plot.cmp.profiles <- function(...,
                              sample.iter = NULL,
                              genes = NULL) {
    if (is.null(sample.iter)) {
        sample.iter <- dl$best.sample
    }
    dls <- list(...)
    dl.levels <- names(dls)
    if (is.null(genes)) {
        genes <- dls[[1]]$genes.high.psi
    }
    stopifnot(! is.null(names(dls)))  # Must have names for de.lorean objects
    get.mean <- function(.name) {
        with(dls[[.name]], (
            predictions
            %>% filter(sample.iter == iter)
            %>% left_join(gene.map)
            %>% filter(gene %in% genes)
            %>% mutate(name=factor(.name, levels=dl.levels))
        ))
    }
    means <- do.call(rbind, lapply(names(dls), get.mean))
    (ggplot(means,
                  aes(x=tau),
                  environment=environment())
        + geom_line(alpha=.8,
                    aes(y=predictedmean + phi,
                        color=name))
        + geom_ribbon(aes(y=predictedmean + phi,
                          ymin=predictedmean+phi-2*sqrt(predictedvar),
                          ymax=predictedmean+phi+2*sqrt(predictedvar),
                          fill=name),
                      alpha=.2)
        + facet_wrap(~ gene)
        + scale_x_continuous(name="Pseudotime",
                             breaks=unique(dls[[1]]$obstime))
        + scale_y_continuous(name="Expression")
    )
}

#' Plot best sample predicted expression
#'
#' @param dl de.lorean object
#' @param genes Genes to plot (defaults to genes.high.psi)
#' @param add.data Add actual expression data to plot
#' @param sample.iter Which sample to plot
#'
#' @export
#'
plot.profiles <- function(dl,
                          genes=NULL,
                          profile.color='black',
                          add.data=T,
                          sample.iter=NULL,
                          ...) {
    if (is.null(genes)) {
        genes <- dl$genes.high.psi
    }
    if (is.null(sample.iter)) {
        sample.iter <- dl$best.sample
    }
    with(dl, {
        if (opts$periodic) {
            modulo.period <- function(t) ( t - floor(t / opts$period)
                                                * opts$period )
        } else {
            modulo.period <- function(t) { t }
        }
        gp <- (ggplot(predictions
                      %>% filter(sample.iter == iter)
                      %>% left_join(gene.map)
                      %>% filter(gene %in% genes),
                      environment=environment()))
        gp <- (
            plot.add.profiles(gp, dl, color=profile.color, genes=genes, ...)
            + facet_wrap(~ gene)
            + scale_x_continuous(name="Pseudotime",
                                 breaks=unique(cell.meta$obstime))
            + scale_y_continuous(name="Expression")
        )
        if (add.data) {
            gp <- plot.add.expr(gp, dl, genes, ...)
        }
        gp
    })
}

#' Add expression profiles to a plot
#'
#' @param gp Plot object
#' @param dl de.lorean object
#' @param genes Genes to plot
#' @param color Color to use
#' @param sample.iter Which sample to plot
#' @param adjust.model A fitted model to adjust expression levels by
#'
#' @export
#'
plot.add.profiles <- function(gp,
                              dl,
                              color='black',
                              genes=NULL,
                              sample.iter=NULL,
                              adjust.model=NULL,
                              ...) {
    if (is.null(genes)) {
        genes <- dl$genes.high.psi
    }
    if (is.null(sample.iter)) {
        sample.iter <- dl$best.sample
    }
    .data <- (
        dl$predictions
        %>% filter(sample.iter == iter)
        %>% left_join(dl$gene.map)
        %>% filter(gene %in% genes)
    )
    if (! is.null(adjust.model)) {
        print(names(.data))
        adjustments <- (
            .data
            %>% group_by(t)
            %>% summarise(tau=tau[1]))
        print(tail(adjustments))
        adjustments$adjustment <- predict(adjust.model,
                                          newdata=adjustments)
        .T <- nrow(adjustments)
        print(adjustments$adjustment[1:(.T-1)]-adjustments$adjustment[2:.T])
        .data <- (
            .data
            %>% left_join(dplyr::select(adjustments, -tau))
            %>% mutate(predictedmean=predictedmean+adjustment))
    }
    (gp
        + geom_line(alpha=.3,
                    color=color,
                    data=.data,
                    aes(x=tau, y=predictedmean + phi))
        + geom_ribbon(aes(x=tau,
                          ymin=predictedmean+phi-2*sqrt(predictedvar),
                          ymax=predictedmean+phi+2*sqrt(predictedvar)),
                      data=.data,
                      fill=color,
                      alpha=.1))
}

#' Add expression data to a plot
#'
#' @param gp Plot object
#' @param dl de.lorean object
#' @param genes Genes to plot
#' @param sample.iter Which sample to plot
#' @param cell.size.adj Adjust expression by posterior estimate of cell size
#'
#' @export
#'
plot.add.expr <- function(gp,
                          dl,
                          genes,
                          sample.iter=NULL,
                          cell.size.adj=T,
                          ...)
{
    if (is.null(sample.iter)) {
        sample.iter <- dl$best.sample
    }
    with(dl, {
        .data <- (
            samples.l$tau
            %>% filter(sample.iter == iter)
            %>% left_join(melt(unname(stan.m),
                          varnames=c("g", "c"),
                          value.name="expr"))
            %>% left_join(gene.map)
            %>% filter(gene %in% genes))
        if (cell.size.adj) {
            .data <- (
                .data
                %>% left_join(samples.l$S)
                %>% mutate(expr=expr - S))
        }
        gp + geom_point(data=.data,
                        aes(x=modulo.period(tau),
                            y=expr,
                            color=capture),
                        size=4,
                        alpha=.7)
    })
}



