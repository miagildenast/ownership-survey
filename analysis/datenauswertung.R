# datenauswertung.R wertet die in merge_study_data.R erstellten Datensätze aus.

# laden der Datensätze aus merge_study_data.R
source("merge_study_data.R")

# Notwendige Libraries zur Auswertung
library(psych)
library(afex)
library(emmeans)

#######################
##### Reliabilität #####
#######################

## Cronbachs Alpha der 7 Ownership-Items für Schreibbedingungen
psych::alpha(
  zusammengefuehrt[zusammengefuehrt$kind == "writing", 14:20]
)

## Cronbachs Alpha der 7 Ownership-Items für Modifikationsbedingung
psych::alpha(
  zusammengefuehrt[zusammengefuehrt$kind == "modification", 14:20]
)


#################################
##### Deskriptive Statistik #####
#################################


##### Stichprobe ######

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



##### Ownership #####

# Ownership-Scores aus den 7 Items berechnen
# Der Score wird für Schreibbedingungen und Modifikation (also alle Runs) berechnet
zusammengefuehrt$Ownership <- rowMeans(
  zusammengefuehrt[, c(
    "likert_accountability_and_responsibility", 
    "likert_authorship", 
    "likert_autonomy", 
    "likert_liking", 
    "likert_self_efficacy", 
    "likert_self_identity", 
    "likert_territoriality"
    )],
  na.rm = TRUE
)
# Übersicht Ownership-Scores über alle Runs
summary(zusammengefuehrt$Ownership)


### Schreibbedingungen ###

# Ownership-Scores (n, M, SD) für die 4 Schreibbedingungen
deskriptiv_schreibbedingung <- zusammengefuehrt %>%
  filter(kind == "writing") %>%
  mutate(
    topic_label = case_when(
      topic_source == "free" ~ "Freies Thema",
      topic_source == "assigned" ~ "Vorgegebenes Thema"
    ),
    ai_label = case_when(
      ai_mode == "with_ai" ~ "Mit KI",
      ai_mode == "without_ai" ~ "Ohne KI"
    )
  ) %>%
  group_by(topic_label, ai_label) %>%
  summarise(
    n = n(),
    M = mean(Ownership, na.rm = TRUE),
    SD = sd(Ownership, na.rm = TRUE),
    .groups = "drop"
  )

deskriptiv_schreibbedingung

# M und SD der einzelnen Ownership-Items für die Schreibbedingungen
ownership_items <- zusammengefuehrt %>%
  filter(kind == "writing") %>%
  summarise(
    M_Accountability = mean(likert_accountability_and_responsibility, na.rm = TRUE),
    SD_Accountability = sd(likert_accountability_and_responsibility, na.rm = TRUE),
    
    M_Authorship = mean(likert_authorship, na.rm = TRUE),
    SD_Authorship = sd(likert_authorship, na.rm = TRUE),
    
    M_Autonomy = mean(likert_autonomy, na.rm = TRUE),
    SD_Autonomy = sd(likert_autonomy, na.rm = TRUE),
    
    M_Liking = mean(likert_liking, na.rm = TRUE),
    SD_Liking = sd(likert_liking, na.rm = TRUE),
    
    M_Self_Efficacy = mean(likert_self_efficacy, na.rm = TRUE),
    SD_Self_Efficacy = sd(likert_self_efficacy, na.rm = TRUE),
    
    M_Self_Identity = mean(likert_self_identity, na.rm = TRUE),
    SD_Self_Identity = sd(likert_self_identity, na.rm = TRUE),
    
    M_Territoriality = mean(likert_territoriality, na.rm = TRUE),
    SD_Territoriality = sd(likert_territoriality, na.rm = TRUE)
  )

ownership_items

##### Modifikation #####

# Ownership-Scores (n, M, SD) nach der Modifikation
# Ändert: a = 1 Wort, b = 1 Zeile für bessere Lesbarkeit
deskriptiv_modifikation <- zusammengefuehrt %>%
  filter(kind == "modification") %>%
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
    by = c(
      "CASE" = "CASE",
           "source_run_index" = "run_index"
           ),
    suffix = c("_nach", "_vor")
  ) %>%
  mutate(
    # Veränderung des Ownership-Scores durch Modifikation berechnen
    # Delta Ownership: Bsp.: delta x = Endwert - Anfangswert
    #                                = x_2 - x_1
    delta_ownership = Ownership_nach - Ownership_vor,
    # Ändert: a = 1 Wort, b = 1 Zeile für bessere Lesbarkeit
    variant_label = factor(
      variant,
      levels = c("a", "b"),
      labels = c("1 Wort", "1 Zeile")
    )
  )

modifikation_auswertung

# Ownership-Scores (n, M, SD, delta) vor und nach der Modifikation
deskriptive_modifikation <-  modifikation_auswertung %>%
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

#Verteilung der Ownership-Veränderung (Delta) getrennt nach Modifikationsart
tapply(
  modifikation_auswertung$delta_ownership, #Was?
  modifikation_auswertung$variant_label, # Nach welcher Gruppe?
  summary # Was damit machen?
)
 

#############################
##### Inferenzstatistik #####
#############################

##### Schreibbedingungen#####
# 2x2 Analyse

schreibdaten <-  zusammengefuehrt %>% 
  filter(kind == "writing") %>%
  select(CASE, topic_source, ai_mode, Ownership)

# Faktoren beschriften
schreibdaten <-  schreibdaten %>%
  mutate(
    topic = factor(
      topic_source,
      levels = c("free", "assigned"),
      labels = c("Freies Thema", "Vorgegebenes Thema")
    ),
    ai = factor(
      ai_mode,
      levels = c("without_ai", "with_ai"),
      labels = c("Ohne KI", "Mit KI")
    )
  )

# 2x2 Repeated Measures ANOVA Schreibbedingungen
anova_schreibbedingungen <- aov_ez(
  id = "CASE",
  dv = "Ownership",
  data = schreibdaten,
  within = c("topic", "ai")
)

anova_schreibbedingungen

# Simple Effects / Paarvergleiche für mit vs ohne KI
emmeans_ai <- emmeans(
  anova_schreibbedingungen,
  ~ ai | topic
)

emmeans_ai

pairs(emmeans_ai)

# Simple Effects / Paarvergleich für freies vs vorgegebenes Thema
emmeans_topic <- emmeans(
  anova_schreibbedingungen,
  ~ topic | ai
)

emmeans_topic

pairs(emmeans_topic)

# Residuen der ANOVA
residuen <- residuals(anova_schreibbedingungen$lm)

#QQPlots
qqnorm(residuen)
qqline(residuen)

# Normalvertilung Residuen
shapiro.test(residuen)

summary(residuen)

############ Sensitivitätsanalyse 
# Zeilennummern der Ausreißer
which(residuen %in% boxplot.stats(residuen)$out)

# Teilnehmende + Bedingung
ausreisser <-  which(residuen %in% boxplot.stats(residuen)$out)
schreibdaten[ausreisser, ]

# Datensatz ohne Ausreißer
schreibdaten_ohne_ausreisser <- schreibdaten[-ausreisser, ]

# ANOVA ohne Ausreißer
anova_ohne_ausreisser <- aov_ez(
  id = "CASE",
  dv = "Ownership",
  data = schreibdaten_ohne_ausreisser,
  within = c("topic", "ai")
)
anova_ohne_ausreisser

# Levene Test
car::leveneTest(
  Ownership ~ interaction(topic, ai),
  data = schreibdaten
)

##### Modifikation ##### 
# Shapiro-Wilk-Test zur Überprüfung der Normalverteilung
shapiro.test(
  modifikation_auswertung$delta_ownership[
    modifikation_auswertung$variant_label == "1 Wort"
  ]
)
shapiro.test(
  modifikation_auswertung$delta_ownership[
    modifikation_auswertung$variant_label == "1 Zeile"
  ]
)

# Wilcoxon-Test bei nicht-normalverteilten Daten
wilcox.test(
  delta_ownership ~ variant_label,
  data = modifikation_auswertung
)

# Vergleich Ownership-Veränderung 1 Wort vs. 1 Zeile mit t-Test
t_test_modifikation <- t.test(
  delta_ownership ~ variant_label,
  data = modifikation_auswertung
)

t_test_modifikation

   
##### Grafiken #####
# Histogramme
# Verteilung Ownership-Score (über alle Beobachtungen) grafisch als Histogramm
hist(
  zusammengefuehrt$Ownership,
  main = "Verteilung des Ownership-Scores über alle Beobachtungen",
  xlab = "Ownership",
  ylab = "Häufigkeit"
)

# Verteilung Ownership-Scores über die Schreibbedingung grafisch als Histogramm
hist(
  schreibdaten$Ownership,
  main = "Verteilung des Ownership-Scores in den Schreib-Bedingungen",
  xlab = "Ownership",
  ylab = "Häufigkeit"
)

# Histogramme der 4 Schreibbedingungen in einem Raster
par(mfrow = c(2,2)) # Histogramme werden als 2x2 dargestellt

hist(
  schreibdaten$Ownership[
    schreibdaten$topic == "Freies Thema" & schreibdaten$ai =="Ohne KI"
    ],
  main = "Freies Thema – Ohne KI",
  xlab = "Ownership",
  ylab = "Häufigkeit"
)
hist(
  schreibdaten$Ownership[
    schreibdaten$topic == "Freies Thema" & schreibdaten$ai == "Mit KI"
  ],
  main = "Freies Thema – Mit KI",
  xlab = "Ownerhsip",
  ylab = "Häufigkeit"
)
hist(
  schreibdaten$Ownership[
    schreibdaten$topic == "Vorgegebenes Thema" & schreibdaten$ai =="Ohne KI"
  ],
  main = "Vorgegebenes Thema – Ohne KI",
  xlab = "Ownership",
  ylab = "Häufigkeit"
)
hist(
  schreibdaten$Ownership[
    schreibdaten$topic == "Vorgegebenes Thema" & schreibdaten$ai == "Mit KI"
  ],
  main = "Vorgegebenes Thema – Mit KI",
  xlab = "Ownerhsip",
  ylab = "Häufigkeit"
)

par(mfrow = c(1,1)) # 2x2 Darstellung wird für spätere Grafiken zurückgesetzt

# Verteilung des Ownership-Scores über die Modifikations-Bedingung grafisch als Histogramm
hist(
  zusammengefuehrt$Ownership[zusammengefuehrt$kind == "modification"],
  main = "Verteilung der Ownership-Scores in der Modifikations-Bedingung",
  xlab = "Ownership",
  ylab = "Häufigkeit"
)

# Boxplots
# Boxplot Ownership-Score (über alle Beobachtungen)
boxplot(
  zusammengefuehrt$Ownership,
  main = "Ownership-Scores über alle Beobachtungen",
  ylab = "Ownership"
)

# Boxplot Ownership-Scores über die Schreib-Bedingungen
boxplot(
  schreibdaten$Ownership,
  main = "Ownership-Scores in den Schreibbedingungen",
  ylab = "Ownership"
)

# Boxplots der 4 Schreibbedingungen
boxplot(
  Ownership ~ topic * ai,
  data = schreibdaten,
  main = "Ownership nach Thema und KI-Bedingung",
  xlab = "Thema und KI-Bedingung",
  ylab = "Ownership"
)

# Boxplot Ownership-Scores über die Modifikations-Bedingung
boxplot(
  zusammengefuehrt$Ownership[zusammengefuehrt$kind == "modification"],
  main = "Ownership-Scores in der Modifikations-Bedingung",
  ylab = "Ownership"
)

# Boxplot Veränderung des Ownership-Scores nach Modifikationsart (1 Wort vs. 1 Zeile)
boxplot(
  delta_ownership ~ variant_label,
  data = modifikation_auswertung,
  main = "Veränderung des Ownership-Scores nach Modifikationsart",
  xlab = "Modifikationsart",
  ylab = "Delta Ownership"
)

# Q-Q-Plots
#Q-Q-Plots für die 4 Schreibbedingungen
par(mfrow = c(2,2))

qqnorm(
  schreibdaten$Ownership[
    schreibdaten$topic == "Freies Thema" & schreibdaten$ai == "Ohne KI"
  ],
  main = "Freies Thema – Ohne KI"
)
qqline(
  schreibdaten$Ownership[
    schreibdaten$topic == "Freies Thema" & schreibdaten$ai == "Ohne KI"
  ]
)
qqnorm(
  schreibdaten$Ownership[
    schreibdaten$topic == "Freies Thema" & schreibdaten$ai == "Mit KI"
  ],
  main = "Freies Thema – Mit KI"
)
qqline(
  schreibdaten$Ownership[
    schreibdaten$topic == "Freies Thema" & schreibdaten$ai == "Mit KI"
  ]
)
qqnorm(
  schreibdaten$Ownership[
    schreibdaten$topic == "Vorgegebenes Thema" & schreibdaten$ai == "Ohne KI"
  ],
  main = "Vorgegebenes Thema – Ohne KI"
)
qqline(
  schreibdaten$Ownership[
    schreibdaten$topic == "Vorgegebenes Thema" & schreibdaten$ai == "Ohne KI"
  ]
)
qqnorm(
  schreibdaten$Ownership[
    schreibdaten$topic == "Vorgegebenes Thema" & schreibdaten$ai == "Mit KI"
  ],
  main = "Vorgegebenes Thema – Mit KI"
)
qqline(
  schreibdaten$Ownership[
    schreibdaten$topic == "Vorgegebenes Thema" & schreibdaten$ai == "Mit KI"
  ]
)

par(mfrow = c(1,1))

# Q-Q-Plot für Delta-Ownership nach Modifikationsart
par(mfrow = c(1,2))

qqnorm(
  modifikation_auswertung$delta_ownership[
    modifikation_auswertung$variant_label == "1 Wort"
  ], 
  main = "1 Wort"
)
qqline(
  modifikation_auswertung$delta_ownership[
    modifikation_auswertung$variant_label == "1 Wort"
  ]
)

qqnorm(
  modifikation_auswertung$delta_ownership[
    modifikation_auswertung$variant_label == "1 Zeile"
  ],
  main = "1 Zeile"
)
qqline(
  modifikation_auswertung$delta_ownership[
    modifikation_auswertung$variant_label == "1 Zeile"
  ]
)

par(mfrow = c(1,1))