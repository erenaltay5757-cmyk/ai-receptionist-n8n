# Datenmodell (Supabase / PostgreSQL)

Alle Tabellen haben eine Spalte `betrieb_id`. So könnte dieselbe Datenbank später mehrere Betriebe getrennt verwalten.

```mermaid
erDiagram
    kunden ||--o{ anfragen : stellt
    anfragen ||--o{ aufgaben : erzeugt
    anfragen ||--o{ termine : hat
    eingaenge }o--o| anfragen : "führt zu"

    kunden {
        uuid id
        text name
        text telefon_normalisiert
        text plz
        text ort
        text adresse
    }
    anfragen {
        uuid id
        text anfrage_id "Vorgangs-ID je Kanal"
        text quelle "telefon, website, whatsapp"
        text kategorie
        text dringlichkeit
        text technisches_anliegen
        text fehlende_informationen
        text termin_status
    }
    aufgaben {
        uuid id
        uuid anfrage_db_id
        text typ "anfrage_pruefen, termin_pruefen"
        text titel
        text prioritaet
        text status
    }
    termine {
        uuid id
        uuid anfrage_db_id
        text status "vorgeschlagen bis gebucht"
        timestamptz start_at
        timestamptz ende_at
        text ressource_id
    }
    eingaenge {
        uuid id
        text kanal
        text externe_id "Vapi-Call-ID, Twilio-SID"
        text status "empfangen, verarbeitet, fehler"
    }
```

| Tabelle | Zweck |
|---|---|
| `kunden` | Ein Eintrag je Kunde und Betrieb. Gefunden wird der Kunde über die normalisierte Telefonnummer. |
| `anfragen` | Ein Eintrag je Vorgang mit KI-Auswertung und Terminstatus. Eindeutig über (`betrieb_id`, `anfrage_id`), damit ein Anruf nie doppelt gespeichert wird. |
| `aufgaben` | Offene Arbeit für Mitarbeitende. Pro Anfrage gibt es höchstens eine Aufgabe je Typ. |
| `termine` | Vorschläge, Reservierungen und Buchungen. Eine Datenbankregel (`exclude using gist`) verhindert Überschneidungen derselben Ressource, inklusive Puffer. |
| `eingaenge` | Protokoll der technischen Eingangs-IDs ohne personenbezogene Daten. Es verhindert, dass ein Anruf oder eine Nachricht doppelt verarbeitet wird. |

Die SQL-Dateien für `termine` und den Duplikatschutz liegen in [`supabase/`](../supabase/). Für die Grundtabellen `kunden`, `anfragen`, `aufgaben` und `eingaenge` liegt hier keine SQL-Datei bei. Die Spalten oben habe ich aus den Workflows abgeleitet und auf die wichtigsten gekürzt.
