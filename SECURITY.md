# Security policy

Security fixes target the latest published release. Other versions should be
updated before a report is reproduced.

Report suspected vulnerabilities through
[GitHub private vulnerability reporting](https://github.com/bashar12-dev/barcode_port/security/advisories/new).
If private reporting is unavailable, contact the maintainer through the
[GitHub profile](https://github.com/bashar12-dev) to arrange a private channel;
do not disclose the vulnerability in a public issue.

Include the affected version, platform, minimal reproduction with synthetic
input, expected impact, and any proposed mitigation. Do not submit credentials,
payment records, or customer barcodes. Response and fix timelines depend on the
report and are not guaranteed.

Barcode contents and Android broadcast messages are input, not authenticated
business operations. Consuming applications remain responsible for validation,
authorization, and decisions such as product lookup and quantity changes.
