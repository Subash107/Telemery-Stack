# Example Bounty Report

This is an example write-up only.
Do not submit it unless you have actually reproduced the issue on a real in-scope target.

## Report Metadata

- Title: Stored XSS in Organization Display Name Triggers in Administrator Session
- Product / Platform: Example Web Product
- Asset / Hostname: app.example.ui.com
- Version / Build: Web build 2026.04.01
- Environment: Production web application
- Entry URL: https://app.example.ui.com/settings/organization
- Vulnerability Type: Stored Cross-Site Scripting
- Severity Estimate: High
- Attack Vector: WAN / Internet
- Privileges Required: Low
- User Interaction Required: Required
- Testing Account: researcher-owned low-privilege test account
- Date Tested: 2026-04-06

## Summary

A stored XSS vulnerability exists in the organization display-name field on `app.example.ui.com`. A low-privileged user can save JavaScript in the field, and the payload executes when an administrator later loads the organization settings page. This allows an attacker to run JavaScript in the victim's authenticated browser context and can lead to unauthorized actions or theft of sensitive UI data.

## Scope And Preconditions

- The issue affects an in-scope web application under the program domain.
- The attacker only needs a normal low-privilege account.
- The vulnerable page is reachable through the public Internet.
- No special browser extensions or local tooling are required for exploitation.

## Steps To Reproduce

1. Log in with a normal low-privilege account.
2. Open `https://app.example.ui.com/settings/organization`.
3. Edit the organization display-name field.
4. Save the following payload as the display name:

```text
"><img src=x onerror=alert(document.domain)>
```

5. Confirm the UI accepts and stores the value.
6. Log out and log in with a second administrator test account.
7. Open the same organization settings page.
8. Observe that the JavaScript executes in the administrator browser.

## Evidence

### Request

```http
POST /api/v1/organization/profile HTTP/2
Host: app.example.ui.com
Content-Type: application/json
Authorization: Bearer <low-privilege-token>

{
  "displayName": "\"><img src=x onerror=alert(document.domain)>"
}
```

### Response

```http
HTTP/2 200 OK
Content-Type: application/json

{
  "success": true,
  "displayName": "\"><img src=x onerror=alert(document.domain)>"
}
```

### Screenshots / Files

- Screenshot 1: payload stored successfully in profile form
- Screenshot 2: payload execution when administrator loads the page
- Video: optional short screen recording showing low-privilege save followed by administrator trigger

## Observed Result

User-controlled HTML and JavaScript are rendered without safe output encoding in the administrator view. The payload executes automatically when the victim loads the page.

## Expected Secure Result

The application should treat the display name as plain text and render it safely. Arbitrary HTML and JavaScript should never execute in another user's browser.

## Security Impact

- Confidentiality impact: attacker can read data visible in the victim browser.
- Integrity impact: attacker can perform unauthorized state-changing actions in the victim session, depending on available anti-CSRF and session protections.
- Availability impact: limited, but UI disruption is possible.
- Accounts or roles affected: any administrator who views the poisoned page.
- Business impact: compromise of administrator sessions can expose tenant settings, secrets visible in the UI, or enable malicious administrative changes.

## Realistic Attack Scenario

1. An attacker signs up for a normal account.
2. The attacker stores a JavaScript payload in the organization display-name field.
3. A support engineer or administrator later opens the poisoned settings page.
4. The payload executes in the victim session and can exfiltrate sensitive UI data or perform actions as that user.

## Why This Should Be Treated As In Scope

This is not only a missing security header or a self-XSS issue. The payload persists server-side and executes in another authenticated user's browser, creating a cross-user impact with a realistic attack path.

## Recommended Fix

- Apply context-appropriate output encoding before rendering user-controlled content.
- Validate and reject HTML where the field should only contain plain text.
- Review similar text-rendering paths for the same pattern.
- Add regression tests for stored XSS in organization profile fields.

## Cleanup

- Remove the stored payload from the organization display name.
- If a dedicated test organization was created, delete it after validation.

## Duplicate Reduction Notes

- Exact endpoint: `POST /api/v1/organization/profile`
- Exact field: `displayName`
- Required role: low-privilege authenticated user
- Unique behavior: stored server-side payload that triggers in an administrator session

## Optional CVSS Notes

- CVSS Vector: `CVSS:3.1/AV:N/AC:L/PR:L/UI:R/S:C/C:H/I:H/A:L`
- CWE: CWE-79
- Severity reasoning: network reachable, low-privilege attacker, cross-user execution, meaningful integrity and confidentiality impact
