#lang racket/base
(require
  (for-syntax racket/base syntax/parse syntax/stx racket/syntax racket/string
              "stx-utils.rkt" "typecheck.rkt")
  (for-meta 2 racket/base syntax/parse racket/syntax)
  "typecheck.rkt")
(require (prefix-in stlc: (only-in "stlc+cons.rkt" #%app λ))
         (except-in "stlc+cons.rkt" #%app λ))
(provide (rename-out [stlc:#%app #%app] [stlc:λ λ]))
(provide (all-from-out "stlc+cons.rkt"))
(provide ref deref :=)

;; Simply-Typed Lambda Calculus, plus mutable references
;; Types:
;; - types from stlc+cons.rkt
;; - Ref constructor
;; Terms:
;; - terms from stlc+cons.rkt

(define-type-constructor Ref)

(define-syntax (ref stx)
  (syntax-parse stx
    [(_ e)
     #:with (e- τ) (infer+erase #'e)
     (⊢ #'(box e-) #'(Ref τ))]))
(define-syntax (deref stx)
  (syntax-parse stx
    [(_ e)
     #:with (e- ((~literal Ref) τ)) (infer+erase #'e)
     (⊢ #'(unbox e-) #'τ)]))
(define-syntax (:= stx)
  (syntax-parse stx
    [(_ e_ref e)
     #:with (e_ref- ((~literal Ref) τ1)) (infer+erase #'e_ref)
     #:with (e- τ2) (infer+erase #'e)
     #:when (τ= #'τ1 #'τ2)
     (⊢ #'(set-box! e_ref- e-) #'Unit)]))