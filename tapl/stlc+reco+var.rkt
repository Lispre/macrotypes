#lang racket/base
(require "typecheck.rkt")
(require (prefix-in stlc: (only-in "stlc+tup.rkt" #%app begin tup proj let type=?))
         (except-in "stlc+tup.rkt" #%app begin tup proj let type=?))
(provide (rename-out [stlc:#%app #%app] [stlc:let let] [stlc:begin begin]
                     [define/tc define]))
(provide (except-out (all-from-out "stlc+tup.rkt")
                     stlc:#%app stlc:let stlc:begin stlc:tup stlc:proj
                     (for-syntax stlc:type=?)))
(provide tup proj var case)
(provide (for-syntax type=?))


;; Simply-Typed Lambda Calculus, plus records and variants
;; Type relations:
;; - type=? extended to strings
;; define-type-alias (also provided to programmer)
;; Types:
;; - types from stlc+tup.rkt
;; - extend tuple type × to include records
;; - sum type constructor ∨
;; Terms:
;; - terms from stlc+tup.rkt
;; - extend tup to include records
;; - sums (var)
;; TopLevel:
;; - define (values only)

(begin-for-syntax
  ; extend to:
  ; 1) accept strings (ie, record labels)
  (define (type=? τ1 τ2)
    (syntax-parse (list τ1 τ2)
      [(s1:str s2:str) (string=? (syntax-e #'s1) (syntax-e #'s2))]
      [_ (stlc:type=? τ1 τ2)]))

  (current-type=? type=?)
  (current-typecheck-relation (current-type=?)))

(provide define-type-alias)
(define-syntax define-type-alias
  (syntax-parser
    [(_ alias:id τ:type)
     ; must eval, otherwise undefined types will be allowed
     #'(define-syntax alias (syntax-parser [x:id #'τ.norm]))]))

(define-type-constructor : #:arity 2)

;; records
(define-syntax (tup stx)
  (syntax-parse stx #:datum-literals (=)
    [(_ [l:str = e] ...)
     #:with ((e- τ) ...) (infers+erase #'(e ...))
     (⊢ #'(list (list l e-) ...) #'(× [: l τ] ...))]
    [(_ e ...)
     #'(stlc:tup e ...)]))
(define-syntax (proj stx)
  (syntax-parse stx #:literals (quote)
    [(_ rec l:str ~!)
     #:with (rec- τ_rec) (infer+erase #'rec)
     #:fail-unless (×? #'τ_rec) (format "not record type: ~a" (syntax->datum #'τ_rec))
     #:with (['l_τ:str τ] ...) (stx-map :-args (×-args #'τ_rec))
     #:with (l_match:str τ_match) (str-stx-assoc #'l #'([l_τ τ] ...))
     (⊢ #'(cadr (assoc l rec)) #'τ_match)]
    [(_ e ...) #'(stlc:proj e ...)]))


(define-type-constructor ∨)

(define-syntax (var stx)
  (syntax-parse stx #:datum-literals (as =) #:literals (quote)
    [(_ l:str = e as τ:type)
     #:when (∨? #'τ.norm)
     #:with (['l_τ:str τ_l] ...) (stx-map :-args (∨-args #'τ.norm))
     #:with (l_match:str τ_match) (str-stx-assoc #'l #'((l_τ τ_l) ...))
     #:with (e- τ_e) (infer+erase #'e)
     #:when (typecheck? #'τ_e #'τ_match)
     (⊢ #'(list l e) #'τ.norm)]))
(define-syntax (case stx)
  (syntax-parse stx #:datum-literals (of =>) #:literals (quote)
    [(_ e [l:str x => e_l] ...)
     #:fail-when (null? (syntax->list #'(l ...))) "no clauses"
     #:with (e- τ_e) (infer+erase #'e)
     #:when (∨? #'τ_e)
     #:with (['l_x:str τ_x] ...) (stx-map :-args (∨-args #'τ_e))
     #:fail-unless (= (stx-length #'(l ...)) (stx-length #'(l_x ...))) "wrong number of case clauses"
     #:fail-unless (typechecks? #'(l ...) #'(l_x ...)) "case clauses not exhaustive"
     #:with (((x-) e_l- τ_el) ...)
            (stx-map (λ (bs e) (infer/type-ctxt+erase bs e)) #'(([x : τ_x]) ...) #'(e_l ...))
     #:fail-unless (same-types? #'(τ_el ...)) "branches have different types"
     (⊢ #'(let ([l_e (car e-)])
            (cond [(string=? l_e l) (let ([x- (cadr e-)]) e_l-)] ...))
        (stx-car #'(τ_el ...)))]))

(define-syntax (define/tc stx)
  (syntax-parse stx
    [(_ x:id e)
     #:with (e- τ) (infer+erase #'e)
     #:with y (generate-temporary)
     #'(begin
         (define-syntax x (make-rename-transformer (⊢ #'y #'τ)))
         (define y e-))]))