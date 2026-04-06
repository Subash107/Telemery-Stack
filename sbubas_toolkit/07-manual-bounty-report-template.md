# Manual Bounty Report Template

Use this for one vulnerability per report.
Replace every placeholder before submission.

This template is designed for programs that want:
- a clear product and asset name
- version or build details where possible
- reproducible steps
- concrete exploitability and impact
- cleanup notes when state was changed

## Quick Program Fit Check

- [ ] The asset is in scope.
- [ ] I used only accounts I own or that were issued for testing.
- [ ] My testing stayed manual and controlled.
- [ ] My evidence shows a real security impact, not just a best-practice gap.
- [ ] This is not only an open port, missing header, weak TLS finding, or scanner output.
- [ ] I can reproduce the issue from a clean starting state.
- [ ] I noted any cleanup actions needed after testing.

## Report Metadata

- Title:
- Product / Platform:
- Asset / Hostname:
- Version / Build:
- Environment:
- Entry URL:
- Vulnerability Type:
- Severity Estimate:
- Attack Vector:
- Privileges Required:
- User Interaction Required:
- Testing Account:
- Date Tested:

## Summary

Write a short paragraph that answers:
- What is the bug?
- Where is it?
- Why is it a security issue?

Example style:

`A stored XSS vulnerability exists in the profile display-name field on <asset>. A low-privileged user can save HTML/JavaScript that executes in another authenticated user's browser when the victim visits the account settings page. This can lead to session theft or unauthorized actions in the victim context.`

## Scope And Preconditions

- Confirm why the target is in scope:
- Confirm what level of access was used:
- Confirm whether the issue is reachable from the Internet, LAN, or cloud:
- Confirm any setup requirements:

## Steps To Reproduce

1. Start from:
2. Browse to:
3. Create or modify:
4. Send the following request:
5. Observe the following response or UI behavior:
6. Open or refresh:
7. Confirm the impact:

## Evidence

### Request

```http
PASTE THE KEY REQUEST HERE
```

### Response

```http
PASTE THE KEY RESPONSE HERE
```

### Screenshots / Files

- Screenshot 1:
- Screenshot 2:
- Video or HAR file:
- Relevant file paths:

## Observed Result

Describe exactly what happened.

## Expected Secure Result

Describe what should have happened instead.

## Security Impact

Cover the real impact, not just the bug class.

- Confidentiality impact:
- Integrity impact:
- Availability impact:
- Sensitive data exposed:
- Accounts or roles affected:
- Business impact:

## Realistic Attack Scenario

1. An attacker with <role> does:
2. The attacker sends or stores:
3. A victim user visits or triggers:
4. The attacker gains:

## Why This Should Be Treated As In Scope

Use this section to show the report is not only:
- missing security headers
- weak TLS settings without exploitability
- open ports
- a descriptive error message
- self-XSS without impact
- a scanner-only observation

Explain the concrete exploit path here:

## Recommended Fix

- Primary fix:
- Defense-in-depth:
- Validation or authorization changes:
- Logging or detection improvements:

## Cleanup

- Created test account:
- Uploaded file to remove:
- Record or object ID to delete:
- Other state to revert:

## Duplicate Reduction Notes

Help the triager see what is unique.

- Exact endpoint or function:
- Exact parameter or field:
- Exact role required:
- Why this is not a duplicate of a generic issue:

## Optional CVSS Notes

- CVSS Vector:
- CWE:
- Severity reasoning:

## Final Submission Checklist

- [ ] One vulnerability only.
- [ ] Product, asset, and version are included.
- [ ] Reproduction is step-by-step and repeatable.
- [ ] Evidence includes the key request and response.
- [ ] Impact is concrete and realistic.
- [ ] Cleanup notes are present.
- [ ] The report avoids out-of-scope issue classes.
