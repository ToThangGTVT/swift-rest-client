# CocoaRestClient (Swift Edition)

A lightweight, native macOS REST client built with **SwiftUI** and **Swift Concurrency (`async/await`)**.

[![macOS 13+](https://img.shields.io/badge/macOS-13.0%2B-blue.svg)](https://www.apple.com/macos)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL%203.0-green.svg)](LICENSE.txt)

**English** · [Tiếng Việt](README.md)

<img width="1278" height="1002" alt="CocoaRestClient main window" src="https://github.com/user-attachments/assets/dec8f70a-b109-4886-bd4c-4ce559a009f1" />

---

## Features

### Requests

* **Methods**: GET, POST, PUT, DELETE, HEAD, OPTIONS, PATCH, COPY, SEARCH, plus any custom verb you type.
* **Body editors**, one per body type:
  * **Raw** — syntax highlighting and one-key beautify for JSON, XML, HTML, JavaScript and plain text.
  * **GraphQL** — side-by-side Query/Mutation and Variables JSON editors.
  * **Form URL-Encoded** — key/value table.
  * **Multipart Form-Data** — file attachments with MIME detection and optional gzip.
  * **Binary File** — send a file as the raw body.
* **Query params** edited as a table, kept in sync with the URL both ways.
* **Auth**: Basic (preemptive or not), Bearer Token, API Key (header or query), OAuth 2.0 access token.
* **Tabs**: work on several requests at once (`⌘T` / `⌘W`).

### Environments and variables

Define profiles (Dev, Staging, Production…) and reference them anywhere — URL, headers, query params, body,
and credential fields — with either `{{variableName}}` or `${variableName}`.

The URL bar renders variables as inline chips while you type: **accent-coloured** when the active environment
resolves the name, **red** when it does not, so a typo shows up before you send rather than after.

Process environment variables are merged in as a fallback, so `{{HOME}}`-style values work without declaring them.

### Workspaces with Git sync

Each workspace is a folder on disk holding its own collections and environments, and it can be backed by its
own Git repository. From the sidebar switcher you can link a remote, commit and push, pull the latest, or
clone an existing repository as a new workspace — no terminal needed. Git status (branch, uncommitted changes,
unpushed commits) is shown inline per workspace.

### Realtime: WebSocket and SSE

A dedicated console for **WebSocket (ws/wss)** and **Server-Sent Events**, with the same auth and header
editors as the request tab, so a stream authenticates exactly the way the equivalent HTTP call does.
Environment variables are resolved in the URL and headers, the app's cookie jar is attached, a rejected
WebSocket handshake reports the actual HTTP status instead of silently claiming success, and SSE reconnects
replay `Last-Event-ID`.

### Response inspector

* **Pretty**, **Raw**, and **Preview** modes — Preview renders HTML through WebKit and displays image
  responses directly.
* Status code, latency in ms, and payload size.
* **Response Headers** and **Sent Headers** (what actually went over the wire).
* In-response search with a live match count.
* **Diff two responses** (`⌘D`) line by line across tabs.

### Tests and variable extraction

Attach assertions to a request and see pass/fail after every send:

`Status Code Equals` · `Status is 2xx Success` · `Response Time Less Than (ms)` · `Body Contains String` ·
`Header Exists` · `Header Value Equals` · `JSON Key / Path Exists` · `JSON Key / Path Equals`

Extraction rules pull values out of a response — by **JSON key/path**, **response header**, or **regex on the
body** — and write them straight into the active environment, so a login response can feed the next request's
token automatically.

### Import and export

* **cURL** (`⌘⇧I`) — paste a command from Swagger, Postman or Chrome DevTools; URL, method, headers, auth and
  payload are parsed out. Pasting a `curl …` command into the URL bar imports it on the spot.
* **Postman** collections (v2.1) and **OpenAPI / Swagger** specifications.
* Export the whole collection tree as JSON.
* Legacy `CocoaRestClient.savedRequests` data is read automatically.

### Other

* **Code snippets** (`⌘⇧G`) for cURL, Swift (`URLSession`), Python (`requests`), JavaScript (`fetch`),
  Node.js (`axios`) and Go (`net/http`).
* **Request history** with status, latency and size, searchable, switchable with the saved-requests tree.
* **Cookie jar manager** — inspect, add and delete stored cookies by domain.
* **Quick Open** (`⌘O`) fuzzy search across saved requests.
* **Preferences** (`⌘,`) — timeout, follow redirects, self-signed certificates, cookies on/off, default
  content type, line numbers, syntax highlighting.

---

## Build and run

### Xcode

```bash
open CocoaRestClient.xcodeproj
```

`⌘R` to run, `⌘U` to run the test suite.

### Swift Package Manager

```bash
swift build
```

```bash
swift test
```

```bash
swift run CocoaRestClient
```

### Package a standalone `.app`

```bash
./scripts/build_app.sh
```

The bundle lands in `build/CocoaRestClient.app`.

### xcodebuild

```bash
xcodebuild test -project CocoaRestClient.xcodeproj -scheme CocoaRestClient -destination 'platform=macOS'
```

```bash
xcodebuild -project CocoaRestClient.xcodeproj -scheme CocoaRestClient -configuration Release -destination 'platform=macOS' build
```

---

## Keyboard shortcuts

| Shortcut | Action |
| :--- | :--- |
| `⌘↩` | Send request |
| `⌘R` | Re-send the last executed request |
| `⌘T` | New tab |
| `⌘W` | Close current tab |
| `⌘S` | Save request to the sidebar |
| `⌘O` | Quick Open saved requests |
| `⌘D` | Diff two responses |
| `⌘⇧I` | Import from a cURL command |
| `⌘⇧C` | Copy request as a cURL command |
| `⌘⇧G` | Generate code snippets |
| `⌘⇧F` | Beautify the JSON body |
| `⌘⇧E` | Manage environments |
| `⌘,` | Preferences |

---

## Where data is stored

Everything lives under `~/Library/Application Support/CocoaRestClient/`:

| Path | Contents |
| :--- | :--- |
| `CocoaRestClient.savedRequests.json` | Saved request tree |
| `CocoaRestClient.environments.json` | Environment profiles |
| `CocoaRestClient.history.json` | Request history |
| `cookies.json` | Cookie jar |
| `workspaces_index.json`, `active_workspace.txt` | Workspace list and current selection |
| `Workspaces/<name>/` | Per-workspace `collections.json`, `environments.json`, `workspace.json`, and its Git repository |

---

## Project layout

```
Sources/
  CocoaRestClientCore/     Models and services — no UI, fully unit-tested
    Models/                RestRequest, Authentication, EnvironmentProfile, …
    Services/              NetworkEngine, WebSocketEngine, SSEEngine, importers,
                           code generators, stores, Git sync
  CocoaRestClient/         SwiftUI app
    ViewModels/
    Views/
Tests/CocoaRestClientTests/
```

Networking, parsing, storage and Git logic live in `CocoaRestClientCore` with no SwiftUI dependency, which is
what makes them testable from the command line.

---

## License

GPL-3.0 — see [LICENSE.txt](LICENSE.txt).
