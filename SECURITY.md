# Security Policy

ArcPatches modifies and re-signs a web browser, so security reports matter a great deal. Thank you for taking the time to report one.

## Reporting a vulnerability

**Don't open a public issue.** Report the problem privately through GitHub instead:

1. Go to the repository's **Security** tab.
2. Click **Report a vulnerability**.
3. Describe the issue, the affected versions, and steps to reproduce. A proof of concept helps if you have one.

You'll get an acknowledgement within 3 working days and a first assessment within 7.
Once a fix is released, you'll be credited in the advisory unless you'd rather not be.

## In scope

- Code execution, privilege escalation or sandbox escape made possible by ArcPatches' changes to the browser.
- Ways for other software to inject code into, or tamper with, the patched browser or the ArcPatches app.
- Weaknesses in the update pipeline: signature verification, release integrity, downgrade attacks.
- ArcPatches leaking browsing data, credentials or other personal data.

## Out of scope

- Vulnerabilities in the browser itself that exist without ArcPatches installed. Report those to the browser's vendor.
- The known trade-offs listed in the README's [Security and trade-offs](README.md#security-and-trade-offs) section, such as the ad hoc signature and relaxed library validation.
- Attacks that require an attacker who already has full control of the user's account.

## Supported versions

Only the latest release gets security fixes.
