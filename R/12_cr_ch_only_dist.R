# Want a bar chart showing how AUC changes with cr_ch range
# Consider faceted bar charts, each row showing a different
# t_AKI range

# ---- Previous Study Cont ----
cr_ch_prev_study_cont <- aki_dev_wrapper(
  analysis_data = epoc_aki$analysis,
  outcome_var = "AKI_ICU",
  baseline_predictors = "",
  cr_predictors = c("del_cr"),
  ch_hr_lim = c(3, 4),
  aki_hr_lim = c(8, 16),
  add_gradient_predictor = NULL,
  all_data = TRUE
)
print_model_summary(cr_ch_prev_study_cont)


# ---- Previous Study Bin ----
cr_ch_prev_study_bin <- aki_dev_wrapper(
  analysis_data = epoc_aki$analysis,
  outcome_var = "AKI_ICU",
  baseline_predictors = "",
  cr_predictors = "",
  ch_hr_lim = c(3, 4),
  aki_hr_lim = c(8, 16),
  add_gradient_predictor = 1,
  all_data = TRUE,
)
print_model_summary(cr_ch_prev_study_bin)


# ---- Uni AUC Distribution ----
uni_auc_dist <- function(outcome_var,
                         del_t_ch_hr_lower,
                         del_t_aki_upper) {

}


# ---- range_cr_ch_cont_only ----
range_cr_ch_only_cont <- tibble(
  del_t_ch_hr_lower = seq(2, 11, by = 1),
  del_t_ch_hr_upper = del_t_ch_hr_lower + 1
) %>%
  mutate(del_t_ch_range = paste0("[", del_t_ch_hr_lower, ", ", del_t_ch_hr_upper, "]")) %>%
  mutate(del_t_ch_range = factor(del_t_ch_range, levels = del_t_ch_range)) %>%
  rowwise() %>%
  do(data.frame(
    .,
    aki_dev_wrapper(
      outcome_var = "AKI_ICU",
      baseline_predictors = "",
      cr_predictors = "del_cr",
      ch_hr_lim = c(.$del_t_ch_hr_lower, .$del_t_ch_hr_upper),
      aki_hr_lim = c(8, 16),
      add_gradient_predictor = NULL,
      heuristic_only = TRUE,
      analysis_data = analysis_df
    )
  )) %>%
  ungroup() %>%
  pivot_longer(cols = c(AUC, per_admin_in), names_to = "names", values_to = "values") %>%
  mutate(
    labels = if_else(names == "AUC", sprintf("%.2f", values), as.character(n_admissions)),
    names = if_else(names == "AUC", "AUC", "Admissions"),
    names = factor(names, levels = c("AUC", "Admissions"))
  )

ggplot(
  range_cr_ch_only_cont,
  aes(x = del_t_ch_range, y = values, fill = names, colour = names)
) +
  geom_col(position = "dodge", alpha = 0.5, colour = NA) +
  geom_label(
    aes(label = labels),
    position = position_dodge(0.9), vjust = -0.2, fill = "white",
    show.legend = FALSE
  ) +
  geom_point(position = position_dodge(0.9)) +
  scale_y_continuous(
    limits = c(0, 0.8),
    breaks = seq(0, 0.8, by = 0.1),
    sec.axis = sec_axis(
      trans = ~ . * length(unique(analysis_df$AdmissionID)),
      name = "Number of Included Admissions",
      breaks = round(seq(0, 0.8, by = 0.1) * length(unique(analysis_df$AdmissionID)), 0)
    )
  ) +
  ggtitle("AUC and Number of Admissions for Various \u0394t Increments") +
  xlab(expression("Duration of small change in Cr epis: " * Delta * "t"["cr_ch"] * " (hours)")) +
  ylab("AUC") +
  scale_fill_manual(name = "Legend", values = c("orange", "blue", "black")) +
  scale_colour_manual(name = "Legend", values = c("orange", "blue", "black")) +
  theme(legend.position = "bottom")
rm(range_cr_ch_only_cont)

# ---- range_cr_ch_bin_only ----
range_cr_ch_only_bin <- tibble(
  del_t_ch_hr_lower = seq(2, 11, by = 1),
  del_t_ch_hr_upper = del_t_ch_hr_lower + 1
) %>%
  mutate(del_t_ch_range = paste0("[", del_t_ch_hr_lower, ", ", del_t_ch_hr_upper, "]")) %>%
  mutate(del_t_ch_range = factor(del_t_ch_range, levels = del_t_ch_range)) %>%
  rowwise() %>%
  do(data.frame(
    .,
    aki_dev_wrapper(
      outcome_var = "AKI_ICU",
      baseline_predictors = "",
      cr_predictors = "",
      ch_hr_lim = c(.$del_t_ch_hr_lower, .$del_t_ch_hr_upper),
      aki_hr_lim = c(8, 16),
      add_gradient_predictor = 1,
      heuristic_only = TRUE,
      analysis_data = analysis_df
    )
  )) %>%
  ungroup() %>%
  pivot_longer(cols = c(AUC, per_admin_in), names_to = "names", values_to = "values") %>%
  mutate(
    labels = if_else(names == "AUC", sprintf("%.2f", values), as.character(n_admissions)),
    names = if_else(names == "AUC", "AUC", "Admissions"),
    names = factor(names, levels = c("AUC", "Admissions"))
  )

ggplot(
  range_cr_ch_only_bin,
  aes(x = del_t_ch_range, y = values, fill = names, colour = names)
) +
  geom_col(position = "dodge", alpha = 0.5, colour = NA) +
  geom_label(
    aes(label = labels),
    position = position_dodge(0.9), vjust = -0.2, fill = "white",
    show.legend = FALSE
  ) +
  geom_point(position = position_dodge(0.9)) +
  scale_y_continuous(
    limits = c(0, 0.8),
    breaks = seq(0, 0.8, by = 0.1),
    sec.axis = sec_axis(
      trans = ~ . * length(unique(analysis_df$AdmissionID)),
      name = "Number of Included Admissions",
      breaks = round(seq(0, 0.8, by = 0.1) * length(unique(analysis_df$AdmissionID)), 0)
    )
  ) +
  ggtitle("AUC and Number of Admissions for Various \u0394t Increments") +
  xlab(expression("Duration of small change in Cr epis: " * Delta * "t"["cr_ch"] * " (hours)")) +
  ylab("AUC") +
  scale_fill_manual(name = "Legend", values = c("orange", "blue", "black")) +
  scale_colour_manual(name = "Legend", values = c("orange", "blue", "black")) +
  theme(legend.position = "bottom")
rm(range_cr_ch_only_bin)
