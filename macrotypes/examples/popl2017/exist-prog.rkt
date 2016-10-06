#lang s-exp "exist.rkt"

(define COUNTER
  (pack [Int (rcrd [new = 1]
                   [inc = add1]
                   [get = (λ ([x : Int]) x)])]
   as
   (∃ (C) 
      (× [new : C] 
         [inc : (→ C C)] 
         [get : (→ C Int)]))))

;; this example type checks
(open [c COUNTER] with Count 
 in
 ((prj c get) 
  ((prj c inc) (prj c new)))) ; => 2

;; failing example from paper
(open [c COUNTER] with Count 
 in
 (+ ((prj c get) ((prj c inc) (prj c new))) ; => 2
    (add1 (prj c new)))) ; TYERR: expected type Int, got Count
