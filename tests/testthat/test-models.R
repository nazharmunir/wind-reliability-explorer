source(file.path("R", "data_pipeline.R"))
source(file.path("R", "survival_models.R"))
source(file.path("R", "reliability_metrics.R"))

testthat::test_that("synthetic data contains failures and right-censored observations", {
  df <- generate_synthetic_data(n = 250, seed = 123)
  testthat::expect_true(any(df$failed == 1))
  testthat::expect_true(any(df$failed == 0))
  testthat::expect_true(all(df$observed_age_years > 0))
})

testthat::test_that("Weibull parameters are finite and positive", {
  df <- generate_synthetic_data(n = 300, seed = 123)
  fit <- fit_weibull_model(df)
  testthat::expect_true(is.finite(fit$shape) && fit$shape > 0)
  testthat::expect_true(is.finite(fit$scale) && fit$scale > 0)
})

testthat::test_that("Weibull survival is monotone non-increasing", {
  ages <- seq(0, 15, by = 0.25)
  s <- weibull_survival(ages, shape = 2.2, scale = 9.0)
  testthat::expect_true(all(diff(s) <= 1e-12))
  testthat::expect_equal(s[1], 1)
})

testthat::test_that("conditional failure probability is bounded and rises with horizon", {
  r6 <- conditional_failure_probability(6, 0.5, shape = 2.2, scale = 9.0)
  r12 <- conditional_failure_probability(6, 1.0, shape = 2.2, scale = 9.0)
  testthat::expect_gte(r6, 0)
  testthat::expect_lte(r6, 1)
  testthat::expect_gt(r12, r6)
})

testthat::test_that("risk table only contains active components and is sorted", {
  df <- generate_synthetic_data(n = 300, seed = 321)
  fit <- fit_weibull_model(df)
  risk <- build_risk_table(df, 1, fit)
  testthat::expect_true(all(risk$failed == 0))
  testthat::expect_true(all(diff(risk$risk_next_horizon) <= 0))
})
