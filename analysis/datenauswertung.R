# datenauswertung.R wertet die in merge_study_data.R erstellten Datensätze aus.

# laden der Datensätze aus merge_study_data.R
source("merge_study_data.R")

# Notwendige Libraries zur Auswertung
library(psych)

### Relibilität ###
## Cronbachs Alpha für Schreibbedingungen
psych::alpha(
  zusammengefuehrt[zusammengefuehrt$kind == "writing", 14:20]
)

## Cronbachs Alpha für Modifikationsbedingung
psych::alpha(
  zusammengefuehrt[zusammengefuehrt$kind == "modification", 14:20]
)

#################################
##### Deskriptive Statistik #####
#################################

#### Beschreibung der Stichprobe ####
### Nominale Variablen ###
# Anzahl Teilnehmende (da in Datei pro run eine Zeile)
length(unique(zusammengefuehrt$CASE))

# Geschlechterverteilung der Teilnehmenden
# Jede Person nur einmal berücksichtigen
geschlechter <- unique(zusammengefuehrt[, c("CASE", "SD01")])
# Anzahl
table(geschlechter$SD01)
# Prozent
prop.table(table(geschlechter$SD01)) * 100
# Plot
barplot(
  table(geschlechter$SD01),
  main = "Geschlechterverteilung der Teilnehmenden",
  xlab = "Geschlecht",
  ylab = "Anzahl",
  # y-Achse anpassen, Balken (34) ragt über Skala (30)
  ylim = c(0,35)
  )

# Beschäftigung der Teilnehmenden
# Jede Person nur einmal berücksichtigen
beschaeftigungen <- unique(zusammengefuehrt[, c("CASE", "SD03")])
# Anzahl
table(beschaeftigungen$SD03)
# Prozent
prop.table(table(beschaeftigungen$SD03)) * 100
# Plot
barplot(
  table(beschaeftigungen$SD03),
  main = "Beschäftigungen der Teilnehmenden",
  xlab = "Beschäftigung",
  ylab = "Anzahl",
  # y-Achse anpassen, Balken (24) ragt über Skala (20)
  ylim = c(0,25)
  )

### Ordinale Variablen ###
## KI-Erfahrung 
# Jede Person nur einmal berücksichtigen
ki_erfahrung <- unique(zusammengefuehrt[, c("CASE", "SD04")])
# KI-Erfahrung als ordinale Variable
ki_erfahrung$SD04 <- factor(
  ki_erfahrung$SD04,
  levels = c(
    "Gar keine Erfahrung",
    "Geringe Erfahrung",
    "Mäßige Erfahrung",
    "Hohe Erfahrung",
    "Sehr hohe Erfahrung"
  ),
  ordered = TRUE
)
# Anzahl
table(ki_erfahrung$SD04)
# Prozent
prop.table(table(ki_erfahrung$SD04)) * 100
# Plot
barplot(
  table(ki_erfahrung$SD04),
  main = "KI-Erfahrung der Teilnehmenden",
  xlab = "Erfahrung",
  ylab = "Anzahl",
  # y-Achse anpassen, Balken (23) ragt über Skala (20)
  ylim = c(0,25)
)
# Median
median_ki_erfahrung <- median(as.numeric(ki_erfahrung$SD04))
median_ki_erfahrung
levels(ki_erfahrung$SD04)[median_ki_erfahrung]
# Modus
modus_ki_erfahrung <- which.max(table(ki_erfahrung$SD04))
modus_ki_erfahrung # gibt Position der Kategorie aus
levels(ki_erfahrung$SD04)[modus_ki_erfahrung] # gibt Kategorie aus
table(ki_erfahrung$SD04)[modus_ki_erfahrung] # gibt Anzahl aus



## KI Nutzungshäufigkeit 
# Jede Person nur einmal berücksichtigen
ki_nutzungshaeufigkeit <- unique(zusammengefuehrt[, c("CASE", "SD05")])
# KI-Nutzungshäufigkeit als ordinale Variable
ki_nutzungshaeufigkeit$SD05 <- factor(
  ki_nutzungshaeufigkeit$SD05,
  levels = c(
    "Nie",
    "Seltener als einmal im Monat",
    "Monatlich",
    "Wöchentlich",
    "Täglich",
    "Mehrmals täglich"
  ),
  ordered = TRUE
)
# Anzahl
table(ki_nutzungshaeufigkeit$SD05)
# Prozent
prop.table(table(ki_nutzungshaeufigkeit$SD05)) * 100
# Plot
barplot(
  table(ki_nutzungshaeufigkeit$SD05),
  main = "KI-Nutzungshäufigkeit der Teilnehmenden",
  xlab = "Nutzungshäufigkeit",
  ylab = "Anzahl",
  # y-Achse anpassen, Balken (23) ragt über Skala (20)
  ylim = c(0,25)
)
# Median
median_ki_nutzungshaeufigkeit <- median(as.numeric(ki_nutzungshaeufigkeit$SD05))
median_ki_nutzungshaeufigkeit
levels(ki_nutzungshaeufigkeit$SD05)[median_ki_nutzungshaeufigkeit]
# Modus
modus_ki_nutzungshaeufigkeit <- which.max(table(ki_nutzungshaeufigkeit$SD05))
modus_ki_nutzungshaeufigkeit # gibt Position der Kategorie aus
levels(ki_nutzungshaeufigkeit$SD05)[modus_ki_nutzungshaeufigkeit] # gibt Kategorie aus
table(ki_nutzungshaeufigkeit$SD05)[modus_ki_nutzungshaeufigkeit] # gibt Anzahl aus



# Kreative Schreiberfahrung
# Jede Person nur einmal berücksichtigen
kreative_schreiberfahrung <- unique(zusammengefuehrt[, c("CASE", "SD08")])
# Kreative Schreiberfahrung als ordinale Variable
kreative_schreiberfahrung$SD08 <- factor(
  kreative_schreiberfahrung$SD08,
  levels = c(
    "Nie",
    "Selten",
    "Gelegentlich",
    "Häufig",
    "Sehr häufig"
  ),
  ordered = TRUE
)
# Anzahl
table(kreative_schreiberfahrung$SD08)
# Prozent
prop.table(table(kreative_schreiberfahrung$SD08)) * 100
# Plot
barplot(
  table(kreative_schreiberfahrung$SD08),
  main = "KI-Nutzungshäufigkeit der Teilnehmenden",
  xlab = "Nutzungshäufigkeit",
  ylab = "Anzahl",
  # y-Achse anpassen, Balken (22) ragt über Skala (20)
  ylim = c(0,25)
)
# Median
median_kreative_schreibaufgabe <- median(as.numeric(kreative_schreiberfahrung$SD08))
median_kreative_schreibaufgabe
levels(kreative_schreiberfahrung$SD08)[median_kreative_schreibaufgabe]
# Modus
modus_kreative_schreibaufgabe <- which.max(table(kreative_schreiberfahrung$SD08))
modus_kreative_schreibaufgabe # gibt Position der Kategorie aus
levels(kreative_schreiberfahrung$SD08)[modus_kreative_schreibaufgabe] # gibt Kategorie aus
table(kreative_schreiberfahrung$SD08)[modus_kreative_schreibaufgabe] # gibt Anzahl aus


# Haiku Schreiberfahrung
# Jede Person nur einmal berücksichtigen
haiku_schreiberfahrung <- unique(zusammengefuehrt[, c("CASE", "SD09")])
# Haiku Schreiberfahrung als ordinale Variable
haiku_schreiberfahrung$SD09 <- factor(
  haiku_schreiberfahrung$SD09,
  levels = c(
    "Nein",
    "Ja, ein- oder zweimal",
    "Ja, gelegentlich",
    "Ja, regelmäßig"
  ),
  ordered = TRUE
)
# Anzahl
table(haiku_schreiberfahrung$SD09)
# Prozent
prop.table(table(haiku_schreiberfahrung$SD09)) * 100
# Plot
barplot(
  table(haiku_schreiberfahrung$SD09),
  main = "KI-Nutzungshäufigkeit der Teilnehmenden",
  xlab = "Nutzungshäufigkeit",
  ylab = "Anzahl",
  # y-Achse anpassen, Balken (32) ragt über Skala (20)
  ylim = c(0,35)
)
# Median
median_haiku_schreibaufgabe <- median(as.numeric(haiku_schreiberfahrung$SD09))
median_haiku_schreibaufgabe
levels(haiku_schreiberfahrung$SD09)[median_haiku_schreibaufgabe]
# Modus
modus_haiku_schreibaufgabe <- which.max(table(haiku_schreiberfahrung$SD09))
modus_haiku_schreibaufgabe # gibt Position der Kategorie aus
levels(haiku_schreiberfahrung$SD09)[modus_haiku_schreibaufgabe] # gibt Kategorie aus
table(haiku_schreiberfahrung$SD09)[modus_haiku_schreibaufgabe] # gibt Anzahl aus


### Verhältnis Variablen ###
# Alter der Teilnehmenden
# Jede Person nur einmal berücksichtigen
alter <- unique(zusammengefuehrt[, c("CASE", "SD02_01")])
# Anzahl gültiger Angaben
sum(!is.na(alter$SD02_01))
# Mittelwert
mittelwert_alter <- mean(alter$SD02_01, na.rm = TRUE) # na.rm = TRUE, falls Altersangaben fehlen sollten
mittelwert_alter
# Standardabweichung
sd_alter <- sd(alter$SD02_01, na.rm = TRUE)
sd_alter
# Median
median_alter <- median(alter$SD02_01, na.rm = TRUE)
median_alter
# Minimum
min_alter <- min(alter$SD02_01, na.rm = TRUE)
min_alter
# Maximum
max_alter <- max(alter$SD02_01, na.rm = TRUE)
max_alter
# Histogramm
hist(
  alter$SD02_01,
  main = "Altersverteilung der Stichprobe",
  xlab = "Alter in Jahren",
  ylab = "Anzahl der Teilnehmenden"
)
# Boxplot
boxplot(
  alter$SD02_01,
  main = "Alter der Teilnehmenden",
  ylab = "Alter in Jahren"
)



#### Beschreibung der Studie #### 
### Schreibbedingungen ###
# Ownership-Scores berechnen
zusammengefuehrt$Ownership <- rowMeans(
  zusammengefuehrt[, c("likert_accountability_and_responsibility", "likert_authorship", "likert_autonomy", "likert_liking", "likert_self_efficacy", "likert_self_identity", "likert_territoriality")],
  na.rm = TRUE
)

summary(zusammengefuehrt$Ownership)
# Ownership-Scores (n, M, SD) für die 4 Schreibbedingungen
deskriptiv_schreibbedingung <- zusammengefuehrt %>%
  filter(!is.na(topic_source) & !is.na(ai_mode)) %>%
  group_by(topic_source, ai_mode) %>%
  summarise(
    n = n(),
    M = mean(Ownership, na.rm = TRUE),
    sd = sd(Ownership, na.rm = TRUE),
    .groups = "drop"
  )

deskriptiv_schreibbedingung


### Modifikationsbedingung ###
# Ownership-Scores (n, M, SD) nach der Modifikation
# Ändert: a = 1 Wort, b = 1 Zeile für bessere Lesbarkeit
deskriptiv_modifikation <- zusammengefuehrt %>%
  filter(!is.na(variant)) %>%
  mutate(
    variant_label = case_when(
      variant == "a" ~ "1 Wort",
      variant == "b" ~ "1 Zeile"
    )
  ) %>%
  group_by(variant_label) %>%
  summarise(
    n = n(),
    M = mean(Ownership, na.rm = TRUE),
    sd = sd(Ownership, na.rm = TRUE),
    .groups = "drop"
  )

deskriptiv_modifikation

# Ownership Änderung vor und nach Modifikation
# Tabelle mit ursprünglichen Schreib-Runs
writing_runs <- zusammengefuehrt %>%
  filter(kind == "writing") %>%
  select(CASE, run_index, Ownership)
# Tabelle Modifikations-Runs
modifikationen <- zusammengefuehrt %>%
  filter(kind == "modification") %>%
  select(CASE, variant, source_run_index, Ownership)
# Modifikations-Run mit ausgewählten Haiku über CASE und Run-Index verbinden
modifikation_auswertung <- modifikationen %>%
  left_join(
    writing_runs,
    by = c("CASE" = "CASE",
           "source_run_index" = "run_index"),
    suffix = c("_nach", "_vor")
  )

modifikation_auswertung

# Veränderung des Ownership-Scores durch Modifikation berechnen
# Delta Ownership: Bsp.: delta x = Endwert - Anfangswert
#                                = x_2 - x_1
modifikation_auswertung <-  modifikation_auswertung %>%
  mutate(
    delta_ownership = Ownership_nach - Ownership_vor
  )

modifikation_auswertung

# Ownership-Scores (n, M, SD, delta) vor und nach der Modifikation
deskriptive_modifikation <-  modifikation_auswertung %>%
  mutate(
    variant_label = case_when(
      variant == "a" ~ "1 Wort",
      variant == "b" ~ "1 Zeile"
    )
  ) %>%
  group_by(variant_label) %>%
  summarise(
    n = n(),
    M_vor = mean(Ownership_vor, na.rm = TRUE),
    SD_vor = sd(Ownership_vor, na.rm = TRUE),
    M_nach = mean(Ownership_nach, na.rm = TRUE),
    SD_nach = sd(Ownership_nach, na.rm = TRUE),
    M_delta = mean(delta_ownership, na.rm = TRUE),
    SD_delta = sd(delta_ownership, na.rm = TRUE),
    .groups = "drop"
  )

deskriptive_modifikation
    
# Verteilung Ownership-Score (über alle Beobachtungen) grafisch als Histogramm
hist(
  zusammengefuehrt$Ownership,
  main = "Verteilung des Ownership-Scores über alle Beobachtungen",
  xlab = "Ownership",
  ylab = "Häufigkeit"
)
# Boxplot Ownership-Score (über alle Beobachtungen)
boxplot(
  zusammengefuehrt$Ownership,
  main = "Ownership-Scores über alle Beobachtungen",
  ylab = "Ownership"
)

# Verteilung Ownership-Scores über die Schreibbedingung grafisch als Histogramm
hist(
  zusammengefuehrt$Ownership[zusammengefuehrt$kind == "writing"],
  main = "Verteilung des Ownership-Scores in den Schreib-Bedingungen",
  xlab = "Ownership",
  ylab = "Häufigkeit"
)
# Boxplot Ownership-Scores über die Schreib-Bedingungen
boxplot(
  zusammengefuehrt$Ownership[zusammengefuehrt$kind == "writing"],
  main = "Ownership-Scores in den Schreib-Bedingungen",
  ylab = "Ownership"
)

# Verteilung des Ownership-Scores über die Modifikations-Bedingung grafisch als Histogramm
hist(
  zusammengefuehrt$Ownership[zusammengefuehrt$kind == "modification"],
  main = "Verteilung der Ownership-Scores in der Modifikations-Bedingung",
  xlab = "Ownership",
  ylab = "Häufigkeit"
)
# Boxplot Ownership-Scores über die Modifikations-Bedingung
boxplot(
  zusammengefuehrt$Ownership[zusammengefuehrt$kind == "modification"],
  main = "Ownership-Scores in der Modifikations-Bedingung"
)

# Boxplots über die 4 Schreib-Bedingungs-Kombinationen
boxplot(
  Ownership ~ topic_source * ai_mode,
  data = zusammengefuehrt[zusammengefuehrt$kind == "writing"],
  main = "Ownership nach Thema und KI-Bedingung",
  xlab = "Thema und KI-Bedingung",
  ylab = "Ownership"
)

#############################
##### Inferenzstatistik #####
#############################

