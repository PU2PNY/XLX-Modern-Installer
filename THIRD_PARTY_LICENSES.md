# Third-party licenses

This register separates the license of original XLX Modern Installer material from upstream components that keep their own terms. It is a distribution/compliance inventory, not a transfer of third-party copyright.

| Component | Upstream / author | License status | Verified | Commercial-distribution note |
|---|---|---|---|---|
| XLX Reflector / XLXD | LX3JL / LX1IQ — `LX3JL/xlxd` | GPL-3.0 | Yes — upstream `license.txt` and repository license metadata | Copies may be sold, but GPL terms, notices and corresponding-source obligations remain applicable to covered work. Do not relicense XLXD as proprietary/MIT. |
| XLX Installer base | PP5PK — `PP5PK/XLX_Installer` | The Unlicense | Yes — upstream repository `LICENSE`/license metadata | May be redistributed subject to the upstream terms and preserved provenance. |
| XLX Dark Dashboard upstream/reference | PP5PK — `PP5PK/XLX_Dark_Dashboard` | GPL-3.0 | Yes — upstream repository license metadata | Any files that remain derivative/covered by this upstream must retain the applicable GPL terms; the root MIT license does not override them. |
| XLX Echo | narspt — `narspt/XLXEcho` | **Unresolved: no license file is exposed by the upstream repository currently reviewed** | No | Do not market the Echo source as proprietary or include it in a commercial source bundle until redistribution rights are established. Prefer exclusion/optional external acquisition or written permission. |

## Original XLX Modern Installer material

The root `LICENSE` is MIT for original material authored for this project, except where a file, directory, vendored component or derivative work is governed by another license. MIT permits sale of copies, but recipients retain the rights granted by MIT.

## Commercial packaging rule

A commercial package must keep a component-level boundary:

1. preserve each upstream copyright/license notice;
2. provide corresponding source where a copyleft license requires it;
3. never represent third-party code as exclusively owned by PU2PNY;
4. exclude credentials, TLS/private keys, production databases, private backups and service/API secrets;
5. exclude or separately resolve any component whose redistribution license is not established;
6. keep `THIRD_PARTY_NOTICES.md` and this register with the delivered source.

This file records technical license evidence for packaging. It is not legal advice; a formal commercial release should receive legal review before sale.
