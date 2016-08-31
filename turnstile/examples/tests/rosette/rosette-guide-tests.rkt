#lang s-exp "../../rosette/rosette2.rkt"
(require "../rackunit-typechecking.rkt"
         "check-type+asserts.rkt")

;; all examples from the Rosette Guide

;; sec 2

(define-symbolic b boolean? : Bool)
(check-type b : Bool)
(check-type (boolean? b) : Bool -> #t)
(check-type (integer? b) : Bool -> #f)

;; TODO: fix these tests
(check-type (vector b 1) : (CMVectorof (U Bool CPosInt)) -> (vector b 1))
(check-not-type (vector b 1) : (CIVectorof (U Bool CPosInt)))
(check-not-type (vector b 1) : (CMVectorof (CU CBool CPosInt)))
;; but this is ok
(check-type (vector b 1) : (CMVectorof (U CBool CPosInt)))
;; mutable vectors are invariant
(check-not-type (vector b 1) : (CMVectorof (U Bool CInt)))
(check-type (vector b 1) : (CVectorof (U Bool PosInt)))
;; vectors are also invariant, because it includes mvectors
(check-not-type (vector b 1) : (CVectorof (U Bool CInt)))
(check-not-type (vector b 1) : (CVectorof (U Bool Int)))

(check-type (not b) : Bool -> (! b))
(check-type (boolean? (not b)) : Bool -> #t)

(define-symbolic* n integer? : Int)

;; TODO: support internal definition contexts
(define (static -> Bool)
  (let-symbolic ([(x) boolean? : Bool]) x))
#;(define (static -> Bool)
 (define-symbolic x boolean? : Bool) ; creates the same constant when evaluated
 x)
 
(define (dynamic -> Int)
  (let-symbolic* ([(y) integer? : Int]) y))
#;(define (dynamic -> Int)
 (define-symbolic* y integer? : Int) ; creates a different constant when evaluated
 y)
 
(check-type static : (C→ Bool))
(check-not-type static : (C→ CBool))
(check-type dynamic : (C→ Int))
(check-type dynamic : (C→ Num))
(check-not-type dynamic : (C→ CInt))
(check-type (eq? (static) (static)) : Bool -> #t)

(define y0 (dynamic))
(define y1 (dynamic))
(check-type (eq? y0 y1) : Bool -> (= y0 y1))

(define (yet-another-x -> Bool)
  (let-symbolic ([(x) boolean? : Bool]) x))

(check-type (eq? (static) (yet-another-x))
            : Bool -> (<=> (static) (yet-another-x)))

(check-type+asserts (assert #t) : Unit -> (void) (list))
(check-runtime-exn (assert #f))

(check-type+asserts (assert (not b)) : Unit -> (void) (list (! b) #f))

(check-type (clear-asserts!) : Unit -> (void))
(check-type (asserts) : (CListof Bool) -> (list))

;; sec 2.3
(define (poly [x : Int] -> Int)
  (+ (* x x x x) (* 6 x x x) (* 11 x x) (* 6 x)))

(define (factored [x : Int] -> Int)
  (* x (+ x 1) (+ x 2) (+ x 2)))

(define (same [p : (C→ Int Int)] [f : (C→ Int Int)] [x : Int] -> Unit)
  (assert (= (p x) (f x))))

; check zeros; all seems well ...
(check-type+asserts (same poly factored 0) : Unit -> (void) (list))
(check-type+asserts (same poly factored -1) : Unit -> (void) (list))
(check-type+asserts (same poly factored -2) : Unit -> (void) (list))

;; 2.3.1 Verification

(define-symbolic i integer? : Int)
(define cex (verify (same poly factored i)))
(check-type cex : CSolution)
(check-type (sat? cex) : Bool -> #t)
(check-type (unsat? cex) : Bool -> #f)
(check-type (evaluate i cex) : Int -> 12)
(check-runtime-exn (same poly factored 12))
(clear-asserts!)

;; 2.3.2 Debugging

(require "../../rosette/query/debug.rkt"
         "../../rosette/lib/render.rkt")
(define/debug (factored/d [x : Int] -> Int)
  (* x (+ x 1) (+ x 2) (+ x 2)))

(define ucore (debug [integer?] (same poly factored/d 12)))
(check-type ucore : CSolution)
;; TESTING TODO: requires visual inspection (in DrRacket)
(check-type (render ucore) : CPict)

;; 2.3.3 Synthesis

(require "../../rosette/lib/synthax.rkt")
(define (factored/?? [x : Int] -> Int)
 (* (+ x (??)) (+ x 1) (+ x (??)) (+ x (??))))

(define binding
  (synthesize #:forall (list i)
              #:guarantee (same poly factored/?? i)))
(check-type binding : CSolution)
(check-type (sat? binding) : Bool -> #t)
(check-type (unsat? binding) : Bool -> #f)
;; TESTING TODO: requires visual inspection of stdout
(check-type (print-forms binding) : Unit -> (void))
;; typed/rosette should print: 
;;  '(define (factored/?? (x : Int) -> Int) (* (+ x 3) (+ x 1) (+ x 2) (+ x 0)))
;; (untyped) rosette should print: 
;;  '(define (factored x) (* (+ x 3) (+ x 1) (+ x 2) (+ x 0)))

;; 2.3.4 Angelic Execution

(define-symbolic x y integer? : Int)
(define sol
  (solve (begin (assert (not (= x y)))
                (assert (< (abs x) 10))
                (assert (< (abs y) 10))
                (assert (not (= (poly x) 0)))
                (assert (= (poly x) (poly y))))))
(check-type sol : CSolution)
(check-type (sat? sol) : Bool -> #t)
(check-type (unsat? sol) : Bool -> #f)
(check-type (evaluate x sol) : Int -> -5)
(check-type (evaluate y sol) : Int -> 2)
(check-type (evaluate (poly x) sol) : Int -> 120)
(check-type (evaluate (poly y) sol) : Int -> 120)

