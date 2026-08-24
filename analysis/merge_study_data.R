# merge_study_data.R — joins this app's export with the SoSci dataset.
# Join key: case_number (app) <-> CASE (SoSci).

# useful libraries
library(here)
library(tidyverse)
library(jsonlite)
library(psych)

# directories to get/put data
RAW_DIR <- here("data", "raw")
OUT_DIR <- here("data", "derived")


PATH_OWNERSHIP_SESSIONS <- file.path(RAW_DIR, "export.json")
PATH_SOSCI    <- file.path(RAW_DIR, "rdata.csv")

dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)


# =============================================================================
# Konfiguration — die Stellschrauben dieses Skripts
# =============================================================================

# Das von SoSci mitgelieferte Import-Script. Es ist der maßgebliche Vertrag für
# das Einlesen von rdata.csv (Spaltenreihenfolge, Typen, skip = 1, Value-Labels)
# und wird deshalb ausgeführt statt nachgebaut — siehe read_sosci() unten.
PATH_SOSCI_IMPORT <- Sys.glob(here("sosci", "import_*.r"))

# --- Ausschlusskriterien ------------------------------------------------------
#
# Ein Eintrag = ein Kriterium. Trifft es zu, wird der Fall AUSGESCHLOSSEN.
#
#   Erweitern:     eine Zeile hinzufügen
#   Deaktivieren:  eine Zeile auskommentieren
#   Ändern:        den Ausdruck anpassen
#
# Mehr ist nicht nötig — der Rest des Skripts ist generisch: jedes Kriterium
# bekommt automatisch eine eigene ex_<name>-Spalte, taucht in
# `ausschlussgrund` auf und erhält eine Zeile in teilnehmerfluss.csv.
#
# Die Ausdrücke werden auf dem gematchten Datensatz ausgewertet und dürfen
# SoSci-Spalten (SC02, FINISHED, TIME_SUM, MISSING, …) genauso verwenden wie
# App-Spalten (session_status, n_runs, session_dauer_min, …). Referenziert ein
# Kriterium eine Spalte, die es im jeweiligen Datensatz nicht gibt (etwa bei
# den Nur-SoSci-Fällen), wird es dort übersprungen statt zu scheitern.
#
# Beispiel für ein zusätzliches Kriterium:
#   zu_schnell = quo(TIME_SUM < 300)
#
EXCLUSION_CRITERIA <- list(
  # "SC02" leeres Feld — Debrief nicht abgesendet.
  # na.strings = "" im Import-Script macht aus dem leeren Feld ein echtes NA.
  sc02_leer     = quo(is.na(SC02)),

  # "FINISHED" enthält "F" — Befragung abgebrochen.
  # FINISHED ist logical; `!x %in% TRUE` statt `!x`, damit NA als Ausschluss
  # zählt und nicht selbst wieder zu NA wird.
  nicht_beendet = quo(!FINISHED %in% TRUE)
)

# Sollen die Run-Tabellen (06_zusammengefuehrt, transcripts_long) nur die
# eingeschlossene Stichprobe enthalten? Die Spalte `ausgeschlossen` bleibt in
# jedem Fall erhalten, damit der Filter nachvollziehbar ist. Auf FALSE setzen,
# wenn Sensitivitätsanalysen die ausgeschlossenen Fälle mitrechnen sollen.
RUN_TABLES_ONLY_INCLUDED <- TRUE

# --- Likert-Items -------------------------------------------------------------
#
# Die Keys, die der App-Export liefert, enthalten Bindestriche (in R-Spalten
# unhandlich) und zwei Tippfehler ("accountabilit", "self-identiy"). Das Mapping
# steht hier sichtbar, damit es angepasst werden kann, falls die App die Keys
# repariert — dann ändert sich nur die linke Seite.
#
# Alle Items sind positiv gepolt (höher = mehr Ownership) und dürfen deshalb
# ohne Umpolung gemittelt werden.
LIKERT_ITEMS <- c(
  "accountabilit-and-responsibility" = "accountability_and_responsibility",
  "authorship"                       = "authorship",
  "autonomy"                         = "autonomy",
  "liking"                           = "liking",
  "self-efficacy"                    = "self_efficacy",
  "self-identiy"                     = "self_identity",
  "territoriality"                   = "territoriality"
)

LIKERT_COLS <- paste0("likert_", unname(LIKERT_ITEMS))

# --- Klarnamen für 07_lesbar --------------------------------------------------
#
# 07 ist 06 mit sprechenden Überschriften: statt "SC01" steht dort "Consent".
# Die Basis liefert das SoSci-Codebook selbst (die comment()-Attribute des
# Import-Scripts) — dadurch bleiben die Überschriften nach einem Re-Export
# automatisch aktuell. Ergänzt wird sie um zwei Tabellen:

# 1. Spalten, die das Codebook nicht kennt: alles aus dem App-Export und die
#    hier abgeleiteten Spalten.
COLUMN_LABELS_APP <- c(
  CASE                 = "Fallnummer",
  case_number          = "Fallnummer (App)",
  case_id              = "Teilnahme-Token",
  session_id           = "Session-ID",
  session_status       = "Session-Status",
  session_started_at   = "Session Beginn",
  session_completed_at = "Session Ende",
  session_dauer_min    = "Session Dauer (min)",
  topic_source_order   = "Reihenfolge der Themenvorgabe",
  n_runs               = "Anzahl Durchgänge",
  n_writing_runs       = "Anzahl Schreib-Durchgänge",
  hat_modifikation     = "Modifikations-Durchgang vorhanden",

  kind                 = "Art des Durchgangs",
  run_pos              = "Position im Ablauf (1-5)",
  run_index            = "Durchgang Nr. (Schreiben 1-4)",
  topic_source         = "Themenvorgabe",
  ai_mode              = "KI-Modus",
  topic                = "Vorgegebenes Thema",
  final_haiku          = "Haiku",
  run_started_at       = "Durchgang Beginn",
  run_completed_at     = "Durchgang Ende",
  run_dauer_s          = "Durchgang Dauer (s)",
  n_turns              = "Anzahl Redebeiträge",

  likert_accountability_and_responsibility = "Ownership: Verantwortung",
  likert_authorship                        = "Ownership: Urheberschaft",
  likert_autonomy                          = "Ownership: Autonomie",
  likert_liking                            = "Ownership: Gefallen",
  likert_self_efficacy                     = "Ownership: Selbstwirksamkeit",
  likert_self_identity                     = "Ownership: Selbstbild",
  likert_territoriality                    = "Ownership: Territorialität",
  likert_mean                              = "Ownership: Mittelwert",

  variant              = "Modifikation: Variante",
  source_run_index     = "Modifikation: Vorlage (Durchgang Nr.)",
  modified_line_index  = "Modifikation: geänderte Zeile (0-basiert)",
  original_haiku       = "Modifikation: Haiku vorher",
  modified_haiku       = "Modifikation: Haiku nachher",
  offen_anmerkungen    = "Offene Antwort: Anmerkungen",
  offen_mitteilungen   = "Offene Antwort: Mitteilungen",

  ausgeschlossen       = "Ausgeschlossen",
  ausschlussgrund      = "Ausschlussgrund"
)

# 2. Codebook-Labels, die als Spaltenüberschrift unbrauchbar sind: Eingabe-
#    hinweise, ganze Fragesätze, ein Tippfehler in der Quelle. Diese Tabelle
#    gewinnt gegen das Codebook.
COLUMN_LABELS_OVERRIDE <- c(
  # Eingabehinweise und Item-Nummern im Label
  SD02_01  = "Alter",                            # "Alter (direkt): Ich bin ... Jahre"
  SD06     = "KI Anwendungsbereiche (Anzahl)",
  SD07_01  = "KI Aufgabenbereiche (offen)",      # "... : [01]"
  SD08     = "Kreatives Schreiben",              # Codebook schreibt "Kreatvies"

  # Codebook-Labels, die ganze Fragesätze sind
  SERIAL   = "Teilnahmecode",
  QUESTNNR = "Fragebogen",
  STARTED  = "Interview Beginn",
  MAILSENT = "Einladungsmail versandt",
  LASTDATA = "Zuletzt geändert",
  STATUS   = "Interview-Status",
  FINISHED = "Befragung abgeschlossen",
  Q_VIEWER = "Nur angesehen (Durchklicker)",
  LASTPAGE = "Zuletzt bearbeitete Seite",
  MAXPAGE  = "Höchste bearbeitete Seite",
  MISSING  = "Fehlende Antworten (%)",
  MISSREL  = "Fehlende Antworten (gewichtet)",
  TIME_SUM = "Verweildauer gesamt"
)

# --- Teildateien 07a-f --------------------------------------------------------
#
# 07 aufgeteilt: je eine Datei pro Bedingung, dazu der Modifikations-Durchgang
# und eine Datei ohne ihn. Alle sechs haben dieselben Spalten und dieselben
# Überschriften wie 07 — nur die Zeilenauswahl unterscheidet sich.
#
# Ein Eintrag = eine Datei; erweitern heißt eine Zeile hinzufügen.
#
# Der Filter wird auf der TECHNISCHEN Tabelle (zusammengefuehrt) ausgewertet,
# nicht auf den Klarnamen — sonst würde eine Änderung in COLUMN_LABELS_APP die
# Filter still brechen.
#
# a-d schneiden nach BEDINGUNG, nicht nach Position im Ablauf: die Reihenfolge
# ist randomisiert, ein Schnitt nach run_pos würde in jeder Datei alle vier
# Bedingungen mischen. Die Position steht als Spalte weiterhin überall drin.
SUBSET_FILES <- list(
  "07a_frei_mit_ki" = list(
    filter = quo(kind == "writing" & topic_source == "free" & ai_mode == "with_ai"),
    text   = "Freie Themenwahl, mit KI (Ping-Pong)."
  ),
  "07b_frei_ohne_ki" = list(
    filter = quo(kind == "writing" & topic_source == "free" & ai_mode == "without_ai"),
    text   = "Freie Themenwahl, ohne KI (allein geschrieben)."
  ),
  "07c_vorgegeben_mit_ki" = list(
    filter = quo(kind == "writing" & topic_source == "assigned" & ai_mode == "with_ai"),
    text   = "Vorgegebenes Thema, mit KI (Ping-Pong)."
  ),
  "07d_vorgegeben_ohne_ki" = list(
    filter = quo(kind == "writing" & topic_source == "assigned" & ai_mode == "without_ai"),
    text   = "Vorgegebenes Thema, ohne KI (allein geschrieben)."
  ),
  "07e_modifikation" = list(
    filter = quo(kind == "modification"),
    text   = paste(
      "Nur der fünfte Durchgang, in dem die KI eine Zeile des besten Haikus",
      "umgeschrieben hat. Hier sind umgekehrt die Schreib-Spalten leer."
    )
  ),
  "07f_ohne_modifikation" = list(
    filter = quo(kind == "writing"),
    text   = paste(
      "Alle vier Schreib-Durchgänge zusammen, also 07 ohne den",
      "Modifikations-Durchgang. Entspricht 07a bis 07d untereinander."
    )
  )
)


# =============================================================================
# Einlesen — SoSci
# =============================================================================

#' Liest rdata.csv über das von SoSci generierte Import-Script.
#'
#' Das Script ruft `file.choose()` auf, was in einem Batch-Lauf nicht geht. Statt
#' die Spaltenspezifikation (39 Spalten, Typen, Value-Labels) zu duplizieren und
#' damit bei jedem Re-Export zu veralten, wird genau diese eine Zeile ersetzt und
#' das Script in einer eigenen Umgebung ausgeführt.
read_sosci <- function(path_csv, path_script) {
  if (length(path_script) != 1 || !file.exists(path_script)) {
    stop("Genau ein sosci/import_*.r erwartet, gefunden: ",
         paste(path_script, collapse = ", "))
  }

  src <- readLines(path_script, encoding = "UTF-8", warn = FALSE)
  patched <- sub("^ds_file = file\\.choose\\(\\)$",
                 sprintf("ds_file = %s", deparse(path_csv)), src)

  if (identical(patched, src)) {
    stop("In ", basename(path_script), " wurde die Zeile 'ds_file = file.choose()' ",
         "nicht gefunden. Hat SoSci das Script-Format geändert?")
  }

  env <- new.env()
  eval(parse(text = patched, encoding = "UTF-8"), envir = env)
  env$ds
}

#' Die Variablen-Labels, die das Import-Script als comment() je Spalte ablegt.
#' Werden geerntet, bevor das Strippen der avector-Klasse sie unhandlich macht.
sosci_labels <- function(ds) {
  tibble(
    variable = names(ds),
    label    = map_chr(ds, \(x) {
      cm <- comment(x)
      if (is.null(cm)) NA_character_ else as.character(cm)
    })
  ) |>
    filter(!is.na(label))
}

#' Entfernt die avector-Hülle, die das Import-Script am Ende um jede Spalte legt,
#' um Kommentare in Subsets zu erhalten. Für die Weiterverarbeitung ist sie nur
#' Ballast — die Labels sind zu dem Zeitpunkt bereits gesichert.
strip_avector <- function(ds) {
  ds[] <- lapply(ds, \(x) {
    class(x) <- setdiff(class(x), "avector")
    x
  })
  rownames(ds) <- NULL
  as_tibble(ds)
}


# =============================================================================
# Einlesen — OwnershipAshChat
# =============================================================================

# Kleine Helfer: der Export lässt fehlende Werte als JSON-null durch, was in R
# als NULL ankommt und jede Vektorisierung sprengt.
n_chr <- function(x) if (is.null(x)) NA_character_ else as.character(x)
n_int <- function(x) if (is.null(x)) NA_integer_ else as.integer(x)
n_ts  <- function(x) as.POSIXct(n_chr(x), format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")

#' Zieht die sieben Likert-Items eines Runs als benannte Liste heraus — in fester
#' Reihenfolge und mit den bereinigten Namen aus LIKERT_ITEMS.
likert_row <- function(likert) {
  vals <- map(names(LIKERT_ITEMS), \(key) {
    v <- likert[[key]]
    if (is.null(v)) NA_real_ else as.numeric(v)
  })
  set_names(vals, LIKERT_COLS)
}

#' Eine Zeile pro Session.
build_sessions <- function(sessions) {
  map(sessions, \(s) {
    started   <- n_ts(s$started_at)
    completed <- n_ts(s$completed_at)
    tibble(
      CASE                 = as.numeric(s$case_number),
      case_number          = n_chr(s$case_number),
      case_id              = n_chr(s$case_id),
      session_id           = n_chr(s$session_id),
      session_status       = n_chr(s$status),
      session_started_at   = started,
      session_completed_at = completed,
      session_dauer_min    = as.numeric(difftime(completed, started, units = "mins")),
      topic_source_order   = paste(unlist(s$topic_source_order), collapse = "|"),
      n_runs               = length(s$runs),
      n_writing_runs       = sum(map_chr(s$runs, \(r) n_chr(r$kind)) == "writing"),
      hat_modifikation     = any(map_chr(s$runs, \(r) n_chr(r$kind)) == "modification")
    )
  }) |>
    list_rbind()
}

#' Eine Zeile pro Session x Writing-Run (run_index 1..4).
build_writing <- function(sessions) {
  map(sessions, \(s) {
    runs <- keep(s$runs, \(r) identical(r$kind, "writing"))
    map(runs, \(r) {
      started   <- n_ts(r$started_at)
      completed <- n_ts(r$completed_at)
      lik       <- likert_row(r$likert)
      tibble(
        CASE             = as.numeric(s$case_number),
        case_id          = n_chr(s$case_id),
        session_id       = n_chr(s$session_id),
        run_index        = n_int(r$run_index),
        kind             = n_chr(r$kind),
        topic_source     = n_chr(r$topic_source),
        ai_mode          = n_chr(r$ai_mode),
        topic            = n_chr(r$topic),
        final_haiku      = n_chr(r$final_haiku),
        run_started_at   = started,
        run_completed_at = completed,
        run_dauer_s      = as.numeric(difftime(completed, started, units = "secs")),
        !!!lik,
        likert_mean      = mean(unlist(lik), na.rm = FALSE),
        n_turns          = length(r$transcript)
      )
    }) |>
      list_rbind()
  }) |>
    list_rbind() |>
    arrange(CASE, run_index)
}

#' Eine Zeile pro Session x Modification-Run (der fünfte Run).
build_modification <- function(sessions) {
  map(sessions, \(s) {
    runs <- keep(s$runs, \(r) identical(r$kind, "modification"))
    map(runs, \(r) {
      lik <- likert_row(r$likert)
      tibble(
        CASE                = as.numeric(s$case_number),
        case_id             = n_chr(s$case_id),
        session_id          = n_chr(s$session_id),
        kind                = n_chr(r$kind),
        run_completed_at    = n_ts(r$completed_at),
        !!!lik,
        likert_mean         = mean(unlist(lik), na.rm = FALSE),
        n_turns             = length(r$transcript),
        variant             = n_chr(r$variant),
        source_run_index    = n_int(r$source_run_index),
        modified_line_index = n_int(r$modified_line_index),
        original_haiku      = n_chr(r$original_haiku),
        modified_haiku      = n_chr(r$modified_haiku),
        offen_anmerkungen   = n_chr(r$open_answers[["Anmerkungen"]]),
        offen_mitteilungen  = n_chr(r$open_answers[["Mitteilungen"]])
      )
    }) |>
      list_rbind()
  }) |>
    list_rbind() |>
    arrange(CASE)
}

#' Stapelt Writing- und Modification-Runs zu EINER Run-Tabelle.
#'
#' Beide Arten teilen sich CASE, session_id, kind, die 7 Likert-Items,
#' likert_mean und n_turns. Die jeweils art-spezifischen Spalten (topic_source,
#' ai_mode, final_haiku … bzw. variant, original_haiku, modified_haiku …) bleiben
#' bei der anderen Art leer — `kind` sagt, welche Hälfte gilt.
#'
#' `run_pos` ist die abgeleitete Position 1..5 in der Reihenfolge, in der die
#' Person die Runs durchlaufen hat. Der Export lässt run_index beim
#' Modification-Run leer (er hat keine Position im 2x2-Plan), für Sortierung und
#' Verlaufsdarstellungen ist die 5 aber genau das, was man braucht.
build_runs <- function(app_writing, app_modification) {
  bind_rows(app_writing, app_modification) |>
    mutate(run_pos = coalesce(run_index, 5L), .after = kind) |>
    arrange(CASE, run_pos)
}

#' Eine Zeile pro Session x Run x Turn — die einzige tabellarische Form, in der
#' die Transkripte auswertbar sind.
build_transcripts <- function(sessions) {
  map(sessions, \(s) {
    imap(s$runs, \(r, i) {
      turns <- r$transcript
      if (length(turns) == 0) return(NULL)
      imap(turns, \(t, j) {
        tibble(
          CASE       = as.numeric(s$case_number),
          session_id = n_chr(s$session_id),
          kind       = n_chr(r$kind),
          run_index  = n_int(r$run_index),
          turn       = j,
          role       = n_chr(t$role),
          text       = n_chr(t$text),
          at         = n_ts(t$at)
        )
      }) |>
        list_rbind()
    }) |>
      list_rbind()
  }) |>
    list_rbind() |>
    arrange(CASE, kind, run_index, turn)
}


# =============================================================================
# Lesbare Überschriften
# =============================================================================

#' Ersetzt die technischen Spaltennamen durch Klarnamen.
#'
#' Reihenfolge, in der die Quellen gewinnen (spätere überschreiben frühere):
#'   1. das SoSci-Codebook (comment()-Attribute)  -> SC01 wird "Consent"
#'   2. COLUMN_LABELS_APP                          -> App- und abgeleitete Spalten
#'   3. die ex_*-Spalten, die erst zur Laufzeit aus EXCLUSION_CRITERIA entstehen
#'   4. COLUMN_LABELS_OVERRIDE                     -> unbrauchbare Codebook-Labels
#'
#' Spalten ohne Eintrag behalten ihren Namen und werden gemeldet, damit die
#' Tabellen oben ergänzt werden können, statt dass es still durchrutscht.
readable_names <- function(df, labels) {
  lookup <- set_names(labels$label, labels$variable)
  lookup[names(COLUMN_LABELS_APP)] <- COLUMN_LABELS_APP

  ex_cols <- grep("^ex_", names(df), value = TRUE)
  if (length(ex_cols) > 0) {
    lookup[ex_cols] <- paste0("Ausschluss: ", sub("^ex_", "", ex_cols))
  }

  lookup[names(COLUMN_LABELS_OVERRIDE)] <- COLUMN_LABELS_OVERRIDE

  alt <- names(df)
  neu <- str_squish(ifelse(alt %in% names(lookup), unname(lookup[alt]), alt))

  fehlend <- alt[!alt %in% names(lookup)]
  if (length(fehlend) > 0) {
    message("  Ohne Klarnamen (bleiben technisch): ", paste(fehlend, collapse = ", "))
  }

  # Zwei Spalten mit derselben Überschrift wären beim Wiedereinlesen nicht mehr
  # auseinanderzuhalten — lieber hart abbrechen als still beschädigen.
  if (anyDuplicated(neu) > 0) {
    stop("Doppelte Überschriften nach dem Umbenennen: ",
         paste(unique(neu[duplicated(neu)]), collapse = ", "))
  }

  set_names(df, neu)
}


# =============================================================================
# Ausschlusskriterien anwenden
# =============================================================================

#' Wertet jedes Kriterium aus EXCLUSION_CRITERIA auf `df` aus und hängt an:
#'   ex_<name>        pro Kriterium eine logische Spalte
#'   ausgeschlossen   TRUE, sobald irgendein Kriterium greift
#'   ausschlussgrund  kommagetrennte Namen der greifenden Kriterien ("" = keins)
#'
#' Kriterien, deren Spalten in `df` fehlen, werden übersprungen (relevant für die
#' Nur-SoSci-Fälle, denen die App-Spalten fehlen).
apply_exclusions <- function(df, criteria = EXCLUSION_CRITERIA) {
  usable <- keep(criteria, \(q) {
    all(all.vars(rlang::quo_get_expr(q)) %in% names(df))
  })

  skipped <- setdiff(names(criteria), names(usable))
  if (length(skipped) > 0) {
    message("  Kriterien übersprungen (Spalten fehlen): ",
            paste(skipped, collapse = ", "))
  }

  # NA -> TRUE: ein Kriterium, das sich nicht entscheiden lässt, schließt aus.
  flags <- map(usable, \(q) {
    replace_na(as.logical(rlang::eval_tidy(q, data = df)), TRUE)
  })

  if (length(flags) == 0) {
    return(mutate(df, ausgeschlossen = FALSE, ausschlussgrund = ""))
  }

  namen <- names(flags)
  matrix_flags <- as.matrix(as.data.frame(flags))

  df |>
    bind_cols(set_names(as_tibble(flags), paste0("ex_", namen))) |>
    mutate(
      ausgeschlossen  = reduce(flags, `|`),
      ausschlussgrund = apply(matrix_flags, 1, \(row) paste(namen[row], collapse = ", "))
    )
}


# =============================================================================
# Schreiben
# =============================================================================

# Register der geschriebenen Dateien — speist die Übersicht am Ende des Laufs.
OUTPUTS <- new.env(parent = emptyenv())
OUTPUTS$rows <- list()

register_output <- function(datei, df, beschreibung) {
  OUTPUTS$rows <- append(OUTPUTS$rows, list(list(
    datei        = datei,
    zeilen       = nrow(df),
    spalten      = ncol(df),
    beschreibung = beschreibung
  )))
}

#' Schreibt einen Datensatz doppelt: CSV zum Reinschauen/Weitergeben (Faktoren
#' werden zu ihren deutschen Labels), RDS für R (Faktorstufen, POSIXct und
#' Attribute bleiben verlustfrei erhalten).
write_both <- function(df, name, beschreibung) {
  readr::write_csv(df, file.path(OUT_DIR, paste0(name, ".csv")), na = "")
  saveRDS(df, file.path(OUT_DIR, paste0(name, ".rds")))
  register_output(paste0(name, ".csv / .rds"), df, beschreibung)
  invisible(df)
}

#' Für Beitabellen, die kein RDS brauchen (reine Nachschlage-/Zähltabellen).
write_csv_only <- function(df, name, beschreibung) {
  readr::write_csv(df, file.path(OUT_DIR, paste0(name, ".csv")), na = "")
  register_output(paste0(name, ".csv"), df, beschreibung)
  invisible(df)
}

#' Druckt die Übersicht: welche Dateien sind entstanden und was sagen sie aus.
print_outputs <- function() {
  message("\n", strrep("=", 78))
  message("Entstandene Dateien in ", OUT_DIR)
  message(strrep("=", 78))
  for (o in OUTPUTS$rows) {
    message(sprintf("\n%s\n  %d Zeilen x %d Spalten", o$datei, o$zeilen, o$spalten))
    message(paste(strwrap(o$beschreibung, width = 74, prefix = "  "), collapse = "\n"))
  }
  message(strrep("=", 78))
}


# =============================================================================
# Ablauf
# =============================================================================

message("SoSci einlesen ...")
sosci_raw <- read_sosci(PATH_SOSCI, PATH_SOSCI_IMPORT)
labels    <- sosci_labels(sosci_raw)
sosci     <- strip_avector(sosci_raw)

message("OwnershipAshChat einlesen ...")
sessions         <- jsonlite::fromJSON(PATH_OWNERSHIP_SESSIONS, simplifyDataFrame = FALSE)
app_sessions     <- build_sessions(sessions)
app_writing      <- build_writing(sessions)
app_modification <- build_modification(sessions)
app_transcripts  <- build_transcripts(sessions)

# Der Join steht und fällt mit eindeutigen Schlüsseln auf beiden Seiten.
stopifnot(
  "CASE ist in rdata.csv nicht eindeutig"          = !any(duplicated(sosci$CASE)),
  "case_number ist in export.json nicht eindeutig" = !any(duplicated(app_sessions$CASE)),
  "CASE fehlt in rdata.csv"                        = !any(is.na(sosci$CASE)),
  "case_number fehlt in export.json"               = !any(is.na(app_sessions$CASE))
)

# --- Mengenzugehörigkeit ------------------------------------------------------
message("\nMengen bilden ...")
matched   <- inner_join(sosci, app_sessions, by = "CASE")
nur_sosci <- anti_join(sosci, app_sessions, by = "CASE")
nur_app   <- anti_join(app_sessions, sosci, by = "CASE")

# --- Ausschluss ---------------------------------------------------------------
message("\nAusschlusskriterien anwenden ...")
matched   <- apply_exclusions(matched)
nur_sosci <- apply_exclusions(nur_sosci)

eingeschlossen <- filter(matched, !ausgeschlossen)
ausgeschlossen <- filter(matched,  ausgeschlossen)

# --- Konsistenzprüfung --------------------------------------------------------
# Die SoSci-seitigen Kriterien sollten dieselben Fälle treffen wie der
# App-seitige Session-Status. Weichen sie ab, ist eine der beiden Quellen
# unvollständig — das ist ein Befund, kein Fehler, deshalb nur eine Warnung.
abweichung <- filter(matched, ausgeschlossen != (session_status != "completed"))
if (nrow(abweichung) > 0) {
  warning(
    "Ausschluss und App-Session-Status stimmen bei ", nrow(abweichung),
    " Fall/Fällen nicht überein: CASE ",
    paste(abweichung$CASE, collapse = ", "),
    call. = FALSE
  )
}

# Jede eingeschlossene Session sollte 4 Writing-Runs und einen Modification-Run
# haben — sonst fehlen der Auswertung Zellen.
unvollstaendig <- filter(eingeschlossen, n_writing_runs != 4 | !hat_modifikation)
if (nrow(unvollstaendig) > 0) {
  warning(
    "Eingeschlossene Sessions ohne vollständige 4+1 Runs: CASE ",
    paste(unvollstaendig$CASE, collapse = ", "),
    call. = FALSE
  )
}

# --- Die zusammengeführte Analysetabelle --------------------------------------
#
# Eine Zeile je Person x Run (5 pro Person), an die ALLES angehängt ist, was auf
# Personenebene gilt: Soziodemographie aus SoSci, Session-Felder aus der App,
# Ausschluss-Flags. Die Personendaten wiederholen sich dadurch je Person
# fünfmal — das ist kein Fehler, sondern das Long-Format, das gemischte Modelle
# (lmerTest) erwarten:
#
#   lmer(likert_mean ~ topic_source * ai_mode + (1 | CASE), data = d)
#
# `run_pos` gibt die Reihenfolge 1..5, `kind` trennt Writing- von
# Modification-Run.
app_runs <- build_runs(app_writing, app_modification)

# Personenebene ohne die Spalten, die schon in app_runs stecken.
personen <- select(matched, -any_of(c("case_id", "session_id")))

zusammengefuehrt <- app_runs |>
  inner_join(personen, by = "CASE") |>
  arrange(CASE, run_pos)

if (RUN_TABLES_ONLY_INCLUDED) {
  zusammengefuehrt <- filter(zusammengefuehrt, !ausgeschlossen %in% TRUE)
}

# Dieselbe Tabelle mit Klarnamen statt Variablenkürzeln — siehe readable_names().
message("\nLesbare Überschriften setzen ...")
lesbar <- readable_names(zusammengefuehrt, labels)

# Die Transkripte haben eine dritte Granularität (Person x Run x Redebeitrag).
# Sie in die Tabelle oben zu stapeln würde jeden Likert-Wert verdreifachen,
# deshalb bleiben sie eine eigene Datei.
transcripts_long <- app_transcripts |>
  left_join(select(matched, CASE, ausgeschlossen, ausschlussgrund), by = "CASE")

if (RUN_TABLES_ONLY_INCLUDED) {
  transcripts_long <- filter(transcripts_long, !ausgeschlossen %in% TRUE)
}

# --- Teilnehmerfluss ----------------------------------------------------------
# CONSORT-artige Zählung: von den Rohzeilen bis zur Analysestichprobe.
gruende <- names(EXCLUSION_CRITERIA)
grund_counts <- map_int(gruende, \(g) {
  col <- paste0("ex_", g)
  if (col %in% names(matched)) sum(matched[[col]], na.rm = TRUE) else NA_integer_
})

teilnehmerfluss <- bind_rows(
  tibble(stufe = "SoSci-Datensätze gesamt",       n = nrow(sosci)),
  tibble(stufe = "App-Sessions gesamt",           n = nrow(app_sessions)),
  tibble(stufe = "nur SoSci (ohne App-Session)",  n = nrow(nur_sosci)),
  tibble(stufe = "nur App (ohne SoSci-Zeile)",    n = nrow(nur_app)),
  tibble(stufe = "gematcht (in beiden)",          n = nrow(matched)),
  tibble(stufe = paste0("ausgeschlossen: ", gruende), n = grund_counts),
  tibble(stufe = "ausgeschlossen gesamt",         n = nrow(ausgeschlossen)),
  tibble(stufe = "eingeschlossen (Analyse)",      n = nrow(eingeschlossen)),
  tibble(stufe = "Runs gesamt (Analysetabelle)",  n = nrow(zusammengefuehrt)),
  tibble(stufe = "davon Writing-Runs",
         n = sum(zusammengefuehrt$kind == "writing")),
  tibble(stufe = "davon Modification-Runs",
         n = sum(zusammengefuehrt$kind == "modification")),
  tibble(stufe = "Redebeiträge (Transkripte)",    n = nrow(transcripts_long))
)

# --- Ausgabe ------------------------------------------------------------------
message("\nSchreiben nach ", OUT_DIR, " ...")

write_both(
  nur_sosci, "01_nur_sosci",
  paste(
    "NUR IN SOSCI. Teilnehmende mit SoSci-Zeile, aber ohne Session im",
    "OwnershipAshChat — sie haben den Fragebogen geöffnet oder begonnen, den",
    "Schreibteil aber nie erreicht. Enthält die SoSci-Spalten plus die",
    "Ausschluss-Flags; App-Spalten fehlen naturgemäß."
  )
)

write_both(
  nur_app, "02_nur_app",
  paste(
    "NUR IM OWNERSHIPASHCHAT. Sessions ohne passende SoSci-Zeile (kein CASE",
    "auf der SoSci-Seite). Ist der Datenstand konsistent, ist diese Datei",
    "leer — sie wird trotzdem geschrieben, damit die Pipeline bei jedem",
    "Snapshot dieselben Dateien erzeugt. Zeilen hier bedeuten: der Rückweg",
    "ins Befragungstool hat nicht funktioniert."
  )
)

write_both(
  matched, "03_matched",
  paste(
    "IN BEIDEN QUELLEN. SoSci-Zeile und App-Session über CASE <-> case_number",
    "verbunden, ungefiltert. Enthält je Ausschlusskriterium eine ex_*-Spalte",
    "sowie 'ausgeschlossen' und 'ausschlussgrund'. Grundlage für die beiden",
    "folgenden Dateien und der richtige Ort, um Ausschlüsse zu prüfen."
  )
)

write_both(
  eingeschlossen, "04_eingeschlossen",
  paste(
    "ANALYSESTICHPROBE AUF PERSONENEBENE. Gematchte Fälle, auf die KEIN",
    "Ausschlusskriterium zutrifft — eine Zeile je Person. Für alles, was pro",
    "Person gilt (Stichprobenbeschreibung, Soziodemographie). Für die",
    "eigentliche Auswertung siehe 06_zusammengefuehrt, das auf genau diese",
    "Fälle gefiltert ist."
  )
)

write_both(
  ausgeschlossen, "05_ausgeschlossen",
  paste(
    "AUSGESCHLOSSEN. Gematchte Fälle, auf die mindestens ein",
    "Ausschlusskriterium zutrifft. Die Spalte 'ausschlussgrund' nennt, welches",
    "— bei mehreren durch Komma getrennt. Für die Dropout-Beschreibung im",
    "Methodenteil."
  )
)

write_both(
  zusammengefuehrt, "06_zusammengefuehrt",
  paste(
    "*** DIE ANALYSETABELLE — hiermit wird gerechnet. *** Eine Zeile je Person",
    "x Run (5 pro Person: 4 Writing + 1 Modification), an die alles angehängt",
    "ist: Soziodemographie aus SoSci, Session-Felder aus der App, Bedingung,",
    "Haiku, die 7 Likert-Items und likert_mean. Die Personendaten wiederholen",
    "sich je Person fünfmal — genau das Long-Format, das gemischte Modelle",
    "brauchen: lmer(likert_mean ~ topic_source * ai_mode + (1|CASE)).",
    "'kind' trennt Writing- von Modification-Run (bei writing sind variant und",
    "original_haiku leer, bei modification topic_source und ai_mode);",
    "'run_pos' gibt die Reihenfolge 1..5. Enthält nur die eingeschlossene",
    "Stichprobe — writing_long und modification sind hierin aufgegangen und",
    "über filter(kind == ...) zu bekommen."
  )
)

write_csv_only(
  lesbar, "07_lesbar",
  paste(
    "06 MIT LESBAREN ÜBERSCHRIFTEN. Inhaltlich identisch mit",
    "06_zusammengefuehrt, nur heißt die Spalte statt 'SC01' jetzt 'Consent',",
    "statt 'SD01' 'Geschlecht' und statt 'likert_authorship' 'Ownership:",
    "Urheberschaft'. Die Namen stammen aus dem SoSci-Codebook, ergänzt um",
    "COLUMN_LABELS_APP und COLUMN_LABELS_OVERRIDE am Kopf des Skripts.",
    "Zum Anschauen, Weitergeben und für den Anhang — gerechnet wird mit 06,",
    "dessen Spaltennamen ohne Backticks ansprechbar sind. Nur als CSV, weil",
    "Überschriften mit Leerzeichen und Doppelpunkten in R unhandlich sind."
  )
)

# 07 aufgeteilt (siehe SUBSET_FILES). Gefiltert wird auf der technischen
# Tabelle, umbenannt erst danach mit derselben readable_names(), die auch 07
# erzeugt — dadurch sind die Überschriften garantiert identisch.
teil_zeilen <- c()
for (teil_name in names(SUBSET_FILES)) {
  spec <- SUBSET_FILES[[teil_name]]
  teil <- filter(zusammengefuehrt, !!spec$filter)

  if (nrow(teil) == 0) {
    warning("Teildatei ", teil_name, " ist leer — Filter prüfen.", call. = FALSE)
  }
  teil_zeilen[teil_name] <- nrow(teil)

  write_csv_only(
    readable_names(teil, labels), teil_name,
    paste(
      "TEILMENGE VON 07 —", spec$text,
      "Gleiche Spalten und Überschriften wie 07_lesbar, nur andere Zeilen;",
      "die für diese Auswahl nicht zutreffenden Spalten bleiben leer."
    )
  )
}

# Ein Tippfehler in einem Filter ("free" vs "frei") würde Zeilen verschwinden
# lassen, ohne dass es auffällt. Deshalb muss die Aufteilung aufgehen.
n_writing      <- sum(zusammengefuehrt$kind == "writing")
n_modification <- sum(zusammengefuehrt$kind == "modification")
stopifnot(
  "07a-d ergeben zusammen nicht 07f" =
    sum(teil_zeilen[c("07a_frei_mit_ki", "07b_frei_ohne_ki",
                      "07c_vorgegeben_mit_ki", "07d_vorgegeben_ohne_ki")]) == n_writing,
  "07e + 07f ergeben nicht 07" =
    n_writing + n_modification == nrow(zusammengefuehrt)
)

write_both(
  transcripts_long, "transcripts_long",
  paste(
    "EINE ZEILE JE PERSON x RUN x REDEBEITRAG. Rolle (user, ai, ai_enhanced),",
    "Text und Zeitstempel in Reihenfolge. Einzige Tabelle neben 06, weil die",
    "Transkripte eine feinere Granularität haben — in 06 gestapelt würden sie",
    "jeden Likert-Wert verdreifachen. Für Textauswertungen und um",
    "nachzuvollziehen, wer im Ping-Pong welche Zeile geschrieben hat."
  )
)

write_csv_only(
  teilnehmerfluss, "teilnehmerfluss",
  paste(
    "ZÄHLUNG DES TEILNEHMENDENFLUSSES (CONSORT-artig): von den Rohzeilen",
    "beider Quellen über die Mengenzugehörigkeit bis zur Analysestichprobe,",
    "mit einer eigenen Zeile je Ausschlusskriterium. Für das Flussdiagramm",
    "im Methodenteil."
  )
)

write_csv_only(
  labels, "variablen_labels",
  paste(
    "NACHSCHLAGETABELLE Variable -> Label aus dem SoSci-Codebook (die",
    "comment()-Attribute des Import-Scripts), damit Kürzel wie SD01 oder SC02",
    "lesbar bleiben."
  )
)

print_outputs()

message("\nTeilnehmerfluss:")
print(as.data.frame(teilnehmerfluss), row.names = FALSE)

message(
  "\nAusschlusskriterien ändern oder erweitern: EXCLUSION_CRITERIA am Kopf\n",
  "dieser Datei. Aktuell aktiv: ", paste(names(EXCLUSION_CRITERIA), collapse = ", "), "."
)
