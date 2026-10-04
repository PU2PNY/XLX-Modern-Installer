# Observed transcoder recovery source

Source copied from the lab build associated with the running XLX026 ELF
`d3ea28efb76ff61f615a5613bc5475b08b9a94a3085f638d470e70a8d21e1884`.
This preserves the D-Star erasure concealment and restored D-Star-to-AMBE+2
path missing from the older generic bridge. It is a recovery reference, not
an automatic replacement of the experimental bridge or production.

The observed client also contains a three-consecutive-failure policy in
`process`, whereas the public bridge contract specifies first-failure sticky
fallback. Do not enable `process` from this reference. Production currently
uses `shadow`; recovery must retain that mode and the exact running ELF from
the private archive. New generic installation keeps Helix optional/OFF.
OP25 source revision: boatbod/op25@28f2c40645deca3f8c2d529d27d0df2555ed287a.
No codec/vendor binaries or voice corpus are redistributed.
