library(shiny)
library(ggplot2)
library(survival)
library(DT)
library(scales)

source(file.path("R", "data_pipeline.R"))
source(file.path("R", "survival_models.R"))
source(file.path("R", "reliability_metrics.R"))

all_data <- load_component_data()

fmt_pct <- function(x) {
  if (length(x) == 0 || is.na(x)) return("—")
  scales::percent(x, accuracy = 0.1)
}

metric_card <- function(title, value, note = NULL) {
  div(
    class = "metric-card",
    div(class = "metric-title", title),
    div(class = "metric-value", value),
    if (!is.null(note)) div(class = "metric-note", note)
  )
}

ui <- fluidPage(
  tags$head(
    tags$title("Wind Reliability Explorer"),
    tags$link(rel = "preconnect", href = "https://fonts.googleapis.com"),
    tags$link(
      href = "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap",
      rel = "stylesheet"
    ),
    tags$style(HTML("\n      body { background:#f5f7fa; font-family:'Inter',sans-serif; color:#172033; }\n      .container-fluid { padding:0; }\n      .hero { background:linear-gradient(120deg,#102f3f,#174d5f); color:white; padding:28px 36px 24px; }\n      .hero h1 { margin:0 0 6px; font-size:32px; font-weight:700; }\n      .hero p { margin:0; opacity:.86; max-width:850px; }\n      .content-wrap { padding:22px 30px 36px; }\n      .control-panel, .panel-card, .metric-card { background:white; border:1px solid #e5e9ef; border-radius:12px; box-shadow:0 4px 18px rgba(18,38,63,.05); }\n      .control-panel { padding:18px; margin-bottom:18px; }\n      .panel-card { padding:18px; margin-bottom:18px; min-height:390px; }\n      .metric-grid { display:grid; grid-template-columns:repeat(5,minmax(0,1fr)); gap:12px; margin-bottom:18px; }\n      .metric-card { padding:16px; min-height:104px; }\n      .metric-title { color:#68758a; font-size:12px; font-weight:600; text-transform:uppercase; letter-spacing:.04em; }\n      .metric-value { font-size:26px; font-weight:700; margin-top:8px; color:#153746; }\n      .metric-note { color:#8792a4; font-size:12px; margin-top:4px; }\n      .section-title { font-weight:700; font-size:17px; margin-bottom:12px; }\n      .model-note { background:#edf6f7; border-left:4px solid #2f7f89; padding:10px 12px; border-radius:6px; font-size:13px; }\n      .footer-note { color:#7d8797; font-size:12px; margin-top:10px; }\n      @media (max-width:1000px) { .metric-grid { grid-template-columns:repeat(2,minmax(0,1fr)); } }\n      @media (max-width:650px) { .metric-grid { grid-template-columns:1fr; } .hero,.content-wrap{padding-left:16px;padding-right:16px;} }\n    "))
  ),

  div(
    class = "hero",
    h1("Wind Reliability Explorer"),
    p("R + Shiny prototype for right-censored component lifetime analysis, survival modelling and maintenance-oriented risk prioritisation.")
  ),

  div(
    class = "content-wrap",
    div(
      class = "control-panel",
      fluidRow(
        column(
          3,
          selectInput(
            "component_type", "Component type",
            choices = c("All", sort(unique(all_data$component_type)))
          )
        ),
        column(
          3,
          selectInput(
            "site", "Site",
            choices = c("All", sort(unique(all_data$site)))
          )
        ),
        column(
          3,
          selectInput(
            "group_by", "Kaplan–Meier grouping",
            choices = c("Component type" = "component_type", "Site" = "site", "None" = "None"),
            selected = "component_type"
          )
        ),
        column(
          3,
          sliderInput(
            "horizon", "Risk horizon (months)",
            min = 3, max = 24, value = 12, step = 3
          )
        )
      )
    ),

    uiOutput("metrics"),

    fluidRow(
      column(
        6,
        div(
          class = "panel-card",
          div(class = "section-title", "Kaplan–Meier survival estimate"),
          plotOutput("km_plot", height = 310)
        )
      ),
      column(
        6,
        div(
          class = "panel-card",
          div(class = "section-title", "Weibull reliability & hazard"),
          plotOutput("weibull_plot", height = 310)
        )
      )
    ),

    fluidRow(
      column(
        4,
        div(
          class = "panel-card",
          div(class = "section-title", "Model summary"),
          uiOutput("model_summary")
        )
      ),
      column(
        8,
        div(
          class = "panel-card",
          div(class = "section-title", "Active components ranked by conditional failure risk"),
          DTOutput("risk_table")
        )
      )
    ),

    div(
      class = "footer-note",
      "Portfolio prototype using synthetic component-lifetime data. It demonstrates statistical reliability concepts and software structure; it is not an operational maintenance recommendation system."
    )
  )
)

server <- function(input, output, session) {
  filtered_data <- reactive({
    df <- filter_component_data(
      all_data,
      component_type = input$component_type,
      site = input$site
    )
    validate(need(nrow(df) >= 10, "Select a broader segment: fewer than 10 observations remain."))
    df
  })

  weibull_fit <- reactive({
    df <- filtered_data()
    validate(need(sum(df$failed) >= 3, "At least three observed failures are needed for the Weibull model."))
    fit_weibull_model(df)
  })

  km_fit <- reactive({
    df <- filtered_data()
    grouping <- input$group_by

    # If a filter leaves only one level, avoid a meaningless grouped legend.
    if (!identical(grouping, "None") && length(unique(df[[grouping]])) < 2) {
      grouping <- "None"
    }
    fit_kaplan_meier(df, grouping)
  })

  output$metrics <- renderUI({
    df <- filtered_data()
    fit <- weibull_fit()
    m <- summary_metrics(df, input$horizon / 12, fit)

    div(
      class = "metric-grid",
      metric_card("Observations", format(m$observations, big.mark = ","), "Selected segment"),
      metric_card("Observed failures", m$failures, paste0(m$censored, " right-censored")),
      metric_card("Median observed age", paste0(round(m$median_age, 1), " y"), "Failure or censor age"),
      metric_card(paste0("Mean ", input$horizon, "m risk"), fmt_pct(m$mean_active_risk), "Conditional on surviving to current age"),
      metric_card("High-risk active", m$high_risk_count, "Modelled risk ≥ 25%")
    )
  })

  output$km_plot <- renderPlot({
    km_df <- km_to_data_frame(km_fit())

    ggplot(km_df, aes(x = time, y = survival, colour = strata, fill = strata)) +
      geom_step(linewidth = 0.9) +
      geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.10, colour = NA) +
      scale_y_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, 1)) +
      labs(x = "Observed age (years)", y = "Estimated survival probability", colour = NULL, fill = NULL) +
      theme_minimal(base_size = 12) +
      theme(
        legend.position = "bottom",
        panel.grid.minor = element_blank(),
        plot.margin = margin(8, 8, 8, 8)
      )
  })

  output$weibull_plot <- renderPlot({
    fit <- weibull_fit()
    max_age <- max(15, ceiling(max(filtered_data()$observed_age_years) + 2))
    curve <- weibull_curve_data(fit, max_age = max_age)

    hazard_scaled <- curve$hazard / max(curve$hazard, na.rm = TRUE)
    plot_df <- data.frame(
      age = rep(curve$age, 2),
      value = c(curve$survival, hazard_scaled),
      series = rep(c("Survival probability", "Hazard (scaled)"), each = nrow(curve))
    )

    ggplot(plot_df, aes(age, value, linetype = series)) +
      geom_line(linewidth = 1.0) +
      scale_y_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, 1)) +
      labs(x = "Component age (years)", y = "Relative level", linetype = NULL) +
      theme_minimal(base_size = 12) +
      theme(legend.position = "bottom", panel.grid.minor = element_blank())
  })

  output$model_summary <- renderUI({
    fit <- weibull_fit()
    horizon_years <- input$horizon / 12
    ages <- c(4, 6, 8, 10)
    risks <- conditional_failure_probability(ages, horizon_years, fit$shape, fit$scale)

    tagList(
      div(class = "model-note",
          strong("Right-censoring is retained."),
          " Components that have not failed by the end of observation still contribute information to the survival estimate."),
      tags$br(),
      tags$p(strong("Weibull shape β: "), sprintf("%.2f", fit$shape)),
      tags$p(strong("Characteristic life η: "), sprintf("%.2f years", fit$scale)),
      tags$p(
        if (fit$shape > 1) {
          "β > 1 implies an increasing modelled hazard with component age."
        } else if (fit$shape < 1) {
          "β < 1 implies a decreasing modelled hazard with component age."
        } else {
          "β ≈ 1 implies an approximately constant hazard."
        }
      ),
      tags$hr(),
      tags$p(strong(paste0(input$horizon, "-month conditional risk examples"))),
      tags$ul(lapply(seq_along(ages), function(i) {
        tags$li(paste0("Age ", ages[i], " y: ", fmt_pct(risks[i])))
      }))
    )
  })

  output$risk_table <- renderDT({
    fit <- weibull_fit()
    risk <- build_risk_table(filtered_data(), input$horizon / 12, fit)

    if (nrow(risk) == 0) return(datatable(data.frame(Message = "No active components in this segment.")))

    view <- risk[, c(
      "component_id", "component_type", "site",
      "observed_age_years", "risk_next_horizon", "risk_band"
    )]
    names(view) <- c("Component", "Type", "Site", "Current age (y)", "Failure risk", "Risk band")

    datatable(
      view,
      rownames = FALSE,
      options = list(pageLength = 8, order = list(list(4, "desc")), dom = "tip")
    ) |>
      formatPercentage("Failure risk", digits = 1)
  })
}

shinyApp(ui, server)
