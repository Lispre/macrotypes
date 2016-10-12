#lang turnstile/lang
(extends "sysf.rkt" #:except #%datum ∀ ~∀ ∀? Λ inst)
(reuse String #%datum #:from "stlc+reco+var.rkt")

; same as fomega.rkt except here λ and #%app works as both type and terms
; - uses definition from stlc, but tweaks type? and kind? predicates
;; → is also both type and kind

;; System F_omega
;; Type relation:
;; Types:
;; - types from sysf.rkt
;; - String from stlc+reco+var
;; Terms:
;; - extend ∀ Λ inst from sysf
;; - #%datum from stlc+reco+var

(provide define-type-alias
         ★ ∀★ ∀
         Λ inst)

(define-syntax-category kind)

(begin-for-syntax
  (current-kind? (λ (k) (or (#%type? k) (kind? k) (#%type? (typeof k)))))
  ;; Try to keep "type?" backward compatible with its uses so far,
  ;; eg in the definition of λ or previous type constuctors.
  ;; (However, this is not completely possible, eg define-type-alias)
  ;; So now "type?" no longer validates types, rather it's a subset.
  ;; But we no longer need type? to validate types, instead we can use
  ;; (kind? (typeof t))
  (current-type? (λ (t) (or (type? t)
                            (let ([k (typeof t)])
                              (or (★? k) (∀★? k)))
                            ((current-kind?) t)))))

; must override
(define-syntax define-type-alias
  (syntax-parser
    [(_ alias:id τ)
     #:with (τ- k_τ) (infer+erase #'τ)
     #'(define-syntax alias
         (syntax-parser [x:id #'τ-][(_ . rst) #'(τ- . rst)]))]))

(define-base-kind ★)
(define-kind-constructor ∀★ #:arity >= 0)
(define-type-constructor ∀ #:bvs >= 0 #:arr ∀★)

;; alternative: normalize before type=?
; but then also need to normalize in current-promote
(begin-for-syntax
  (define (normalize τ)
    (syntax-parse τ #:literals (#%plain-app #%plain-lambda)
      [x:id #'x]
      [(#%plain-app 
        (#%plain-lambda (tv ...) τ_body) τ_arg ...)
       (normalize (substs #'(τ_arg ...) #'(tv ...) #'τ_body))]
      [(#%plain-lambda (x ...) . bodys)
       #:with bodys_norm (stx-map normalize #'bodys)
       (transfer-stx-props #'(#%plain-lambda (x ...) . bodys_norm) τ #:ctx τ)]
      [(#%plain-app x:id . args)
       #:with args_norm (stx-map normalize #'args)
       (transfer-stx-props #'(#%plain-app x . args_norm) τ #:ctx τ)]
      [(#%plain-app . args)
       #:with args_norm (stx-map normalize #'args)
       (transfer-stx-props (normalize #'(#%plain-app . args_norm)) τ #:ctx τ)]
      [_ τ]))
  
  (define old-eval (current-type-eval))
  (define (type-eval τ) (normalize (old-eval τ)))
  (current-type-eval type-eval)
  
  (define old-type=? (current-type=?))
  (define (type=? t1 t2)
    (or (and (★? t1) (#%type? t2))
        (and (#%type? t1) (★? t2))
        (and (syntax-parse (list t1 t2) #:datum-literals (:)
               [((~∀ ([tv1 : k1]) tbody1)
                 (~∀ ([tv2 : k2]) tbody2))
                ((current-type=?) #'k1 #'k2)]
               [_ #t])
             (old-type=? t1 t2))))
  (current-type=? type=?)
  (current-typecheck-relation (current-type=?)))

(define-typed-syntax (Λ bvs:kind-ctx e) ≫
  [[bvs.x ≫ tv- : bvs.kind] ... ⊢ e ≫ e- ⇒ τ_e]
  --------
  [⊢ e- ⇒ (∀ ([tv- : bvs.kind] ...) τ_e)])

(define-typed-syntax (inst e τ ...) ≫
  [⊢ e ≫ e- ⇒ : (~∀ (tv ...) τ_body) (⇒ : (~∀★ k ...))]
  [⊢ τ ≫ τ- ⇐ k] ...
  #:with τ-inst (substs #'(τ- ...) #'(tv ...) #'τ_body)
  --------
  [⊢ e- ⇒ τ-inst])

