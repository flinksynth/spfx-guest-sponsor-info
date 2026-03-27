---
layout: page
lang: en
title: Privacy Policy
permalink: /en/privacy/
description: >-
  Privacy policy for the Guest Sponsor Info web part — how data is handled,
  what permissions are used, and where data is stored.
---

Guest Sponsor Info is designed with a **privacy-first architecture**. All data
processing happens within your own Microsoft 365 and Azure tenant boundaries.

## Key Principles

- **No data sent to Workoho or third parties** — the web part and Azure
  Function operate entirely within your tenant.
- **Browser memory only** — the web part holds sponsor data (name, title,
  email, phone, Teams presence) in browser memory during the page session.
  Nothing is persisted to disk or sent elsewhere.
- **Azure Function is stateless** — each request is processed and discarded.
  No sponsor or guest data is stored.
- **Your Application Insights** — if enabled, telemetry goes to your own
  Azure subscription. Workoho has no access.

## Permissions Used

| Scope | Type | Purpose |
|-------|------|---------|
| `User.Read` | Delegated | Identify the signed-in guest user |
| `User.ReadBasic.All` | Delegated | Read sponsor basic profiles |
| `User.Read.All` | Application (Managed Identity) | Read sponsor details via API proxy |
| `Presence.Read.All` | Application (optional) | Teams presence indicators |

## Full Policy

For the complete privacy policy including data subject rights, GitHub release
checks, and Customer Usage Attribution details, see the
[full privacy policy on GitHub](https://github.com/workoho/spfx-guest-sponsor-info/blob/main/docs/privacy-policy.md).
