# Data utilities for Wind Reliability Explorer

component_types <- c("Main bearing", "Gearbox", "Generator")

component_codes <- c(
  "Main bearing" = "MB",
  "Gearbox" = "GB",
  "Generator" = "GEN"
)

required_columns <- c(
  "turbine_id", "component_id", "component_type", "site",
  "observed_age_years", "failed"
)

validate_component_data <- function(df, require_complete_turbines = FALSE) {
  missing <- setdiff(required_columns, names(df))
  if (length(missing) > 0) {
    stop("Missing required columns: ", paste(missing, collapse = ", "))
  }

  if (any(is.na(df$turbine_id)) || any(!nzchar(trimws(df$turbine_id)))) {
    stop("turbine_id cannot contain missing or empty values.")
  }

  if (any(is.na(df$component_id)) || any(!nzchar(trimws(df$component_id)))) {
    stop("component_id cannot contain missing or empty values.")
  }

  if (anyDuplicated(df$component_id)) {
    stop("component_id must be unique.")
  }

  unknown_types <- setdiff(unique(df$component_type), component_types)
  if (length(unknown_types) > 0) {
    stop("Unknown component types: ", paste(unknown_types, collapse = ", "))
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

  if (require_complete_turbines) {
    rows_per_turbine <- table(df$turbine_id)
    if (any(rows_per_turbine != length(component_types))) {
      stop(
        "Each turbine must contain exactly ",
        length(component_types),
        " component records: ",
        paste(component_types, collapse = ", "),
        "."
      )
    }

    types_by_turbine <- split(df$component_type, df$turbine_id)
    complete_types <- vapply(
      types_by_turbine,
      function(x) {
        length(x) == length(component_types) &&
          setequal(x, component_types) &&
          anyDuplicated(x) == 0
      },
      logical(1)
    )

    if (any(!complete_types)) {
      bad_ids <- names(complete_types)[!complete_types]
      stop(
        "Every turbine must have exactly one Main bearing, one Gearbox and one Generator. Invalid turbine(s): ",
        paste(utils::head(bad_ids, 5), collapse = ", "),
        if (length(bad_ids) > 5) " ..." else ""
      )
    }

    sites_by_turbine <- split(df$site, df$turbine_id)
    one_site <- vapply(sites_by_turbine, function(x) length(unique(x)) == 1, logical(1))
    if (any(!one_site)) {
      stop("All component records for a turbine must belong to the same site.")
    }
  }

  invisible(TRUE)
}

generate_synthetic_data <- function(n_turbines = 140, seed = 42) {
  if (n_turbines < 20) {
    stop("n_turbines must be at least 20.")
  }

  set.seed(seed)

  turbine_ids <- sprintf("WT-%04d", seq_len(n_turbines))
  site_by_turbine <- sample(
    c("North Sea", "Baltic", "Onshore North"),
    n_turbines,
    replace = TRUE
  )

  # One observation window per turbine keeps the three component records
  # tied to the same asset context.
  censor_by_turbine <- runif(n_turbines, min = 3.0, max = 12.0)

  df <- data.frame(
    turbine_id = rep(turbine_ids, each = length(component_types)),
    component_type = rep(component_types, times = n_turbines),
    site = rep(site_by_turbine, each = length(component_types)),
    censor_time = rep(censor_by_turbine, each = length(component_types)),
    stringsAsFactors = FALSE
  )

  df$component_id <- paste(
    df$turbine_id,
    unname(component_codes[df$component_type]),
    sep = "-"
  )

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

  lifetime <- stats::rweibull(
    nrow(df),
    shape = unname(type_shape[df$component_type]),
    scale = unname(type_scale[df$component_type])
  )

  df$failed <- as.integer(lifetime <= df$censor_time)
  df$observed_age_years <- round(pmin(lifetime, df$censor_time), 3)

  df <- df[, c(
    "turbine_id", "component_id", "component_type", "site",
    "observed_age_years", "failed"
  )]

  validate_component_data(df, require_complete_turbines = TRUE)
  df
}

load_component_data <- function(path = file.path("data", "synthetic_turbine_components.csv")) {
  if (!file.exists(path)) {
    df <- generate_synthetic_data()
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    utils::write.csv(df, path, row.names = FALSE)
  }

  df <- utils::read.csv(path, stringsAsFactors = FALSE)
  validate_component_data(df, require_complete_turbines = TRUE)
  df
}

filter_component_data <- function(df, component_type = "All", site = "All") {
  validate_component_data(df)

  out <- df
  if (!identical(component_type, "All")) {
    out <- out[out$component_type == component_type, , drop = FALSE]
  }
  if (!identical(site, "All")) {
    out <- out[out$site == site, , drop = FALSE]
  }
  out
}
