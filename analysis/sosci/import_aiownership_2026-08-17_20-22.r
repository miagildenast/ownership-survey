# Dieses Script liest eine CSV-Datendatei in GNU R ein.
# Beim Einlesen werden für alle Variablen Beschriftungen (comment) angelegt.
# Die Beschriftungen für Werte wird ebenfalls als Attribute (attr) abgelegt.

ds_file = file.choose()
# setwd("./")
# ds_file = "rdata_aiownership_2026-08-17_20-22.csv"

options(encoding = "UTF-8")
ds = read.delim(
  file=ds_file, encoding="UTF-8", fileEncoding="UTF-8",
  header = FALSE, sep = "\t", quote = "\"",
  dec = ".", row.names = NULL,
  col.names = c(
    "CASE","SERIAL","REF","QUESTNNR","MODE","STARTED","SC01","SC02","SD01",
    "SD02_01","SD03","SD03_08","SD04","SD05","SD06","SD06_01","SD06_02","SD06_03",
    "SD06_04","SD06_05","SD06_05a","SD07_01","SD08","SD09","TIME001","TIME002",
    "TIME003","TIME004","TIME_SUM","MAILSENT","LASTDATA","STATUS","FINISHED",
    "Q_VIEWER","LASTPAGE","MAXPAGE","MISSING","MISSREL","TIME_RSI"
  ),
  as.is = TRUE,
  colClasses = c(
    CASE="numeric", SERIAL="character", REF="character", QUESTNNR="character",
    MODE="factor", STARTED="POSIXct", SC01="numeric", SC02="numeric",
    SD01="numeric", SD02_01="numeric", SD03="numeric", SD03_08="character",
    SD04="numeric", SD05="numeric", SD06="numeric", SD06_01="logical",
    SD06_02="logical", SD06_03="logical", SD06_04="logical", SD06_05="logical",
    SD06_05a="character", SD07_01="character", SD08="numeric", SD09="numeric",
    TIME001="integer", TIME002="integer", TIME003="integer", TIME004="integer",
    TIME_SUM="integer", MAILSENT="POSIXct", LASTDATA="POSIXct",
    STATUS="character", FINISHED="logical", Q_VIEWER="logical",
    LASTPAGE="numeric", MAXPAGE="numeric", MISSING="numeric", MISSREL="numeric",
    TIME_RSI="numeric"
  ),
  skip = 1,
  check.names = TRUE, fill = TRUE,
  strip.white = FALSE, blank.lines.skip = TRUE,
  comment.char = "",
  na.strings = ""
)

row.names(ds) = ds$CASE

rm(ds_file)

attr(ds, "project") = "aiownership"
attr(ds, "description") = "Dein, mein, unser? Eine Studie zu kreativem Schreiben, KI und Ideenursprung"
attr(ds, "date") = "2026-08-17 20:22:00"
attr(ds, "server") = "https://www.sosci.uni-hamburg.de"

# Variable und Value Labels
ds$SC01 = factor(ds$SC01,
    levels=c("1","-9"),
    labels=c("Hiermit bestätige ich, dass ich alle Informationen zur Studie vollständig gelesen und die Datenschutzinformation zur Kenntnis genommen habe.","[NA] nicht beantwortet"),
    ordered=FALSE)
ds$SC02 = factor(ds$SC02,
    levels=c("1","-9"),
    labels=c("Absenden","[NA] nicht beantwortet"),
    ordered=FALSE)
ds$SD01 = factor(ds$SD01,
    levels=c("1","2","3","4","-9"),
    labels=c("weiblich","männlich","divers","keine Angabe","[NA] nicht beantwortet"),
    ordered=FALSE)
ds$SD03 = factor(ds$SD03,
    levels=c("1","2","3","4","5","6","7","8","-9"),
    labels=c("Schüler/in","In Ausbildung","Student/in","Angestellte/r","Beamte/r","Selbstständig","Arbeitslos/Arbeit suchend","Sonstiges:","[NA] nicht beantwortet"),
    ordered=FALSE)
ds$SD04 = factor(ds$SD04,
    levels=c("1","2","3","4","5","-9"),
    labels=c("Gar keine Erfahrung","Geringe Erfahrung","Mäßige Erfahrung","Hohe Erfahrung","Sehr hohe Erfahrung","[NA] nicht beantwortet"),
    ordered=FALSE)
ds$SD05 = factor(ds$SD05,
    levels=c("1","2","3","4","5","6","-9"),
    labels=c("Nie","Seltener als einmal im Monat","Monatlich","Wöchentlich","Täglich","Mehrmals täglich","[NA] nicht beantwortet"),
    ordered=FALSE)
ds$SD08 = factor(ds$SD08,
    levels=c("1","2","3","4","5","-9"),
    labels=c("Nie","Selten","Gelegentlich","Häufig","Sehr häufig","[NA] nicht beantwortet"),
    ordered=FALSE)
ds$SD09 = factor(ds$SD09,
    levels=c("1","2","3","4","-9"),
    labels=c("Nein","Ja, ein- oder zweimal","Ja, gelegentlich","Ja, regelmäßig","[NA] nicht beantwortet"),
    ordered=FALSE)
attr(ds$SD06_01,"F") = "nicht gewählt"
attr(ds$SD06_01,"T") = "ausgewählt"
attr(ds$SD06_02,"F") = "nicht gewählt"
attr(ds$SD06_02,"T") = "ausgewählt"
attr(ds$SD06_03,"F") = "nicht gewählt"
attr(ds$SD06_03,"T") = "ausgewählt"
attr(ds$SD06_04,"F") = "nicht gewählt"
attr(ds$SD06_04,"T") = "ausgewählt"
attr(ds$SD06_05,"F") = "nicht gewählt"
attr(ds$SD06_05,"T") = "ausgewählt"
attr(ds$STATUS,"complete") = "Interview vollständig"
attr(ds$STATUS,"finished") = "Interview abgeschlossen (letzte Seite erreicht)"
attr(ds$STATUS,"quality fail") = "Als ungültiger Datensatz markiert"
attr(ds$STATUS,"quota full") = "Aufgrund eines Quotenstopps abgewiesen"
attr(ds$STATUS,"screenout") = "Aufgrund der Auswahlkritiern abgewiesen"
attr(ds$FINISHED,"F") = "abgebrochen"
attr(ds$FINISHED,"T") = "ausgefüllt"
attr(ds$Q_VIEWER,"F") = "Teilnehmer"
attr(ds$Q_VIEWER,"T") = "Durchklicker"
comment(ds$SERIAL) = "Personenkennung oder Teilnahmecode (sofern verwendet)"
comment(ds$REF) = "Referenz (sofern im Link angegeben)"
comment(ds$QUESTNNR) = "Fragebogen, der im Interview verwendet wurde"
comment(ds$MODE) = "Interview-Modus"
comment(ds$STARTED) = "Zeitpunkt zu dem das Interview begonnen hat (Europe/Berlin)"
comment(ds$SC01) = "Consent"
comment(ds$SC02) = "Debrief"
comment(ds$SD01) = "Geschlecht"
comment(ds$SD02_01) = "Alter (direkt): Ich bin   ... Jahre"
comment(ds$SD03) = "Beschäftigung"
comment(ds$SD03_08) = "Beschäftigung: Sonstiges"
comment(ds$SD04) = "KI-Erfahrung"
comment(ds$SD05) = "Nutzungshäufigkeit KI"
comment(ds$SD06) = "KI Anwendungsbereiche: Ausweichoption (negativ) oder Anzahl ausgewählter Optionen"
comment(ds$SD06_01) = "KI Anwendungsbereiche: Studium"
comment(ds$SD06_02) = "KI Anwendungsbereiche: Beruf"
comment(ds$SD06_03) = "KI Anwendungsbereiche: Schule"
comment(ds$SD06_04) = "KI Anwendungsbereiche: Freizeit"
comment(ds$SD06_05) = "KI Anwendungsbereiche: Sonstiges"
comment(ds$SD06_05a) = "KI Anwendungsbereiche: Sonstiges (offene Eingabe)"
comment(ds$SD07_01) = "KI Aufgabenbereiche: [01]"
comment(ds$SD08) = "Kreatvies Schreiben"
comment(ds$SD09) = "Haiku-Erfahrung"
comment(ds$TIME001) = "Verweildauer Seite 1"
comment(ds$TIME002) = "Verweildauer Seite 2"
comment(ds$TIME003) = "Verweildauer Seite 3"
comment(ds$TIME004) = "Verweildauer Seite 4"
comment(ds$TIME_SUM) = "Verweildauer gesamt (ohne Ausreißer)"
comment(ds$MAILSENT) = "Versandzeitpunkt der Einladungsmail (nur für nicht-anonyme Adressaten)"
comment(ds$LASTDATA) = "Zeitpunkt als der Datensatz das letzte mal geändert wurde"
comment(ds$STATUS) = "Status des Interviews (Markierung)"
comment(ds$FINISHED) = "Wurde die Befragung abgeschlossen (letzte Seite erreicht)?"
comment(ds$Q_VIEWER) = "Hat der Teilnehmer den Fragebogen nur angesehen, ohne die Pflichtfragen zu beantworten?"
comment(ds$LASTPAGE) = "Seite, die der Teilnehmer zuletzt bearbeitet hat"
comment(ds$MAXPAGE) = "Letzte Seite, die im Fragebogen bearbeitet wurde"
comment(ds$MISSING) = "Anteil fehlender Antworten in Prozent"
comment(ds$MISSREL) = "Anteil fehlender Antworten (gewichtet nach Relevanz)"
comment(ds$TIME_RSI) = "Ausfüll-Geschwindigkeit (relativ)"



# Assure that the comments are retained in subsets
as.data.frame.avector = as.data.frame.vector
`[.avector` <- function(x,i,...) {
  r <- NextMethod("[")
  mostattributes(r) <- attributes(x)
  r
}
ds_tmp = data.frame(
  lapply(ds, function(x) {
    structure( x, class = c("avector", class(x) ) )
  } )
)
mostattributes(ds_tmp) = attributes(ds)
ds = ds_tmp
rm(ds_tmp)

