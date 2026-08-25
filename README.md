# Wind Reliability Explorer

An **R + Shiny reliability-modelling prototype** for analysing wind-turbine component lifetimes when the dataset contains both failures and **right-censored** observations.

The project is intentionally compact: it demonstrates how survival statistics can be turned into a maintainable, user-facing software tool for reliability and maintenance discussions.

## What it does

- fits **Kaplan–Meier survival curves** while retaining right-censored components;
- fits a **parametric Weibull lifetime model**;
- visualises survival and age-dependent hazard behaviour;
- estimates the **conditional probability of failure over the next 3–24 months**, given that a component has survived to its current age;
- ranks active components into low / medium / high modelled risk bands;
- supports filtering by component type and site;
- includes modular R functions, automated tests and GitHub Actions CI.

> **Important:** the included dataset is synthetic. The application is a portfolio and learning prototype, not an operational predictive-maintenance system and not affiliated with Siemens Gamesa or any turbine manufacturer.

## Why right-censoring matters

A reliability dataset rarely contains only completed lifetimes. Many components are still operating when the observation window ends. Dropping them would discard useful evidence and bias lifetime estimates toward shorter-lived components.

This project therefore represents each component as:

```text
observed_age_years + failed (1 = event, 0 = censored)
```

and models it with `survival::Surv()`.

## Statistical approach

### Kaplan–Meier

Kaplan–Meier provides a non-parametric estimate of the survival function:

```text
S(t) = P(T > t)
```

The dashboard can stratify curves by component type or site.

### Weibull model

A Weibull model is fitted using `survival::survreg(..., dist = "weibull")`.

The app reports:

- **shape β** — controls how hazard changes with age;
- **characteristic life η** — the Weibull scale parameter;
- an age-dependent hazard curve;
- conditional near-term failure probabilities.

For a currently operating component of age `a`, the probability of failure during the next horizon `h` is calculated as:

```text
P(a < T <= a+h | T > a) = 1 - S(a+h) / S(a)
```

This is more useful for maintenance prioritisation than an unconditional lifetime probability.

## Project structure

```text
wind-reliability-explorer/
├── app.R
├── R/
│   ├── data_pipeline.R
│   ├── survival_models.R
│   └── reliability_metrics.R
├── data/
│   └── synthetic_turbine_components.csv
├── tests/
│   ├── testthat.R
│   └── testthat/
│       └── test-models.R
├── .github/workflows/
│   └── r-tests.yml
├── setup.R
├── wind-reliability-explorer.Rproj
└── LICENSE
```

## Run locally

Install R, open the project in RStudio, then run:

```r
source("setup.R")
shiny::runApp()
```

Or from a terminal:

```bash
Rscript setup.R
R -e 'shiny::runApp(".")'
```

## Run tests

```bash
Rscript tests/testthat.R
```

## Reproducible environment

For a fully pinned environment, initialise `renv` after cloning:

```r
install.packages("renv")
renv::init()
renv::snapshot()
```

`renv` is intentionally not pre-initialised in this repository so the lockfile can be generated with the R version used by the person running the project rather than committing an unverified lockfile.

## Synthetic data

The synthetic generator creates three component families with different Weibull lifetime characteristics and then applies an administrative observation window. Components whose generated lifetime exceeds that window are marked as right-censored.

This makes the example statistically meaningful without presenting simulated data as real turbine evidence.

## Engineering choices

The app separates:

1. **data validation / acquisition** (`R/data_pipeline.R`)
2. **statistical models** (`R/survival_models.R`)
3. **decision metrics** (`R/reliability_metrics.R`)
4. **presentation / interaction** (`app.R`)

This keeps the modelling logic independently testable and makes it easier to replace the synthetic data source with a real reliability dataset later.

## Possible next steps

- component-specific or hierarchical Weibull models;
- covariates via Cox proportional-hazards models;
- uncertainty intervals for predicted conditional risk;
- maintenance cost / downtime optimisation;
- ingestion of open SCADA/event-log datasets;
- calibration and out-of-sample validation;
- deployment with a reproducible `renv` lockfile.

## Author

**Muhammad Mazhar Munir**  
M.Sc. Data Science — Hamburg University of Technology (TUHH)  
Software engineer interested in reliability modelling, data-intensive systems and renewable-energy applications.
