# Future tests (after Phase 0G)

## Separate low-binding-energy F_other candidate

TODO: add a later candidate/robustness test containing a distinct F 1s
component near 681.3-681.6 eV. The Ruoff assignment for this region is
physisorbed, entrapped, or interface fluorine; it must not be labeled as the
ionic component near 684.7 eV.

The locked three-peak F1s model currently contains only:

- ionic or substrate-bound F near 684.7 eV;
- semi-covalent F-C near 686.7 eV;
- covalent F-C near 688.2 eV.

Do not add `F_other` to the locked production profile or its generic plumbing
test without a separately approved candidate configuration. The later test
must evaluate classification, identifiability, total-F inclusion, and whether
the additional component remains stable under noise/background mismatch.
