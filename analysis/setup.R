# =============================================================================
# setup.R — run once, after R and RStudio are installed.
#
#   source("setup.R")
#
# Not needed again afterwards. Anyone checking the project out later runs
# renv::restore() instead, which recreates exactly the package versions pinned
# here.
# =============================================================================

# The packages the merge and the analysis need.
#   tidyverse — dplyr/tidyr/readr/purrr/stringr in one
#   jsonlite  — reads the app's JSON export
#   here      — paths relative to the project, not the working directory
#   lmerTest  — mixed models with p-values (pulls in lme4)
packages <- c("tidyverse", "jsonlite", "here", "lmerTest")

# renv keeps package versions project-local, so the analysis still produces the
# same result in two years.
if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv")
}

# init() creates renv.lock, .Rprofile and renv/activate.R, adopting packages
# that are already installed. bare = TRUE because the list above is the source
# of truth — no need for renv to scan the project.
if (!file.exists("renv.lock")) {
  renv::init(bare = TRUE, restart = FALSE)
}

missing <- packages[!packages %in% rownames(installed.packages())]
if (length(missing) > 0) {
  message("Installing: ", paste(missing, collapse = ", "))
  renv::install(missing)
}

# Writes the versions actually installed to renv.lock. That file belongs in git
# — it is the reproducible part.
renv::snapshot(packages = packages, prompt = FALSE)

message(
  "\nDone. renv.lock written.\n",
  "Next: put the snapshots into data/raw/, then\n",
  "  source(\"merge_study_data.R\")\n"
)
