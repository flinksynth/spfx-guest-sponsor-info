# Architecture Diagram

Visual system-level overview of the *Guest Sponsor Info* solution.
For the written design decisions behind each component, see [architecture.md](architecture.md).

---

## Recommended Path — Azure Function Proxy

The function proxy is the **recommended deployment**: guests never need an Entra
directory role, and all Graph app-permission calls are confined to the function.

```mermaid
flowchart TB
    subgraph browser["Guest User Browser"]
        WP["SPFx Web Part\nGuestSponsorInfo.tsx · SponsorService.ts"]
    end

    subgraph spo["SharePoint Online"]
        CDN["Public CDN\n(web part assets)"]
    end

    subgraph entra["Microsoft Entra ID"]
        AppReg["EasyAuth App Registration\n(exposes user_impersonation scope)"]
    end

    subgraph azfunc["Azure Function App"]
        EA["EasyAuth\n(validates Bearer token,\nsets X-MS-CLIENT-PRINCIPAL-ID)"]
        GS["getGuestSponsors.ts"]
        MI["Managed Identity\n(DefaultAzureCredential)"]
        AI[("Application\nInsights")]
    end

    subgraph msgraph["Microsoft Graph"]
        SpEP["/users/{oid}/sponsors"]
        BatEP["$batch\n(profiles + manager + accountEnabled)"]
        PhEP["/users/{id}/photo/$value"]
        PrEP["/communications/getPresencesByUserId\n(optional — Presence.Read.All)"]
    end

    CDN       -. "① web part assets on first load" .->    WP
    WP        -. "② acquire token (user_impersonation)" .-> AppReg
    AppReg    -. "Bearer token" .->                        WP
    WP        --  "③ POST /api/getGuestSponsors\n   + Bearer token" --> EA
    EA        --  "validated request\n+ OID header" -->    GS
    GS        -->                                          MI
    MI        --  "User.Read.All" -->                      SpEP
    MI        --  "User.Read.All" -->                      BatEP
    MI        -. "Presence.Read.All (optional)" .->        PrEP
    GS        --  "{ activeSponsors, unavailableCount }" --> WP
    GS        -. "telemetry & logs" .->                    AI
    WP        --  "④ photo/$value · User.ReadBasic.All\n   (delegated, always direct)" --> PhEP
```

### Step-by-step

| Step | What happens |
|---|---|
| ① | Browser loads the bundled web part JavaScript from the SharePoint Public CDN. |
| ② | Web part acquires an Entra ID token for the EasyAuth App Registration (`user_impersonation` scope). No extra guest consent needed — the scope is pre-authorized for *SharePoint Online Web Client Extensibility*. |
| ③ | Web part calls `POST /api/getGuestSponsors` on the Function App, passing the Bearer token. EasyAuth validates the token before any function code runs and injects the caller's object ID as `X-MS-CLIENT-PRINCIPAL-ID`. The function never trusts a user ID from the request body. |
| ④ | Profile photos are always fetched **directly** from Graph with a delegated token (`User.ReadBasic.All`). They are returned as `ArrayBuffer` → base64 data URL to avoid `Blob` URL leaks. |

The function uses `Promise.allSettled` to fan out three Graph calls concurrently
(sponsor list, `$batch` for profiles + manager, optional presence) and returns
`{ activeSponsors, unavailableCount }` once all resolve.

---

## Fallback Path — Direct Graph (legacy)

When **no Azure Function URL is configured**, the web part falls back to calling
`GET /me/sponsors` directly on Microsoft Graph with a delegated token. This
requires the guest account to hold an Entra directory role (e.g. *Directory Readers*),
which is impractical at scale. Deploy the Azure Function to avoid this.

```mermaid
flowchart LR
    subgraph browser["Guest User Browser"]
        WP2["SPFx Web Part"]
    end

    subgraph msgraph2["Microsoft Graph (delegated)"]
        SpEP2["/me/sponsors\n(requires Directory Readers role)"]
        PhEP2["/users/{id}/photo/$value"]
        PrEP2["/communications/getPresencesByUserId\n(optional — Presence.Read.All)"]
    end

    WP2 -- "User.Read\n(+ Directory Readers role)" --> SpEP2
    WP2 -- "User.ReadBasic.All" --> PhEP2
    WP2 -. "Presence.Read.All (optional)" .-> PrEP2
```

> **Note:** On the direct path, `accountEnabled` cannot be checked efficiently
> because `User.Read.All` is not requested. Disabled-but-not-deleted sponsors
> remain visible until their account is hard-deleted from Entra ID.

---

## Component Summary

| Component | Technology | Role |
|---|---|---|
| SPFx Web Part | React 17 · Fluent UI v8 · TypeScript | Guest-facing UI inside SharePoint |
| Azure Function | Node.js 22 · Azure Functions v4 | Graph proxy — enforces caller identity, applies business filters |
| EasyAuth | Azure App Service Authentication | Validates JWT Bearer tokens before function code runs |
| Managed Identity | Azure system-assigned MI | Credential-free Graph access (`DefaultAzureCredential`) |
| Microsoft Graph | REST API | Source of sponsors, profiles, photos, and presence |
| Application Insights | Azure Monitor | Function telemetry, structured error logs |

---

## Related Documents

- [architecture.md](architecture.md) — design decisions, known limitations, SPFx lifecycle
- [deployment.md](deployment.md) — step-by-step deployment, Azure Function setup, hosting plans
- [development.md](development.md) — local dev setup, build & test commands
- [features.md](features.md) — feature descriptions and the problems they solve
- [README](../README.md) — quick-start and overview
- [Azure Function README](../azure-function/README.md) — function-specific permissions and security design
