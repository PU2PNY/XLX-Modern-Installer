# Migration plan from PP5PK/XLX_Installer

## Preserve after review

- installation sequence concepts;
- systemd integration;
- optional Echo service;
- dashboard integration;
- project credits.

## Rewrite

- bilingual interface;
- backup and rollback;
- configuration validation;
- firewall handling;
- uninstall procedure;
- secret protection.

## Reject

- `chmod 777`;
- uncontrolled recursive deletion;
- destructive actions without confirmation;
- publication of server-specific files.

## License gate

Third-party code must not be copied until copyright and license terms are confirmed.
