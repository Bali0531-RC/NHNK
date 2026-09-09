# Neptun API notes

What we know about the Neptun student API, written down so the next person does not
have to guess, and so nobody repeats the mistake described at the bottom of this file.

Everything here was observed from a real institution's live system. Nothing came from
official documentation, because there is none available to us.

| file | contents |
| --- | --- |
| [endpoints.md](endpoints.md) | Every route observed on the modern web client, 180 of them |
| [schemas.md](schemas.md) | Confirmed response shapes for the routes we depend on |
| [discovery.md](discovery.md) | How the list was produced, and how to redo it |

## The two APIs

Institutions run one of two things, and NHNK supports both. `DataCache.getIsModernApi()`
records which one the account is on, decided during login.

**Legacy**, a SOAP-flavoured service at `/hallgato/MobileService.svc`, with flat routes
like `/api/GetMarkbookData`. Credentials go in the POST body on every call. Older
institutions still run this and it is not going away.

**Modern**, a REST API at `/hallgato/api/`, bearer authenticated. This is what the
current Neptun web client talks to, and it is where all the findings below apply.

## Modern API basics

Base URL is the institution's Neptun host plus `/hallgato/api/`, for example
`https://neptun-ws01.uni-pannon.hu/hallgato/api/`.

### Authentication

    POST Account/Authenticate
    { "userName": "...", "password": "...", "LCID": 1038, "token": "<TOTP if enabled>" }

Returns **202** when two-factor is required and the code was not supplied, **200** with
`data.accessToken` once it is. `data.isTwoFactorRequired` marks the first case.

Tokens are short lived. On the account we tested, five minutes: `nbf` and `exp` in the
JWT were 300 seconds apart. Refresh with `POST Account/GetNewTokens` rather than
re-authenticating, which is what the web client does.

### Response envelope

Every modern endpoint returns the same wrapper:

    { "data": <the payload>, "notification": [] }

`data` is an object or an array depending on the route. NHNK treats a response with no
`data` key as "this build does not have this endpoint", which is the basis of the
capability check described below.

### Capability, not availability

**Institutions run different Neptun builds.** An endpoint that exists on one
university's server may 404 on another's, and the version string in the web footer
(`2026.2.13` where we looked) differs between them.

`ModernApi` in `lib/API/api_coms.dart` handles this: it tries an endpoint once, caches
the answer per institution in `ModernSupport_<path>`, and returns null forever after if
the endpoint is not there. Every caller must keep its existing path as the fallback. A
missing endpoint is a normal condition, not an error.

Transport failures are deliberately **not** cached as a miss, otherwise one flaky
network moment would permanently disable a feature.

## Sampling warning

Everything documented here comes from **one institution, one Neptun build, one student
account**. That is not enough to conclude anything is universal, and several fields
that look mandatory came back null on the very account we probed.

Treat every shape in [schemas.md](schemas.md) as "seen once", not "guaranteed".

Endpoints were found in an afternoon by watching the browser's network tab. See
[discovery.md](discovery.md).
