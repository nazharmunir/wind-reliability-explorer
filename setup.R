packages <- c(
  "shiny",
  "ggplot2",
  "survival",
  "DT",
  "scales",
  "testthat"
)

missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  install.packages(missing, repos = "https://cloud.r-project.org")
}

message("Dependencies ready. Run: shiny::runApp()")
