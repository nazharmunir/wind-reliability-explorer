# Data utilities for Wind Reliability Explorer

required_columns <- c(
  "component_id", "component_type", "site", "observed_age_years", "failed"
)

validate_component_data <- function(df) {
  missing <- setdiff(required_columns, names(df))
  if (length(missing) > 0) {
    stop("Missing required columns: ", paste(missing, collapse = ", "))
  }

  if (any(!df$failed %in% c(0, 1))) {
    stop("Column 'failed' must contain only 0/1 values.")
  }

  if (any(!is.finite(df$observed_age_years)) || any(df$observed_age_years <= 0)) {
    stop("Observed ages must be finite positive values.")
  }

  if (any(is.na(df$component_type)) || any(is.na(df$site))) {
    stop("component_type and site cannot contain missing values.")
  }

  invisible(TRUE)
}

generate_synthetic_data <- function(n = 420, seed = 42) {
  stopifnot(n >= 50)
  set.seed(seed)

  component_type <- sample(
    c("Main bearing", "Gearbox", "Generator"),
    n,
    replace = TRUE,
    prob = c(0.35, 0.35, 0.30)
  )
  site <- sample(c("North Sea", "Baltic", "Onshore North"), n, replace = TRUE)

  # Different characteristic lifetimes by component type.
  type_scale <- c(
    "Main bearing" = 9.4,
    "Gearbox" = 8.1,
    "Generator" = 10.7
  )
  type_shape <- c(
    "Main bearing" = 2.25,
    "Gearbox" = 2.55,
    "Generator" = 2.05
  )

  lifetime <- numeric(n)
  for (i in seq_len(n)) {
    lifetime[i] <- rweibull(
      1,
      shape = unname(type_shape[component_type[i]]),
      scale = unname(type_scale[component_type[i]])
    )
  }

  # Administrative censoring: assets are observed for a finite study window.
  censor_time <- runif(n, min = 3.0, max = 12.0)
  failed <- as.integer(lifetime <= censor_time)
  observed_age <- pmin(lifetime, censor_time)

  df <- data.frame(
    component_id = sprintf("WT-%04d", seq_len(n)),
    component_type = component_type,
    site = site,
    observed_age_years = round(observed_age, 3),
    failed = failed,
    stringsAsFactors = FALSE
  )

  validate_component_data(df)
  df
}

load_component_data <- function(path = file.path("data", "synthetic_turbine_components.csv")) {
  if (!file.exists(path)) {
    df <- generate_synthetic_data()
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    utils::write.csv(df, path, row.names = FALSE)
  }

  df <- utils::read.csv(path, stringsAsFactors = FALSE)
  validate_component_data(df)
  df
}

filter_component_data <- function(df, component_type = "All", site = "All") {
  out <- df
  if (!identical(component_type, "All")) {
    out <- out[out$component_type == component_type, , drop = FALSE]
  }
  if (!identical(site, "All")) {
    out <- out[out$site == site, , drop = FALSE]
  }
  out
}
