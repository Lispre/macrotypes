#lang racket/base
(require "typecheck.rkt")
(require (prefix-in stlc: (only-in "stlc+reco+var.rkt" #%app))
         (except-in "stlc+reco+var.rkt" #%app))
(provide (rename-out [stlc:#%app #%app] [cons/tc cons]))
(provide (except-out (all-from-out "stlc+reco+var.rkt") stlc:#%app))
(provide nil isnil head tail)

;; Simply-Typed Lambda Calculus, plus cons
;; Types:
;; - types from stlc+reco+var.rkt
;; - List constructor
;; Terms:
;; - terms from stlc+reco+var.rkt

;; TODO: enable HO use of list primitives

;(define-type-constructor (List τ) #:declare τ type)
(define-basic-checked-stx List #:arity = 1)

(define-syntax (nil stx)
  (syntax-parse stx
    [(_ ~! τi:ann)
     (⊢ null : (List τi.τ))]
    [null:id
     #:fail-when #t (error 'nil "requires type annotation")
     #'null]))
(define-syntax (cons/tc stx)
  (syntax-parse stx
    [(_ e1 e2)
     #:with (e1- τ1) (infer+erase #'e1)
;     #:with (e2- (τ2)) (inferList+erase #'e2)
     #:with (e2- (τ2)) (⇑ e2 as List)
;     #:with (e2- τ-lst) (infer+erase #'e2)
;     #:with τ2 (List-get τ from τ-lst)
     #:when (typecheck? #'τ1 #'τ2)
     (⊢ (cons e1- e2-) : (List τ1))]))
(define-syntax (isnil stx)
  (syntax-parse stx
    [(_ e)
;     #:with (e- _) (inferList+erase #'e)
     #:with (e- _) (⇑ e as List)
;     #:with (e- τ-lst) (infer+erase #'e)
;     #:fail-unless (List? #'τ-lst) "expected argument of List type"
     (⊢ (null? e-) : Bool)]))
(define-syntax (head stx)
  (syntax-parse stx
    [(_ e)
;     #:with (e- (τ)) (inferList+erase #'e)
     #:with (e- (τ)) (⇑ e as List)
;     #:with (e- τ-lst) (infer+erase #'e)
;     #:with τ (List-get τ from τ-lst)
     (⊢ (car e-) : τ)]))
(define-syntax (tail stx)
  (syntax-parse stx
    [(_ e)
     #:with (e- τ-lst) (infer+erase #'e)
     #:when (List? #'τ-lst)
     (⊢ (cdr e-) : τ-lst)]))