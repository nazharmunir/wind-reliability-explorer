# Decision-oriented reliability metrics

build_risk_table <- function(df, horizon_years, weibull_fit) {
  validate_component_data(df)

  active <- df[df$failed == 0, , drop = FALSE]
  if (nrow(active) == 0) {
    return(data.frame())
  }

  active$risk_next_horizon <- conditional_failure_probability(
    current_age = active$observed_age_years,
    horizon_years = horizon_years,
    shape = weibull_fit$shape,
    scale = weibull_fit$scale
  )

  active$risk_band <- cut(
    active$risk_next_horizon,
    breaks = c(-Inf, 0.10, 0.25, Inf),
    labels = c("Low", "Medium", "High")
  )

  active <- active[order(-active$risk_next_horizon), , drop = FALSE]
  active$risk_next_horizon <- round(active$risk_next_horizon, 4)
  active
}

summary_metrics <- function(df, horizon_years, weibull_fit) {
  active <- df[df$failed == 0, , drop = FALSE]
  risks <- if (nrow(active) > 0) {
    conditional_failure_probability(
      active$observed_age_years,
      horizon_years,
      weibull_fit$shape,
      weibull_fit$scale
    )
  } else numeric(0)

  list(
    observations = nrow(df),
    failures = sum(df$failed),
    censored = sum(df$failed == 0),
    median_age = stats::median(df$observed_age_years),
    mean_active_risk = if (length(risks)) mean(risks) else NA_real_,
    high_risk_count = if (length(risks)) sum(risks >= 0.25) else 0
  )
}
