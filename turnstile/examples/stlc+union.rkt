#lang turnstile
(extends "ext-stlc.rkt" 
 #:except #%app #%datum + add1 sub1 * Int Int? ~Int Float Float? ~Float)
(reuse define-type-alias #:from "stlc+reco+var.rkt")
(provide Int Num Nat U
         define-named-type-alias
         (for-syntax current-sub? prune+sort))

;; Simply-Typed Lambda Calculus, plus union types
;; Types:
;; - types from and ext+stlc.rkt
;; - Top, Num, Nat
;; - U
;; Type relations:
;; - sub?
;;   - Any <: Top
;;   - Nat <: Int
;;   - Int <: Num
;;   - →
;; Terms:
;; - terms from stlc+lit.rkt, except redefined: datum and +
;; - also *
;; Other: sub? current-sub?

(define-syntax define-named-type-alias
  (syntax-parser
    [(define-named-type-alias Name:id τ:type)
     #'(define-syntax Name
         (make-variable-like-transformer (add-orig #'τ #'Name)))]
    [(define-named-type-alias (f:id x:id ...) ty) ; dont expand yet
     #'(define-syntax (f stx)
         (syntax-parse stx
           [(_ x ...) (add-orig #'ty stx)]))]))


(define-base-types Zero NegInt PosInt Float)
(define-type-constructor U* #:arity > 0)

(define-for-syntax (prune+sort tys)
  (stx-sort 
   (remove-duplicates 
    (stx->list tys)
    ;; remove dups keeps first element
    ;; but we want to keep supertype
    (lambda (x y) (typecheck? y x)))))
  
(define-syntax (U stx)
  (syntax-parse stx
    [(_ . tys)
     ;; canonicalize by expanding to U*, with only (sorted and pruned) leaf tys
     #:with ((~or (~U* ty1- ...) ty2-) ...) (stx-map (current-type-eval) #'tys)
     #:with tys- (prune+sort #'(ty1- ... ... ty2- ...))
     (if (= 1 (stx-length #'tys-))
         (stx-car #'tys)
         #'(U* . tys-))]))
(define-syntax Nat
  (make-variable-like-transformer 
   (add-orig #'(U Zero PosInt) #'Nat)))
(define-syntax Int
  (make-variable-like-transformer 
   (add-orig #'(U NegInt Nat) #'Int)))
(define-syntax Num 
  (make-variable-like-transformer (add-orig #'(U Float Int) #'Num)))

(define-primop + : (→ Num Num Num))
(define-primop * : (→ Num Num Num))
(define-primop add1 : (→ Int Int))
(define-primop sub1 : (→ Int Int))

(define-typed-syntax datum #:export-as #%datum
  [(_ . n:integer) ≫
   #:with ty_out (let ([m (syntax-e #'n)])
                   (cond [(zero? m) #'Zero]
                         [(> m 0) #'PosInt]
                         [else #'NegInt]))
   --------
   [⊢ [_ ≫ (#%datum- . n) ⇒ : ty_out]]]
  [(#%datum . n:number) ≫
   #:when (real? (syntax-e #'n))
   --------
   [⊢ [_ ≫ (#%datum- . n) ⇒ : Float]]]
  [(_ . x) ≫
   --------
   [_ ≻ (ext-stlc:#%datum . x)]])

(define-typed-syntax app #:export-as #%app
  [(_ e_fn e_arg ...) ≫
   [⊢ [e_fn ≫ e_fn- ⇒ : (~→ ~! τ_in ... τ_out)]]
   #:fail-unless (stx-length=? #'[τ_in ...] #'[e_arg ...])
   (num-args-fail-msg #'e_fn #'[τ_in ...] #'[e_arg ...])
   [⊢ [e_arg ≫ e_arg- ⇐ : τ_in] ...]
   --------
   [⊢ [_ ≫ (#%app- e_fn- e_arg- ...) ⇒ : τ_out]]])

(begin-for-syntax
  (define (sub? t1 t2)
    ; need this because recursive calls made with unexpanded types
   ;; (define τ1 ((current-type-eval) t1))
   ;; (define τ2 ((current-type-eval) t2))
    ;; (printf "t1 = ~a\n" (syntax->datum t1))
    ;; (printf "t2 = ~a\n" (syntax->datum t2))
    (or 
     ((current-type=?) t1 t2)
     (syntax-parse (list t1 t2)
       ; 2 U types, subtype = subset
       [((~U* . tys1) (~U* . tys2))
        (for/and ([t (stx->list #'tys1)])
          ((current-sub?) t t2))]
       ; 1 U type, 1 non-U type. subtype = member
       [(ty (~U* . tys))
        (for/or ([t (stx->list #'tys)])
          ((current-sub?) #'ty t))]
       [((~→ s1 ... s2) (~→ t1 ... t2))
        (and (subs? #'(t1 ...) #'(s1 ...))
             ((current-sub?) #'s2 #'t2))]
       [_ #f])))
  (define current-sub? (make-parameter sub?))
  (current-typecheck-relation sub?)
  (define (subs? τs1 τs2)
    (and (stx-length=? τs1 τs2)
         (stx-andmap (current-sub?) τs1 τs2)))
  
  (define (join t1 t2) #`(U #,t1 #,t2))
  (current-join join))
                   
