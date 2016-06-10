#lang s-exp "typecheck.rkt"
(extends "sysf.rkt" #:except #%datum ∀ Λ inst)
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

(define-syntax-category kind)

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
  ;; But we no longer need type? to validate types, instead we can use (kind? (typeof t))
  (current-type? (λ (t)
                   (define k (typeof t))
                   #;(or (type? t) (★? (typeof t)) (∀★? (typeof t)))
                   (and ((current-kind?) k) (not (⇒? k))))))

; must override, to handle kinds
(provide define-type-alias)
(define-syntax define-type-alias
  (syntax-parser
    [(_ alias:id τ)
     #:with (τ- k_τ) (infer+erase #'τ)
     #:fail-unless ((current-kind?) #'k_τ) (format "not a valid type: ~a\n" (type->str #'τ))
     #'(define-syntax alias (syntax-parser [x:id #'τ-][(_ . rst) #'(τ- . rst)]))]))

(provide ★ (for-syntax ★?))
(define-for-syntax ★? #%type?)
(define-syntax ★ (make-rename-transformer #'#%type))
(define-kind-constructor ⇒ #:arity >= 1)
(define-kind-constructor ∀★ #:arity >= 0)

(define-type-constructor ∀ #:bvs >= 0 #:arr ∀★)

;; alternative: normalize before type=?
; but then also need to normalize in current-promote
(begin-for-syntax
  (define (normalize τ)
    (syntax-parse τ
      [x:id #'x]
      [((~literal #%plain-app) 
        ((~literal #%plain-lambda) (tv ...) τ_body) τ_arg ...)
       (normalize (substs #'(τ_arg ...) #'(tv ...) #'τ_body))]
      [((~literal #%plain-lambda) (x ...) . bodys)
       #:with bodys_norm (stx-map normalize #'bodys)
       (transfer-stx-props #'(#%plain-lambda (x ...) . bodys_norm) τ #:ctx τ)]
      [((~literal #%plain-app) x:id . args)
       #:with args_norm (stx-map normalize #'args)
       (transfer-stx-props #'(#%plain-app x . args_norm) τ #:ctx τ)]
      [((~literal #%plain-app) . args)
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
    (let ([k1 (typeof t1)][k2 (typeof t2)])
      (and (or (and (not k1) (not k2))
               (and k1 k2 ((current-type=?) k1 k2)))
           (old-type=? t1 t2))))
  (current-type=? type=?)
  (current-typecheck-relation (current-type=?)))

(define-typed-syntax Λ
  [(_ bvs:kind-ctx e)
   #:with ((tv- ...) e- τ_e) (infer/ctx+erase #'bvs #'e)
   (⊢ e- : (∀ ([tv- : bvs.kind] ...) τ_e))])

(define-typed-syntax inst
  [(_ e τ ...)
   #:with (e- (([tv k] ...) (τ_body))) (⇑ e as ∀)
   #:with ([τ- k_τ] ...) (infers+erase #'(τ ...))
   #:when (stx-andmap
           (λ (t k) (or ((current-kind?) k)
                        (type-error #:src t #:msg "not a valid type: ~a" t)))
           #'(τ ...) #'(k_τ ...))
   #:when (typechecks? #'(k_τ ...) #'(k ...))
   (⊢ e- : #,(substs #'(τ- ...) #'(tv ...) #'τ_body))])

;; TODO: merge with regular λ and app?
;; - see fomega2.rkt
(define-typed-syntax tyλ
  [(_ bvs:kind-ctx τ_body)
   #:with (tvs- τ_body- k_body) (infer/ctx+erase #'bvs #'τ_body)
   #:fail-unless ((current-kind?) #'k_body)
                 (format "not a valid type: ~a\n" (type->str #'τ_body))
   (⊢ (λ tvs- τ_body-) : (⇒ bvs.kind ... k_body))])

(define-typed-syntax tyapp
  [(_ τ_fn τ_arg ...)
   #:with [τ_fn- (k_in ... k_out)] (⇑ τ_fn as ⇒)
   #:with ([τ_arg- k_arg] ...) (infers+erase #'(τ_arg ...))
   #:fail-unless (typechecks? #'(k_arg ...) #'(k_in ...))
                 (string-append
                  (format "~a (~a:~a) Arguments to function ~a have wrong kinds(s), "
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
   (⊢ (#%app τ_fn- τ_arg- ...) : k_out)])
