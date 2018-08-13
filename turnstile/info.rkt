#lang info

(define scribblings
  '(["scribblings/turnstile.scrbl" (multi-page)]))

(define compile-omit-paths 
  '("examples/tests"
    "examples/trivial.rkt")) ; needs typed racket

(define test-include-paths
  '("examples/tests/mlish")) ; to include .mlish files

(define test-omit-paths
  '("examples/tests/trivial-test.rkt"    ; needs typed/racket
    "examples/tests/mlish/sweet-map.rkt" ; needs sweet-exp
    "examples/tests/mlish/bg/README.md"))
