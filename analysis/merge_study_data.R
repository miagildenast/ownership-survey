# merge_study_data.R — joins this app's export with the SoSci dataset.
# Join key: case_number (app) <-> CASE (SoSci).

# useful libraries
library(here)
library(tidyverse)
library(jsonlite)

# directories to get/put data
RAW_DIR <- here("data", "raw")
OUT_DIR <- here("data", "derived")


PATH_OWNERSHIP_SESSIONS <- file.path(RAW_DIR, "export.json")
PATH_SOSCI    <- file.path(RAW_DIR, "rdata.csv")

dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# code comes here
