# ---- Heuristic Search Functions ----
tanh_penalty <- function(x, c, d, s) {
  1 / 2 + 1 / 2 * tanh(s / d * atanh(0.8) * (x - c))
}

heuristic_penalty <- function(summary) {
  0 +
    (1 - summary$AUC) * 5 +
    (1 - summary$per_admin_in) * 2 +
    (1 - summary$per_admin_pos) * 3 +
    tanh_penalty(summary$ch_hr_lower, 3.25, 0.25, -1) * 5 +
    tanh_penalty(summary$ch_hr_lower, 9, 1, 1) +
    tanh_penalty(summary$ch_hr_upper, 9, 1, 1) +
    tanh_penalty(summary$aki_hr_upper, 15, 15, -1) +
    tanh_penalty(summary$aki_hr_upper, 60, 10, 1) +
    grepl("\\bAPACHE_II\\b", summary$glm_model) * 5 +
    grepl("\\bAPACHE_III\\b", summary$glm_model) * 5 +
    grepl("\\bBaseline_Cr\\b", summary$glm_model) +
    grepl("\\bcr\\b", summary$glm_model) * 3 +
    (1 - grepl("cr_gradient", summary$glm_model)) * 6
}

heuristic_wrapper <- function(x,
                              penalty_fn = function(x) x$penalty,
                              return_fn = function(x) x,
                              ...) {
  summary <- aki_dev_wrapper(
    ch_hr_lim = c(x[1] - x[2] / 2, x[1] + x[2] / 2),
    aki_hr_lim = c(x[3], x[3] + x[4]),
    ...
  )
  summary$penalty <- penalty_fn(summary)
  return(return_fn(summary))
}

deoptim_wrapper <- function(lower, upper,
                            itermax,
                            NP = 320,
                            ...,
                            return_fn = function(summary) summary$penalty,
                            fnMap = function(x) round(x, 1),
                            parallel = FALSE) {
  if (parallel) {
    control <- DEoptim.control(
      itermax = itermax,
      NP = NP,
      reltol = 1e-5,
      parallelType = 1,
      packages = c("dplyr", "cutpointr"),
      parVar = c("analysis_df", "aki_dev_wrapper", "heuristic_penalty", "tanh_penalty")
    )
  } else {
    control <- DEoptim.control(
      itermax = itermax,
      NP = NP,
      reltol = 1e-5
    )
  }

  result <- DEoptim(
    heuristic_wrapper,
    lower = lower,
    upper = upper,
    control = control,
    ..., # Passed into the heuristic wrapper
    return_fn = return_fn, # Also passed into the heuristic wrapper
    fnMap = fnMap
  )
  return(list(
    bestmem = heuristic_wrapper(result$optim$bestmem, ...),
    result = result
  ))
}

# Example:
# example1 <- deoptim_wrapper(
#   lower = c(4, 0.5, 3, 1),
#   upper = c(6, 6, 12, 72),
#   itermax = 3, # 20 brief test
#   NP = 32,
#   analysis_data = epoc_aki$analysis,
#   outcome_var = "AKI_2or3",
#   baseline_predictors = NULL,
#   cr_predictors = NULL,
#   add_gradient_predictor = 1,
#   penalty_fn = heuristic_penalty,
#   parallel = FALSE
# )
# example2 <- deoptim_wrapper(
#   lower = c(4, 0.5, 3, 1),
#   upper = c(6, 6, 12, 72),
#   itermax = 3, # 20 brief test
#   NP = 32,
#   outcome_var = "AKI_2or3",
#   baseline_predictors = NULL,
#   cr_predictors = NULL,
#   add_gradient_predictor = 1,
#   penalty_fn = heuristic_penalty,
#   parallel = TRUE
# )


# ---- deoptim functions ----
deoptim_search <- function( # aki_dev_wrapper
                           analysis_data,
                           outcome_var,
                           baseline_predictors,
                           cr_predictors,
                           add_gradient_predictor,
                           first_cr_only = FALSE,
                           stepwise = FALSE,
                           k = "mBIC",
                           # de_optim
                           penalty_fn = heuristic_penalty,
                           itermax = 200,
                           NP = 320,
                           parallel = TRUE,
                           # extra
                           secondary_outcomes = c(
                             "AKI_ICU",
                             "Cr_defined_AKI_2or3", "Cr_defined_AKI",
                             "Olig_defined_AKI_2or3", "Olig_defined_AKI"
                           ),
                           baseline_data = NULL,
                           override = NULL,
                           print = TRUE) {
  if (is.null(override)) {
    optim_value <- deoptim_wrapper(
      lower = c(4, 0.5, 3, 1),
      upper = c(6, 6, 12, 72),
      analysis_data = analysis_data,
      outcome_var = outcome_var,
      baseline_predictors = baseline_predictors,
      cr_predictors = cr_predictors,
      add_gradient_predictor = add_gradient_predictor,
      stepwise = stepwise,
      k = k,
      penalty_fn = heuristic_penalty,
      itermax = itermax,
      NP = NP,
      parallel = parallel
    )
  } else {
    optim_value <- list(result = list(optim = list(bestmem = override)))
  }

  optim_model <- heuristic_wrapper(
    optim_value$result$optim$bestmem,
    analysis_data = analysis_data,
    outcome_var = outcome_var,
    baseline_predictors = baseline_predictors,
    cr_predictors = cr_predictors,
    add_gradient_predictor = add_gradient_predictor,
    first_cr_only = first_cr_only,
    stepwise = stepwise,
    k = k,
    all_data = TRUE
  )
  cat("\n----------------\nOptimised model found:\n")
  print_model_summary(optim_model, print = print)

  optim_model_full <- heuristic_wrapper(
    optim_value$result$optim$bestmem,
    analysis_data = analysis_data,
    outcome_var = outcome_var,
    baseline_predictors = baseline_predictors,
    cr_predictors = cr_predictors,
    add_gradient_predictor = add_gradient_predictor,
    all_data = TRUE,
  )
  cat("\n----------------\nOptimised model with all variables:\n")
  print_model_summary(optim_model_full, print = print)

  if (!is.null(baseline_data)) {
    baseline_all <- aki_dev_wrapper(
      analysis_data = baseline_data,
      outcome_var = outcome_var,
      baseline_predictors = baseline_predictors,
      cr_predictors = NULL,
      add_gradient_predictor = NULL,
      ch_hr_lim = c(-Inf, Inf),
      aki_hr_lim = c(-Inf, Inf),
      all_data = TRUE
    )
    cat("\n----------------\nBaseline model for all admissions:\n")
    print_model_summary(baseline_all, print = print)

    baseline_sig <- aki_dev_wrapper(
      analysis_data = baseline_data,
      outcome_var = outcome_var,
      baseline_predictors = baseline_predictors,
      cr_predictors = NULL,
      add_gradient_predictor = NULL,
      ch_hr_lim = c(-Inf, Inf),
      aki_hr_lim = c(-Inf, Inf),
      stepwise = TRUE,
      k = "AIC",
      all_data = TRUE
    )
    cat("\n----------------\nBaseline model for all admissions (sig only):\n")
    print_model_summary(baseline_sig, print = print)
  }

  # Update the predictors if it was stepwise!
  baseline_predictors <- gsub(".*~ | \\+ \\bcr\\b| \\+ \\bcr_gradient\\b", "", optim_model$summary$glm_model)
  if (str_split(baseline_predictors, " \\+ ") %in% cr_predictors) {
    baseline_predictors <- NULL
  }
  # if (nchar(baseline_predictors) == 0) baseline_predictors <- NULL
  if (!grepl("\\bcr\\b|\\bdel_cr\\b|\\bper_cr_change\\b", optim_model$summary$glm_model)) cr_predictors <- NULL
  if (!grepl("\\bcr_gradient\\b", optim_model$summary$glm_model)) add_gradient_predictor <- NULL
  if (grepl("~ cr_gradient$", optim_model$summary$glm_model)) baseline_predictors <- NULL # Edge case where baseline_predictors = "cr_gradient" only

  secondary_models <- lapply(
    secondary_outcomes,
    function(outcome_var) {
      secondary_model <- heuristic_wrapper(
        optim_value$result$optim$bestmem,
        analysis_data = analysis_data,
        outcome_var = outcome_var,
        baseline_predictors = baseline_predictors,
        cr_predictors = cr_predictors,
        add_gradient_predictor = add_gradient_predictor,
        all_data = TRUE
      )
      cat(paste0("\n----------------\nSame model with secondary outcome ", outcome_var, ":\n"))
      print_model_summary(secondary_model, print = print)
      return(secondary_model)
    }
  )
  names(secondary_models) <- secondary_outcomes

  # CR ONLY models

  if (is.null(baseline_data)) {
    return(list(
      optim_value = optim_value,
      optim_model = optim_model,
      optim_model_full = optim_model_full,
      secondary_models = secondary_models
    ))
  } else {
    return(list(
      optim_value = optim_value,
      optim_model = optim_model,
      optim_model_full = optim_model_full,
      baseline_models = list(baseline_all = baseline_all, baseline_sig = baseline_sig),
      secondary_models = secondary_models
    ))
  }
}
