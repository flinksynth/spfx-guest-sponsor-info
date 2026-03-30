---
layout: page
lang: de
title: Datenschutz
permalink: /de/privacy/
description: >-
  Datenschutzrichtlinie für das Guest Sponsor Info Web Part — wie
  Daten verarbeitet werden, welche Berechtigungen verwendet werden
  und wo Daten gespeichert werden.
---

Guest Sponsor Info ist mit einer **Privacy-First-Architektur** konzipiert.
Die gesamte Datenverarbeitung findet innerhalb Ihrer eigenen Microsoft 365
und Azure Tenant-Grenzen statt.

## Grundprinzipien

- **Keine Daten an Workoho oder Dritte** — Web Part und Azure Function
  arbeiten vollständig innerhalb Ihres Tenants.
- **Nur Browser-Speicher** — das Web Part hält Sponsor-Daten (Name, Titel,
  E-Mail, Telefon, Teams-Präsenz) nur während der Seitensitzung im
  Browser-Speicher. Nichts wird auf der Festplatte gespeichert oder
  anderweitig versendet.
- **Azure Function ist zustandslos** — jede Anfrage wird verarbeitet und
  verworfen. Keine Sponsor- oder Gastdaten werden gespeichert.
- **Ihre Application Insights** — falls aktiviert, geht die Telemetrie
  in Ihr eigenes Azure-Abonnement. Workoho hat keinen Zugriff.

## Verwendete Berechtigungen

| Berechtigung | Typ | Zweck |
|---|---|---|
| `User.Read.All` | Anwendung (Managed Identity) | Lesen von Sponsor-Details über den API-Proxy |
| `Presence.Read.All` | Anwendung (optional) | Teams-Präsenz-Indikatoren |
| `MailboxSettings.Read` | Anwendung (optional) | Freigegebene Postfächer/Raum-/Gerätekonten filtern |
| `TeamMember.Read.All` | Anwendung (optional) | Teams-Konto-Provisionierung von Gästen erkennen |

## Vollständige Richtlinie

Die vollständige Datenschutzrichtlinie einschließlich Betroffenenrechte,
GitHub-Release-Prüfungen und Customer Usage Attribution finden Sie in der
[vollständigen Datenschutzrichtlinie auf GitHub](https://github.com/workoho/spfx-guest-sponsor-info/blob/main/docs/privacy-policy.md).
