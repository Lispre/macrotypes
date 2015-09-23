#lang s-exp "typecheck.rkt"
(require (except-in "stlc+reco+sub.rkt" #%app λ +)
         (prefix-in stlc: (only-in "stlc+reco+sub.rkt" #%app λ))
         (only-in "sysf.rkt" ∀?)
         (prefix-in sysf: (only-in "sysf.rkt" ∀))
         (rename-in (only-in "sysf.rkt" ~∀) [~∀ ~sysf:∀]))
(provide (rename-out [stlc:#%app #%app] [stlc:λ λ]))
(provide (except-out (all-from-out "stlc+reco+sub.rkt") stlc:#%app stlc:λ)
         (except-out (all-from-out "sysf.rkt") sysf:∀ (for-syntax ~sysf:∀)))
(provide ∀ Λ inst)
 
;; System F<:
;; Types:
;; - types from sysf.rkt
;; - extend ∀ with bounds
;; Terms:
;; - terms from sysf.rkt
;; - extend Λ and inst
;; Other
;; - current-promote, expose
;; - extend current-sub? to call current-promote

(define-primop + : (→ Nat Nat Nat))

; can't just call expose in type-eval,
; otherwise typevars will have bound as type, rather than instantiated type
; only need expose during
; 1) subtype checking
; 2) pattern matching -- including base types
(begin-for-syntax
  (define (expose t)
    (cond [(identifier? t)
           (define sub (typeof t #:tag 'sub))
           (if sub (expose sub) t)]
          [else t]))
  (current-promote expose)
  (define stlc:sub? (current-sub?))
  (define (sub? t1 t2)
    (stlc:sub? ((current-promote) t1) t2))
  (current-sub? sub?)
  (current-typecheck-relation (current-sub?)))

; quasi-kind, but must be type constructor because its arguments are types
(define-type-constructor <: #:arity >= 0) 
(begin-for-syntax
  (current-type? (λ (t) (or (type? t) (<:? (typeof t))))))

;; Type annotations used in two places:
;; 1) typechecking the body of 
;; 2) instantiation of ∀
;; Problem: need type annotations, even in expanded form
;; Solution: store type annotations in a (quasi) kind <:
(define-syntax ∀
  (syntax-parser #:datum-literals (<:)
    [(_ ([tv:id <: τ:type] ...) τ_body)
     ; eval first to overwrite the old #%type
     (⊢ #,((current-type-eval) #'(sysf:∀ (tv ...) τ_body)) : (<: τ.norm ...))]))
(begin-for-syntax
  (define-syntax ~∀
    (pattern-expander
     (syntax-parser #:datum-literals (<:)
       [(_ ([tv:id <: τ_sub] ...) τ)
        #'(~and ∀τ
                (~parse (~sysf:∀ (tv ...) τ) #'∀τ)
                (~parse (~<: τ_sub ...) (typeof #'∀τ)))]
       [(_ . args)
        #'(~and ∀τ
                (~parse (~sysf:∀ (tv (... ...)) τ) #'∀τ)
                (~parse (~<: τ_sub (... ...)) (typeof #'∀τ))
                (~parse args #'(([tv τ_sub] (... ...)) τ)))])))
  (define-syntax ~∀*
    (pattern-expander
     (syntax-parser #:datum-literals (<:)
       [(_ . args)
        #'(~or
           (~∀ . args)
           (~and any (~do
                      (type-error
                       #:src #'any
                       #:msg "Expected ∀ type, got: ~a" #'any))))]))))

(define-syntax (Λ stx)
  (syntax-parse stx #:datum-literals (<:)
    [(_ ([tv:id <: τsub:type] ...) e)
     ;; NOTE: store the subtyping relation of tv and τsub in another
     ;; "environment", ie, a syntax property with another tag: 'sub
     ;; The "expose" function looks for this tag to enforce the bound,
     ;; as in TaPL (fig 28-1)
     #:with ((tv- ...) _ (e-) (τ_e)) (infer #'(e) #:tvctx #'([tv : #%type] ...)
                                                  #:octx  #'([tv : τsub] ...) #:tag 'sub)
     (⊢ e- : (∀ ([tv- <: τsub] ...) τ_e))]))
(define-syntax (inst stx)
  (syntax-parse stx
    [(_ e τ:type ...)
     #:with (e- (([tv τ_sub] ...) τ_body)) (⇑ e as ∀)
     #:when (typechecks? #'(τ.norm ...) #'(τ_sub ...))
     (⊢ e- : #,(substs #'(τ.norm ...) #'(tv ...) #'τ_body))]))

