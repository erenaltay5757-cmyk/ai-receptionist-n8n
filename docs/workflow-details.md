# Ablauf im Detail

Diese Seite beschreibt die beiden n8n-Workflows genauer. Die Node-Namen sind genauso geschrieben wie im Workflow, damit man sie in n8n wiederfindet.

## 1. Hauptworkflow „AI Receptionist MVP – SHK“

Datei: [`workflows/ai-receptionist-main.json`](../workflows/ai-receptionist-main.json), 99 Nodes

### Eingänge

| Trigger | Kanal | Was er macht |
|---|---|---|
| `Vapi-Telefonassistent` (Webhook) | Telefon | Empfängt am Ende des Anrufs den Gesprächsbericht von Vapi. |
| `Vapi-Terminfunktionen` (Webhook) | Telefon | Empfängt während des Gesprächs die Werkzeugaufrufe des Voice-Assistenten (Termine prüfen oder buchen). Abgesichert mit Header-Authentifizierung. |
| `Website-Anfrage – Demo` (n8n Form) | Website | Formular mit Name, Telefon, PLZ, Ort, Adresse und Anliegen. |
| `Schedule Trigger` | WhatsApp | Ruft alle 10 Minuten neue Nachrichten über die Twilio-API ab (Testzugang). |
| `Error Trigger` | – | Startet, wenn eine Ausführung fehlschlägt. |
| `Prüfung starten` (manuell) | – | Prüft vor dem Start, ob alle Einstellungen gesetzt sind. Es werden keine Kundendaten verarbeitet. |

Alle Trigger laufen zuerst durch `Betriebskonfiguration`. Dort stehen alle betriebsspezifischen Werte an einer Stelle: Firmenname, Texte, Einsatzgebiet und Terminregeln. Danach verteilt der Switch `Eingangskanal` auf den richtigen Weg.

### Weg einer Anfrage

1. **Kanal vereinheitlichen.** Jeder Kanal wird in dieselben Felder übersetzt, zum Beispiel `anfrage_id`, `quelle`, `name`, `telefon`, `plz`, `ort`, `adresse` und `technisches_anliegen`. Bei WhatsApp werden mehrere Nachrichten derselben Nummer zu einer Anfrage gebündelt (`WhatsApp-Nachrichten je Nummer bündeln`).
2. **Duplikate abfangen.** `Vapi-Eingang prüfen/erfassen` und `WhatsApp-Eingänge prüfen/erfassen` vermerken jede technische ID in der Tabelle `eingaenge`. Was schon den Status `verarbeitet` hat, wird übersprungen.
3. **Kontaktdaten von der KI trennen.** Der Ablauf teilt sich in zwei Wege:
   - Weg A, `Kontaktdaten behalten`: Name, Telefon, Ort und Adresse bleiben im Workflow.
   - Weg B, `KI-Eingabe minimieren`: Nur das Anliegen geht weiter. Vorher entfernt das System bekannte Namen, Telefonnummern, E-Mail-Adressen und Straßenangaben aus dem Text.
4. **KI-Analyse.** `Anfrage mit KI analysieren` (n8n Information Extractor mit OpenAI-Modell) liefert feste Textfelder: `kategorie`, `dringlichkeit`, `hersteller`, `geraet`, `fehlercode`, `warmwasser` und `fehlende_informationen`.
   Bei Telefonanrufen liefert Vapi diese Felder schon im strukturierten Gesprächsbericht. Dann überspringt das System die zweite Analyse (`Structured Output vorhanden?`).
5. **Zusammenführen und prüfen.** `Daten zusammenführen` verbindet beide Wege wieder über die `anfrage_id`. `Daten vereinheitlichen` setzt danach feste Regeln durch:
   - nur erlaubte Kategorien und Dringlichkeiten
   - ein ausdrücklich verneinter Notfall wird herabgestuft
   - eine erkannte Wassergefahr wird immer als Wasserschaden eingestuft
   - Telefonnummern bekommen ein einheitliches Format (+49 …)
6. **Speichern in Supabase.**
   - `Kunde suchen`: Suche über die normalisierte Telefonnummer. Wenn es keinen Treffer gibt, legt `Kunde anlegen` den Kunden neu an.
   - `Anfrage zum Vorgang suchen` → `Bestehende Anfrage?`: Gibt es den Vorgang schon (z. B. eine weitere WhatsApp-Nachricht), wird er ergänzt (`Anfrage ergänzen`), sonst neu gespeichert (`Anfrage speichern`). Leere neue Werte überschreiben keine vorhandenen.
   - `Mitarbeiterprüfung anlegen/aktualisieren`: eine Aufgabe vom Typ `anfrage_pruefen` mit Titel, Priorität und Beschreibung.
7. **Erst nach erfolgreichem Speichern** (`Speicherung erfolgreich`) läuft `Benachrichtigung vorbereiten`. Von dort verzweigt der Ablauf:
   - **Mitarbeiter-E-Mail** mit Rückrufnummer als Link, Kategorie, Gerät, fehlenden Angaben und rotem Notfall-Banner (Outlook-Node, deaktiviert).
   - **`Notfall?`** → `Bereitschaft alarmieren` (WhatsApp an die Bereitschaft, deaktiviert).
   - **WhatsApp-Antwort:** `WhatsApp-Antwort formulieren` (KI) → `KI-Antwort prüfen`. Das ist eine Leitplanke: Enthält die Antwort Uhrzeiten, Wochentage, Preise, Zusagen oder Kontaktdaten, ersetzt das System sie durch einen freigegebenen Standardtext. Sicherheitstexte, die noch als „ENTWURF“ markiert sind, gehen nie an Kunden. Der Versand selbst ist deaktiviert.
   - **Website:** Bestätigungsseite oder direkt Terminauswahl (siehe unten).
   - `Eingang als verarbeitet markieren`.

### Termine im Website-Formular

`Automatische Terminierung versuchen?` → `Terminassistent: Vorschläge (Website)` ruft den Unterworkflow auf. Gibt es passende Termine, wählt der Kunde im Formular `Terminauswahl (Website)` einen aus oder lehnt alle ab. `Terminergebnis auswerten (Website)` zeigt dann das Ergebnis, neue Vorschläge oder die Frage nach einem Wunschzeitraum.

### Termine während des Anrufs

Vapi ruft `Vapi-Terminfunktionen` auf. Für jeden Anruf entsteht genau ein Datensatz in `anfragen` (`Anruf-Anfrage suchen` → `anlegen`), auch wenn zwei Aufrufe gleichzeitig kommen. `Telefonfunktion wählen` leitet dann auf die Terminprüfung oder die Buchung weiter. Die Antwort an den Voice-Assistenten baut `Vapi-Antwort vorbereiten`. Sie enthält nur die Termine, die der Unterworkflow wirklich geliefert hat.

## 2. Unterworkflow „AI Terminassistent – SHK“

Datei: [`workflows/ai-terminassistent-subworkflow.json`](../workflows/ai-terminassistent-subworkflow.json), 60 Nodes

Der Hauptworkflow ruft diesen Unterworkflow auf. Er arbeitet für alle Kanäle gleich und kennt diese Aktionen: `vorschlagen`, `bestaetigen`, `kundenantwort`, `anzeigen`, `verschieben`, `stornieren`, `verfuegbarkeit` und `direkt_buchen`.

- **Terminkonfiguration:** Öffnungszeiten, Pausen, Puffer, Vorlaufzeit, maximale Termine pro Tag und Terminarten mit Dauer. Diese Werte kann jeder Betrieb in der Betriebskonfiguration überschreiben.
- **Eignung prüfen:** Prüft, ob die Anfrage automatisch terminiert werden darf. Dazu müssen Dringlichkeit, Terminart und Einsatzgebiet (PLZ oder Ort) passen und alle nötigen Angaben vorhanden sein. Notfälle, Angebote und Großaufträge gehen immer an einen Menschen.
- **Termine berechnen:** Freie Zeitfenster nach Öffnungszeiten minus belegter Termine, ein Vorschlag pro Tag.
- **Reservieren und Buchen:** Ein Termin wird zuerst reserviert und danach gebucht. Eine Datenbankregel verhindert, dass sich zwei Termine derselben Ressource überschneiden, auch bei gleichzeitigen Anfragen. Abgelaufene Reservierungen werden wieder freigegeben.
- **Ablehnung:** Lehnt der Kunde zweimal alle Vorschläge ab, fragt das System nach einem Wunschzeitraum und legt eine Aufgabe für Mitarbeitende an.
- **Kalender:** Getestet wurde mit einem Testkalender. Die Outlook-Anbindung ist vorbereitet, aber deaktiviert.
- **Testmodus:** Im Modus `test` wird nichts dauerhaft gebucht.

## Was bewusst deaktiviert ist

| Node | Grund |
|---|---|
| `Mitarbeiter per E-Mail informieren`, `Mitarbeiter über Termin informieren`, `Fehleralarm senden` | Es ist kein echtes Postfach angebunden. |
| `WhatsApp-Antwort senden`, `Bereitschaft alarmieren` | Es gibt keinen produktiven WhatsApp-Absender. Es sollen keine echten Nachrichten verschickt werden. |
| `Outlook-Kalender lesen` / `Outlook-Termin …` | Statt eines echten Kalenders wird der Testkalender genutzt. |
