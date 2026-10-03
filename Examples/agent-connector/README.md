# Universal local agent connector (architecture sketch)

This example applies Hypercode to the connector idea discussed on 2026-10-03.
It is a **proposed architecture**, not a description of an existing app or an
ASP conformance claim.

The connector has one shared core for ASP discovery, origin checks, user
consent, Grant coordination, local-agent mediation, result disclosure and
revocation. Platform bindings supply the path from a requesting website to
that core:

- **iPhone:** an embedded browser and a native WebKit bridge.
- **Mac:** an external browser and a loopback HTTP listener.

Both paths terminate at the same origin-and-Grant gates. Website code proposes
an action; it does not receive a Grant or credential and cannot add actions to
the selected surface. The ASP authorization profile determines which authority
issues a Grant; the connector coordinates acquisition and keeps any credential
in connector-controlled custody. The remote application independently checks
current authority when it executes the call.

The `.hc` tree names responsibilities and platform components. Nesting does
not assert runtime order. The two `.hcs` scenario traces therefore use explicit
`sequence` and `next_step` properties. Hypercode validates their shape and
contracts, but does not prove that an implementation follows those traces.

The Mac loopback checks and iPhone bridge checks are design constraints that
need platform-specific implementation evidence. In particular, binding to
loopback does not itself authenticate a website; origin checks and a
short-lived proof must gate action dispatch before side effects. Nor does this
sketch establish that arbitrary desktop browsers permit a website-to-loopback
HTTP request: browser security policy and transport behavior need a separate
compatibility test before choosing this as the Mac binding.

## Validate with the Hypercode compiler

From the Hypercode repository root:

```sh
swift run hypercode validate Examples/agent-connector/connector.hc \
  --hcs Examples/agent-connector/connector.hcs
swift run hypercode validate Examples/agent-connector/connector.hc \
  --hcs Examples/agent-connector/connector.hcs --ctx platform=ios
swift run hypercode validate Examples/agent-connector/connector.hc \
  --hcs Examples/agent-connector/connector.hcs --ctx platform=macos
```

Emit the resolved machine-readable representation with:

```sh
swift run hypercode emit Examples/agent-connector/connector.hc \
  --hcs Examples/agent-connector/connector.hcs --format json
```

The `platform=ios` and `platform=macos` contexts resolve the connector's
selected binding to different explicit values. They do not change the common
Grant, consent, origin or result-disclosure constraints.
