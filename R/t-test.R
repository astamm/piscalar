#' @rdname mean
#' @export
t_test <- function(x, y = NULL,
                   alternative = c("two_tail", "left_tail", "right_tail"),
                   mu = 0, paired = FALSE, var_equal = FALSE,
                   conf_level = 0.95, B = 1000) {
  if (is.null(y))
    stop("One-sample test not yet implemented.")
  if (!is.numeric(x) || !is.numeric(y))
    stop("Both data samples should be numeric and univariate.")

  alternative <- match.arg(alternative)

  method <- if (var_equal)
    "Two-Sample Student Permutation Test"
  else
    "Two-Sample Welch Permutation Test"

  stat_fun <- function(data, indices) {
    stat_t(data, indices, var_equal = var_equal)
  }

  statistic <- stat_fun(
    data = c(
      purrr::array_tree(x, margin = 1),
      purrr::array_tree(y, margin = 1)
    ),
    indices = 1:length(x)
  )

  pf <- flipr::PlausibilityFunction$new(mean_null, 1, x, y, stats = stat_fun)
  pf$set_nperms(B)
  pf$set_alternative(alternative)

  estimate <- stats::optim(
    par = mean(y)- mean(x),
    fn = function(x) -pf$get_value(x),
    method = "BFGS"
  )$par

  stderr <- estimate / statistic

  conf_int <- flipr::two_sample_ci(
    pf = pf,
    conf_level = conf_level,
    point_estimate = estimate
  )
  attr(conf_int, "conf.level") <- conf_level

  structure(
    list(
      statistic = statistic,
      parameter = NULL,
      p.value = pf$get_value(mu),
      estimate = c(`mu_y - mu_x` = estimate),
      conf.int = conf_int,
      null.value = c(`mu_y - mu_x` = mu),
      stderr = stderr,
      alternative = if (alternative == "two_tail")
        "two.sided"
      else if (alternative == "left_tail")
        "less"
      else
        "greater",
      method = method,
      data.name = paste0(
        rlang::expr_deparse(rlang::enexpr(x), width = Inf),
        " and ",
        rlang::expr_deparse(rlang::enexpr(y), width = Inf)
      )
    ),
    class = "htest"
  )
}

stat_t <- function(data, indices, var_equal = FALSE) {
  n <- length(data)
  n1 <- length(indices)
  n2 <- n - n1
  indices2 <- seq_len(n)[-indices]
  x1 <- unlist(data[indices])
  x2 <- unlist(data[indices2])
  val <- stats::t.test(x2, x1, var.equal = var_equal)$statistic
  names(val) <- if (var_equal) "student" else "welch"
  val
}
