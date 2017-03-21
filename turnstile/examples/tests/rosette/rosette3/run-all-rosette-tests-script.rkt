#lang racket/base

(require macrotypes/examples/tests/do-tests)

(do-tests
 "rosette3-tests.rkt"            "General"
 "rosette-guide-sec2-tests.rkt"  "Rosette Guide, Section 2"
 "rosette-guide-sec3-tests.rkt"  "Rosette Guide, Section 3"
 "rosette-guide-sec4-tests.rkt"  "Rosette Guide, Section 4.1-4.2"
 "rosette-guide-sec43-tests.rkt" "Rosette Guide, Section 4.3 BVs"
 "rosette-guide-sec44-tests.rkt" "Rosette Guide, Section 4.4 Uninterp Fns"
 "rosette-guide-sec45-tests.rkt" "Rosette Guide, Section 4.5 Procedures"
 "rosette-guide-sec46-tests.rkt" "Rosette Guide, Section 4.6-4.8")

(do-tests
 "rosette-guide-sec49-tests.rkt" "Rosette Guide, Section 4.9"
 "rosette-guide-sec5-tests.rkt"  "Rosette Guide, Section 5 Structures"
 "rosette-guide-sec6-tests.rkt"  "Rosette Guide, Section 6 Libraries"
 "rosette-guide-sec7-tests.rkt"  "Guide Sec. 7 Reflecting on Symbolic Values")

(do-tests "bv-tests.rkt" "BV SDSL - General"
          "fsm3-tests.rkt" "FSM"
          "ifc3-tests.rkt" "IFC"
          "synthcl3-tests.rkt" "SynthCL"
          "synthcl3-matrix-synth-tests.rkt" "SynthCL Matrix Mult: synth")
(do-tests "bv-ref-tests.rkt" "BV SDSL - Hacker's Delight synthesis")

