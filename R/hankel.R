#   R package for Singular Spectrum Analysis
#   Copyright (c) 2009 Anton Korobeynikov <asl@math.spbu.ru>
#
#   This program is free software; you can redistribute it
#   and/or modify it under the terms of the GNU General Public
#   License as published by the Free Software Foundation;
#   either version 2 of the License, or (at your option)
#   any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the
#   Free Software Foundation, Inc., 675 Mass Ave, Cambridge,
#   MA 02139, USA.

#   Routines for normal hankel SSA

tcirc.old <- function(F, L = (N - 1) %/% 2) {
  N <- length(F); K = N - L + 1
  .res <- list()
  .res$C <- as.vector(fft(c(F[K:N], F[1:(K-1)])))
  .res$L <- L
  return (.res)
}

hmatmul.old <- function(C, v) {
  v <- as.vector(fft(C$C * fft(c(rev(v), rep(0, C$L-1))), inverse = TRUE))
  Re((v/length(C$C))[1:C$L])
}

hankel <- function(X, L) {
  if (is.matrix(X) && nargs() == 1) {
     L <- nrow(X); K <- ncol(X); N <- K + L - 1
     left  <- c(1:L, L*(2:K))
     right <- c(1+L*(0:(K-1)), ((K-1)*L+2):(K*L))
     v <- sapply(1:N, function(i) mean(X[seq.int(left[i], right[i], by = L-1)]))
     return (v)
  }

  # Coerce output to vector, if necessary
  if (!is.vector(X))
    X <- as.vector(X)
  N <- length(X)
  if (missing(L))
    L <- (N - 1) %/% 2
  K <- N - L + 1
  outer(1:L, 1:K, function(x,y) X[x+y-1])
}

.get.or.create.fft.plan <- function(x) {
  .get.or.create(x, "fft.plan", fft.plan.1d(x$length))
}

.get.or.create.hmat <- function(x) {
  .get.or.create(x, "hmat",
                 new.hmat(x$F, L = x$window,
                          fft.plan = .get.or.create.fft.plan(x)))
}

.hankelize.one.1d.ssa <- function(x, U, V) {
  fft.plan <- .get.or.create.fft.plan(x)
  storage.mode(U) <- storage.mode(V) <- "double"
  .Call("hankelize_one_fft", U, V, fft.plan)
}

.hankelize.multi <- function(U, V) {
  storage.mode(U) <- storage.mode(V) <- "double"
  .Call("hankelize_multi", U, V)
}

.hankelize.multi.hankel <- function(U, V, fft.plan) {
  storage.mode(U) <- storage.mode(V) <- "double"
  .Call("hankelize_multi_fft", U, V, fft.plan)
}

fft.plan.1d <- function(N) {
  storage.mode(N) <- "integer"
  .Call("initialize_fft_plan", N)
}

is.fft.plan <- function(fft.plan) {
  .Call("is_fft_plan", fft.plan)
}

new.hmat <- function(F,
                     L = (N - 1) %/% 2,
                     fft.plan = NULL) {
  N <- length(F)
  storage.mode(F) <- "double"
  storage.mode(L) <- "integer"
  h <- .Call("initialize_hmat", F, L, if (is.null(fft.plan)) fft.plan.1d(N) else fft.plan)
}

hcols <- function(h) {
  .Call("hankel_cols", h)
}

hrows <- function(h) {
  .Call("hankel_rows", h)
}

is.hmat <- function(h) {
  .Call("is_hmat", h)
}

hmatmul <- function(hmat, v, transposed = FALSE) {
  storage.mode(v) <- "double";
  storage.mode(transposed) <- "logical";
  .Call("hmatmul", hmat, v, transposed);
}

.init.1d.ssa <- function(x, ...) {
  # Initialize FFT plan
  .get.or.create.fft.plan(x)

  x
}

decompose.1d.ssa <- function(x,
                             neig = min(50, L, K),
                             ...,
                             force.continue = FALSE) {
  N <- x$length; L <- x$window; K <- N - L + 1
  stop("Unsupported SVD method for 1D SSA!")
}

decompose.1d.ssa.svd <- function(x,
                                 neig = min(L, K),
                                 ...,
                                 force.continue = FALSE) {
  N <- x$length; L <- x$window; K <- N - L + 1

  # Check, whether continuation of decomposition is requested
  if (!force.continue && nlambda(x) > 0)
    stop("Continuation of decomposition is not supported for this method.")

  # Build hankel matrix
  F <- .get(x, "F")
  h <- hankel(F, L = L)

  # Do decomposition
  S <- svd(h, nu = neig, nv = neig)

  # Save results
  .set(x, "lambda", S$d)
  if (!is.null(S$u))
    .set(x, "U", S$u)
  if (!is.null(S$v))
    .set(x, "V", S$v)

  x
}

Lcov.matrix <- function(F,
                        L = (N - 1) %/% 2,
                        fft.plan = NULL) {
  N <- length(F)
  storage.mode(F) <- "double"
  storage.mode(L) <- "integer"
  .Call("Lcov_matrix", F, L, if (is.null(fft.plan)) fft.plan.1d(N) else fft.plan)
}

decompose.1d.ssa.eigen <- function(x, ...,
                                   force.continue = FALSE) {
  N <- x$length; L <- x$window; K <- N - L + 1

  # Check, whether continuation of decomposition is requested
  if (!force.continue && nlambda(x) > 0)
    stop("Continuation of decomposition is not supported for this method.")

  # Build hankel matrix
  F <- .get(x, "F")
  fft.plan <- .get.or.create.fft.plan(x)

  # Do decomposition
  S <- eigen(Lcov.matrix(F, L = L, fft.plan = fft.plan), symmetric = TRUE)

  # Fix small negative values
  S$values[S$values < 0] <- 0

  # Save results
  .set(x, "lambda", sqrt(S$values))
  .set(x, "U", S$vectors)

  x
}

decompose.1d.ssa.propack <- function(x,
                                     neig = min(50, L, K),
                                     ...,
                                     force.continue = FALSE) {
  N <- x$length; L <- x$window; K <- N - L + 1

  # Check, whether continuation of decomposition is requested
  if (!force.continue && nlambda(x) > 0)
    stop("Continuation of decompostion is not yet implemented for this method.")

  h <- .get.or.create.hmat(x)
  S <- propack.svd(h, neig = neig, ...)

  # Save results
  .set(x, "lambda", S$d)
  if (!is.null(S$u))
    .set(x, "U", S$u)
  if (!is.null(S$v))
    .set(x, "V", S$v)

  x
}

decompose.1d.ssa.nutrlan <- function(x,
                                     neig = min(50, L, K),
                                       ...) {
  N <- x$length; L <- x$window; K <- N - L + 1

  h <- .get.or.create.hmat(x)

  lambda <- .get(x, "lambda", allow.null = TRUE)
  U <- .get(x, "U", allow.null = TRUE)

  S <- trlan.svd(h, neig = neig, ...,
                 lambda = lambda, U = U)

  # Save results
  .set(x, "lambda", S$d)
  if (!is.null(S$u))
    .set(x, "U", S$u)

  x
}

calc.v.1d.ssa <- function(x, idx, env = .GlobalEnv, ...) {
  lambda <- .get(x, "lambda")[idx]
  U <- .get(x, "U")[, idx, drop = FALSE]
  h <- .get.or.create.hmat(x)

  invisible(sapply(1:length(idx),
                   function(i) hmatmul(h, U[, i], transposed = TRUE) / lambda[i]))
}

#mes <- function(N = 1000, L = (N %/% 2), n = 50) {
#  F <- rnorm(N);
#  v <- rnorm(N - L + 1);
#  C <- tcirc.old(F, L = L);
#  X <- hankel(F, L = L);
#  h <- new.hmat(F, L = L);
#  st1 <- system.time(for (i in 1:n) X %*% v);
#  st2 <- system.time(for (i in 1:n) hmatmul.old(C, v));
#  st3 <- system.time(for (i in 1:n) hmatmul(h, v));
#  c(st1[["user.self"]], st2[["user.self"]], st3[["user.self"]]);
#}


#Rprof();
#for (i in 1:250) {
#  r1 <- X %*% v;
#  r2 <- hmul(C, v);
#}
#Rprof(NULL);
#print(max(abs(r1-r2)));
#summaryRprof();
