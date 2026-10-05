# Helix shadow recovery reference

The XLX026 running Helix daemon observed on 2026-10-05 has SHA-256
`7c4292bfe5610bc22870308b6c5b934b492caf4d579626586ac30da4c2ff6745`.
Its matching lab source is the public `PU2PNY/Helix-Voice` revision
`e80969d58d0ecf0f4bd55bbc7fae85311c0176d2`, with the accompanying Cargo.lock.
The source changes are already published in that repository.

Use `bash runtime/build-helix-recovery.sh /new/output/directory` to compile
the reference without installing or restarting any service. Compiler/platform
differences may change the rebuilt ELF hash. For exact private restoration,
use the running ELF and service configuration recorded in the private archive.
This does not authorize or enable Helix process mode; recovery must retain the
documented shadow/legacy policy and independent audio validation gates.
