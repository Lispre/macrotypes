#lang s-exp "typecheck.rkt"
(extends "stlc+reco+var.rkt")

;; Simply-Typed Lambda Calculus, plus cons
;; Types:
;; - types from stlc+reco+var.rkt
;; - List constructor
;; Terms:
;; - terms from stlc+reco+var.rkt

;; TODO: enable HO use of list primitives

(define-type-constructor List)

(define-typed-syntax nil/tc #:export-as nil
  [(~and ni (_ ~! τi:type-ann))
   (⊢ null : (List τi.norm))]
  ; minimal type inference
  [ni:id #:with expected-τ (get-expected-type #'ni)
         #:when (syntax-e #'expected-τ) ; 'expected-type property exists (ie, not false)
         #:with (~List τ) (local-expand #'expected-τ 'expression null) ; canonicalize
         (⊢ null : (List τ))]
  [_:id #:fail-when #t
        (raise (exn:fail:type:infer
                (format "~a (~a:~a): nil requires type annotation"
                        (syntax-source stx) (syntax-line stx) (syntax-column stx))
                (current-continuation-marks)))
        #'(void)])
(define-typed-syntax cons/tc #:export-as cons
  [(_ e1 e2)
   #:with [e1- τ1] (infer+erase #'e1)
;   #:with e2ann (add-expected-type #'e2 #'(List τ1))
   #:with (e2- (τ2)) (⇑ (add-expected e2 (List τ1)) as List)
   #:fail-unless (typecheck? #'τ1 #'τ2)
                 (format "trying to cons expression ~a with type ~a to list ~a with type ~a\n"
                         (syntax->datum #'e1) (type->str #'τ1)
                         (syntax->datum #'e2) (type->str #'(List τ2)))
   ;; propagate up inferred types of variables
   #:with env (stx-flatten (filter (λ (x) x) (stx-map get-env #'(e1- e2-))))
   #:with result-cons (add-env #'(cons e1- e2-) #'env)
   (⊢ result-cons : (List τ1))])
(define-typed-syntax isnil
  [(_ e)
   #:with (e- _) (⇑ e as List)
   (⊢ (null? e-) : Bool)])
(define-typed-syntax head
  [(_ e)
   #:with (e- (τ)) (⇑ e as List)
   (⊢ (car e-) : τ)])
(define-typed-syntax tail
  [(_ e)
   #:with (e- τ-lst) (infer+erase #'e)
   #:when (List? #'τ-lst)
   (⊢ (cdr e-) : τ-lst)])
(define-typed-syntax list/tc #:export-as list
  [(_) #'nil/tc]
  [(~and lst (_ x . rst)) ; has expected type
   #:with expected-τ (get-expected-type #'lst)
   #:when (syntax-e #'expected-τ)
   #:with (~List τ) (local-expand #'expected-τ 'expression null)
   #'(cons/tc (add-expected x τ) (list/tc . rst))]
  [(_ x . rst) ; no expected type
   #'(cons/tc x (list/tc . rst))])
(define-typed-syntax reverse
  [(_ e)
   #:with (e- τ-lst) (infer+erase #'e)
   #:when (List? #'τ-lst)
   (⊢ (reverse e-) : τ-lst)])
