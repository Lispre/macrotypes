#lang s-exp macrotypes/typecheck
(extends "sysf.rkt" #:except #%datum ∀ ∀- ~∀ ∀? Λ inst)
(reuse String #%datum #:from "stlc+reco+var.rkt")

;; System F_omega
;; Type relation:
;; Types:
;; - types from sysf.rkt
;; - String from stlc+reco+var
;; Terms:
;; - extend ∀ Λ inst from sysf
;; - add tyλ and tyapp
;; - #%datum from stlc+reco+var

(provide (for-syntax current-kind?)
         define-type-alias
         (type-out ★ ⇒ ∀★ ∀)
         Λ inst tyλ tyapp)

(define-syntax-category :: kind :::)

; want #%type to be equiv to★
; => edit current-kind? so existing #%type annotations (with no #%kind tag)
;    are treated as kinds
; <= define ★ as rename-transformer expanding to #%type
(begin-for-syntax
  (current-kind? (λ (k) (or (#%type? k) (kind? k))))
  ;; Try to keep "type?" backward compatible with its uses so far,
  ;; eg in the definition of λ or previous type constuctors.
  ;; (However, this is not completely possible, eg define-type-alias)
  ;; So now "type?" no longer validates types, rather it's a subset.
  ;; But we no longer need type? to validate types, instead we can use 
  ;; (kind? (typeof t))
  (current-type? (λ (t)
                   (define k (kindof t))
                   #;(or (type? t) (★? (typeof t)) (∀★? (typeof t)))
                   (and k ((current-kind?) k) (not (⇒? k)))))
  ;; o.w., a valid type is one with any valid kind
  (current-any-type? (λ (t) 
                       (define k (kindof t))
                       (and k ((current-kind?) k)))))


; must override, to handle kinds
(define-syntax define-type-alias
  (syntax-parser
    [(_ alias:id τ)
     #:with (τ- k_τ) (infer+erase #'τ #:tag '::)
     #:fail-unless ((current-kind?) #'k_τ)
                   (format "not a valid type: ~a\n" (type->str #'τ))
     #'(define-syntax alias 
         (syntax-parser [x:id #'τ-][(_ . rst) #'(τ- . rst)]))]))

(begin-for-syntax
  (define ★? #%type?)
  (define-syntax ~★ (lambda _ (error "~★ not implemented")))) ; placeholder
(define-syntax ★ (make-rename-transformer #'#%type))
(define-kind-constructor ⇒ #:arity >= 1)
(define-kind-constructor ∀★ #:arity >= 0)

(define-binding-type ∀ #:arr ∀★)

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
       #:with res (normalize #'(#%plain-app . args_norm))
       (transfer-stx-props #'res τ #:ctx τ)]
      [_ τ]))
  
  (define old-eval (current-type-eval))
  (define (type-eval τ) (normalize (old-eval τ)))
  (current-type-eval type-eval)
  
  (define old-type=? (current-type=?))
  ; ty=? == syntax eq and syntax prop eq
  (define (type=? t1 t2)
    (let ([k1 (kindof t1)][k2 (kindof t2)])
      (and (or (and (not k1) (not k2))
               (and k1 k2 ((current-kind=?) k1 k2)))
           (old-type=? t1 t2))))
  (current-type=? type=?)
  (current-typecheck-relation (current-type=?)))

(define-typed-syntax Λ
  [(_ bvs:kind-ctx e)
   #:with ((tv- ...) e- τ_e) (infer/ctx+erase #'bvs #'e)
   (⊢ e- : (∀ ([tv- :: bvs.kind] ...) τ_e))])

(define-typed-syntax inst
  [(_ e τ:any-type ...)
   #:with [e- τ_e] (infer+erase #'e)
   #:with (~∀ (tv ...) τ_body) #'τ_e
   #:with (~∀★ k ...) (kindof #'τ_e)
;   #:with ([τ- k_τ] ...) (infers+erase #'(τ ...) #:tag '::)
   #:with (k_τ ...) (stx-map kindof #'(τ.norm ...))
   #:fail-unless (kindchecks? #'(k_τ ...) #'(k ...))
                 (typecheck-fail-msg/multi 
                  #'(k ...) #'(k_τ ...) #'(τ ...))
   #:with τ_inst (substs #'(τ.norm ...) #'(tv ...) #'τ_body)
   (⊢ e- : τ_inst)])

;; TODO: merge with regular λ and app?
;; - see fomega2.rkt
(define-typed-syntax tyλ
  [(_ bvs:kind-ctx τ_body)
   #:with (tvs- τ_body- k_body) (infer/ctx+erase #'bvs #'τ_body #:tag '::)
   #:fail-unless ((current-kind?) #'k_body)
                 (format "not a valid type: ~a\n" (type->str #'τ_body))
   (⊢ (λ- tvs- τ_body-) :: (⇒ bvs.kind ... k_body))])

(define-typed-syntax tyapp
  [(_ τ_fn τ_arg ...)
;   #:with [τ_fn- (k_in ... k_out)] (⇑ τ_fn as ⇒)
   #:with [τ_fn- (~⇒ k_in ... k_out)] (infer+erase #'τ_fn #:tag '::)
   #:with ([τ_arg- k_arg] ...) (infers+erase #'(τ_arg ...) #:tag '::)
   #:fail-unless (kindchecks? #'(k_arg ...) #'(k_in ...))
                 (string-append
                  (format 
                   "~a (~a:~a) Arguments to function ~a have wrong kinds(s), "
                   (syntax-source stx) (syntax-line stx) (syntax-column stx)
                   (syntax->datum #'τ_fn))
                  "or wrong number of arguments:\nGiven:\n"
                  (string-join
                   (map (λ (e t) (format "  ~a : ~a" e t)) ; indent each line
                        (syntax->datum #'(τ_arg ...))
                        (stx-map type->str #'(k_arg ...)))
                   "\n" #:after-last "\n")
                  (format "Expected: ~a arguments with type(s): "
                          (stx-length #'(k_in ...)))
                  (string-join (stx-map type->str #'(k_in ...)) ", "))
   (⊢ (#%app- τ_fn- τ_arg- ...) :: k_out)])
