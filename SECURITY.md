# Security Policy

## Reporting a vulnerability

MenuVibe handles clipboard contents — including potentially sensitive data — and
controls other apps' windows via the Accessibility API, so security reports are taken
seriously.

**Please do not open a public issue for security vulnerabilities.**

Instead, use GitHub's private **[Report a vulnerability](https://github.com/OWNER/MenuVibe/security/advisories/new)**
flow (Security tab → Advisories). Include:

- A description of the issue and its impact
- Steps to reproduce
- The MenuVibe version and your macOS version/Mac type

You can expect an initial response within a few days. Once a fix is available, we'll
coordinate disclosure and credit you (unless you prefer to remain anonymous).

## Scope & design notes

- MenuVibe stores everything locally under `~/Library/Application Support/MenuVibe/`
  and performs **no network requests** of its own.
- Clipboard entries marked concealed or transient by password managers are never
  persisted.
- MenuVibe runs outside the App Sandbox specifically to use the Accessibility API for
  window snapping; see the commented [`Resources/MenuVibe.entitlements`](Resources/MenuVibe.entitlements).

## Supported versions

The latest released version receives security fixes.
