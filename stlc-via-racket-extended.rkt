#lang s-exp "racket-extended-for-implementing-typed-langs.rkt"
;(provide #%top-interaction)
;(require (prefix-in r: racket/base))
;(provide (rename-out [r:#%module-begin #%module-begin]))

;; Simply-Typed Lambda Calculus
;; - implemented with racket-extended language
;; - lam, app, var, +, and int literals only

(declare-base-types → Int)

;; typed forms ----------------------------------------------------------------

(define-literal-type-rule integer : Int)

(define-simple-syntax/type-rule
  (+ e ...) : Int
  #:where
  (e : Int) ...)

(define-simple-syntax/type-rule
  (λ ([x : τ] ...) e) : (τ ... → τ_body)
  #:where
  (let τ_body := (typeof e)))

(define-simple-syntax/type-rule
  (#%app f e ...) : τ2
  #:where
  (let (τ1 ... → τ2) := (typeof f))
  (e : τ1) ...)
