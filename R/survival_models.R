# Survival and reliability models

fit_kaplan_meier <- function(df, group_by = NULL) {
  validate_component_data(df)
  if (nrow(df) < 5) {
    stop("At least 5 observations are required for survival modelling.")
  }

  y <- survival::Surv(time = df$observed_age_years, event = df$failed)

  if (is.null(group_by) || identical(group_by, "None")) {
    survival::survfit(y ~ 1, data = df)
  } else {
    if (!group_by %in% names(df)) {
      stop("Unknown grouping column: ", group_by)
    }
    survival::survfit(stats::as.formula(paste("y ~", group_by)), data = df)
  }
}

fit_weibull_model <- function(df) {
  validate_component_data(df)
  if (nrow(df) < 10 || sum(df$failed) < 3) {
    stop("Weibull fitting needs at least 10 observations and 3 failures.")
  }

  model <- survival::survreg(
    survival::Surv(observed_age_years, failed) ~ 1,
    data = df,
    dist = "weibull"
  )

  # survreg's Weibull parameterisation: shape = 1 / model$scale,
  # characteristic life (scale) = exp(intercept).
  list(
    model = model,
    shape = 1 / model$scale,
    scale = exp(stats::coef(model)[1])
  )
}

weibull_survival <- function(age, shape, scale) {
  exp(-((pmax(age, 0) / scale) ^ shape))
}

weibull_hazard <- function(age, shape, scale) {
  age_safe <- pmax(age, 1e-8)
  (shape / scale) * ((age_safe / scale) ^ (shape - 1))
}

conditional_failure_probability <- function(current_age, horizon_years, shape, scale) {
  stopifnot(horizon_years >= 0, shape > 0, scale > 0)
  s_now <- weibull_survival(current_age, shape, scale)
  s_future <- weibull_survival(current_age + horizon_years, shape, scale)
  risk <- 1 - (s_future / pmax(s_now, .Machine$double.eps))
  pmin(pmax(risk, 0), 1)
}

km_to_data_frame <- function(fit) {
  s <- summary(fit)
  strata <- if (is.null(s$strata)) rep("All components", length(s$time)) else as.character(s$strata)
  data.frame(
    time = s$time,
    survival = s$surv,
    lower = s$lower,
    upper = s$upper,
    strata = strata,
    stringsAsFactors = FALSE
  )
}

weibull_curve_data <- function(fit, max_age = 15, points = 250) {
  age <- seq(0, max_age, length.out = points)
  data.frame(
    age = age,
    survival = weibull_survival(age, fit$shape, fit$scale),
    hazard = weibull_hazard(age, fit$shape, fit$scale)
  )
}
