#lang racket/base
(require "typecheck.rkt")
(require (except-in "stlc+reco+var.rkt" #%app λ let type=?)
         (prefix-in stlc: (only-in "stlc+reco+var.rkt" #%app λ let))
         (only-in "stlc+rec-iso.rkt" type=?))
(provide (rename-out [stlc:#%app #%app] [stlc:λ λ] [stlc:let let]))
(provide (except-out (all-from-out "stlc+reco+var.rkt") stlc:#%app stlc:λ stlc:let)
         (all-from-out "stlc+rec-iso.rkt"))
(provide ∃ pack open)

;; existential types
;; combine type=? from sysf (for lam, ie ∃) and stlc+reco+var (for strings)
;; Types:
;; - types from stlc+reco+var.rkt
;; - ∃
;; Terms:
;; - terms from stlc+reco+var.rkt
;; - pack and open

#;(begin-for-syntax
  (define (type=? t1 t2)
    (or (stlc:type=? t1 t2)
        (sysf:type=? t1 t2)))
  (current-type=? type=?)
  (current-typecheck-relation type=?))


#;(define-type-constructor (∃ [[X]] τ_body))
(define-basic-checked-stx ∃ #:arity = 1 #:bvs = 1)
; this is exactly the same as μ
;(define-syntax ∃
;  (syntax-parser
;    [(_ (tv:id) τ_body)
;     #:with ((tv-) τ_body- k) (infer/ctx+erase #'([tv : #%type]) #'τ_body)
;     #:when (#%type? #'k)
;     (mk-type #'(λ (tv-) τ_body-))]))
;(begin-for-syntax
;  #;(define (infer∃+erase e)
;    (syntax-parse (infer+erase e) #:context e
;      [(e- τ_e)
;       #:with ((~literal #%plain-lambda) (tv) τ) #'τ_e
;       #'(e- (tv τ))]))
;  (define-syntax ~∃
;    (pattern-expander
;     (syntax-parser
;       [(_ (tv:id) τ)
;        #'((~literal #%plain-lambda) (tv) τ)])))
;  (define-syntax ~∃*
;    (pattern-expander
;     (syntax-parser
;       [(_ (tv:id) τ)
;        #'(~or (~∃ (tv) τ)
;               (~and any (~do
;                          (type-error
;                           #:src #'any
;                           #:msg "Expected ∃ type, got: ~a" #'any))))]))))

(define-syntax (pack stx)
  (syntax-parse stx
    [(_ (τ:type e) as ∃τ:type)
     #:with (~∃* (τ_abstract) τ_body) #'∃τ.norm
;     #:with (#%plain-lambda (τ_abstract:id) τ_body) #'∃τ.norm
     #:with [e- τ_e] (infer+erase #'e)
     #:when (typecheck? #'τ_e  (subst #'τ.norm #'τ_abstract #'τ_body))
     (⊢ e- : ∃τ)]))

(define-syntax (open stx)
  (syntax-parse stx #:datum-literals (<=)
    [(_ ([(tv:id x:id) <= e_packed]) e)
;     #:with [e_packed- τ_packed] (infer+erase #'e_packed)
;     #:when (displayln #'τ_packed)
;     #:with (~∃ (τ_abstract) τ_body) #'τ_packed
     #:with [e_packed- ((τ_abstract) (τ_body))] (⇑ e_packed as ∃)
;     #:with [e_packed- (τ_abstract τ_body)] (infer∃+erase #'e_packed)
;     #:with [e_packed- τ_packed] (infer+erase #'e_packed)
;     #:with (#%plain-lambda (τ_abstract:id) τ_body) #'τ_packed ; existential
     ;; The subst below appears to be a hack, but it's not really.
     ;; It's the (TaPL) type rule itself that is fast and loose.
     ;; Leveraging the macro system's management of binding reveals this.
     ;; 
     ;; Specifically, here is the TaPL Unpack type rule, fig24-1, p366:
     ;; Γ ⊢ t_1 : {∃X,T_12}
     ;; Γ,X,x:T_12 ⊢ t_2 : T_2
     ;; ------------------------------
     ;; Γ ⊢ let {X,x}=t_1 in t_2 : T_2
     ;;
     ;; There's *two* separate binders, the ∃ and the let,
     ;; which the rule conflates.
     ;;
     ;; Here's the rule rewritten to distinguish the two binding positions:
     ;; Γ ⊢ t_1 : {∃X_1,T_12}
     ;; Γ,X_???,x:T_12 ⊢ t_2 : T_2
     ;; ------------------------------
     ;; Γ ⊢ let {X_2,x}=t_1 in t_2 : T_2
     ;;
     ;; The X_1 binds references to X in T_12.
     ;; The X_2 binds references to X in t_2.
     ;; What should the X_??? be?
     ;;
     ;; A first guess might be to replace X_??? with both X_1 and X_2,
     ;; so all the potentially referenced type vars are bound.
     ;; Γ ⊢ t_1 : {∃X_1,T_12}
     ;; Γ,X_1,X_2,x:T_12 ⊢ t_2 : T_2
     ;; ------------------------------
     ;; Γ ⊢ let {X_2,x}=t_1 in t_2 : T_2
     ;;
     ;; But this example demonstrates that the rule above doesnt work:
     ;; (open ([x : X_2 (pack (Int 0) as (∃ (X_1) X_1))])
     ;;   ((λ ([y : X_2]) y) x)
     ;; Here, x has type X_1, y has type X_2, but they should be the same thing,
     ;; so we need to replace all X_1's with X_2
     ;;
     ;; Here's the fixed rule, which is implemented here
     ;;
     ;; Γ ⊢ t_1 : {∃X_1,T_12}
     ;; Γ,X_2,x:[X_2/X_1]T_12 ⊢ t_2 : T_2
     ;; ------------------------------
     ;; Γ ⊢ let {X_2,x}=t_1 in t_2 : T_2
     ;;
     #:with [_ (x-) (e-) (τ_e)]
            (infer #'(e) #:tvctx #'([tv : #%type]) #:ctx #`([x : #,(subst #'tv #'τ_abstract #'τ_body)]))
     (⊢ (let ([x- e_packed-]) e-) : τ_e)]))