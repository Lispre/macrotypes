#lang turnstile/lang
(extends "ext-stlc.rkt")

(require (for-syntax racket/list))

;; Simply-Typed Lambda Calculus, plus tuples
;; Types:
;; - types from ext-stlc.rkt
;; - ×
;; Terms:
;; - terms from ext-stlc.rkt
;; - tup and proj

(define-type-constructor × #:arity >= 0
  #:arg-variances (λ (stx)
                    (make-list (stx-length (stx-cdr stx)) covariant)))

(define-typed-syntax tup
  [(_ e ...) ⇐ (~× τ ...) ≫
   #:when (stx-length=? #'[e ...] #'[τ ...])
   [⊢ e ≫ e- ⇐ τ] ...
   --------
   [⊢ (list- e- ...)]]
  [(_ e ...) ≫
   [⊢ e ≫ e- ⇒ τ] ...
   --------
   [⊢ (list- e- ...) ⇒ (× τ ...)]])

(define-typed-syntax proj
  [(_ e_tup n:nat) ≫
   [⊢ e_tup ≫ e_tup- ⇒ (~× τ ...)]
   #:fail-unless (< (syntax-e #'n) (stx-length #'[τ ...])) "index too large"
   --------
   [⊢ (list-ref- e_tup- n) ⇒ #,(stx-list-ref #'[τ ...] (syntax-e #'n))]])

