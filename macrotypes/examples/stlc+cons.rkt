#lang s-exp macrotypes/typecheck
(extends "stlc+reco+var.rkt")

;; Simply-Typed Lambda Calculus, plus cons
;; Types:
;; - types from stlc+reco+var.rkt
;; - List constructor
;; Terms:
;; - terms from stlc+reco+var.rkt

;; TODO: enable HO use of list primitives

(define-type-constructor List)

(define-typed-syntax nil
  [(nil ~! τi:type-ann)
   (⊢ null- : (List τi.norm))]
  ; minimal type inference
  [nil:id #:with expected-τ (get-expected-type #'nil)
          #:fail-unless (syntax-e #'expected-τ) ; 'expected-type property exists (ie, not false)
          (raise (exn:fail:type:infer
                  (format "~a (~a:~a): nil: ~a"
                          (syntax-source stx) (syntax-line stx) (syntax-column stx)
                          (no-expected-type-fail-msg))
                  (current-continuation-marks)))
          #:fail-unless (List? #'expected-τ)
          (raise (exn:fail:type:infer
                  (format "~a (~a:~a): Inferred ~a type for nil, which is not a List."
                          (syntax-source stx) (syntax-line stx) (syntax-column stx)
                          (type->str #'ty_lst))
                  (current-continuation-marks)))
          (⊢ null- : expected-τ)])
(define-typed-syntax cons
  [(cons e1 e2)
   #:with [e1- τ_e1] (infer+erase #'e1)
   #:with τ_list ((current-type-eval) #'(List τ_e1))
   #:with [e2- τ_e2] (infer+erase (add-expected-ty #'e2 #'τ_list))
   #:fail-unless (typecheck? #'τ_e2 #'τ_list)
   (typecheck-fail-msg/1 #'τ_list #'τ_e2 #'e2)
   ;; propagate up inferred types of variables
   #:with env (stx-flatten (filter (λ (x) x) (stx-map get-env #'(e1- e2-))))
   #:with result-cons (add-env #'(cons- e1- e2-) #'env)
   (⊢ result-cons : τ_list)])
(define-typed-syntax isnil
  [(isnil e)
   #:with [e- (~List _)] (infer+erase #'e)
   (⊢ (null?- e-) : Bool)])
(define-typed-syntax head
  [(head e)
   #:with [e- (~List τ)] (infer+erase #'e)
   (⊢ (car- e-) : τ)])
(define-typed-syntax tail
  [(tail e)
   #:with [e- τ_lst] (infer+erase #'e)
   #:when (List? #'τ_lst)
   (⊢ (cdr- e-) : τ_lst)])
(define-typed-syntax list
  [(list) #'nil]
  [(_ x . rst) ; has expected type
   #:with expected-τ (get-expected-type stx)
   #:when (syntax-e #'expected-τ)
   #:with (~List τ) (local-expand #'expected-τ 'expression null)
   #'(cons (add-expected x τ) (list . rst))]
  [(_ x . rst) ; no expected type
   #'(cons x (list . rst))])
(define-typed-syntax reverse
  [(reverse e)
   #:with (e- τ-lst) (infer+erase #'e)
   #:when (List? #'τ-lst)
   (⊢ (reverse- e-) : τ-lst)])
(define-typed-syntax length
  [(length e)
   #:with (e- τ-lst) (infer+erase #'e)
   #:when (List? #'τ-lst)
   (⊢ (length- e-) : Int)])
(define-typed-syntax list-ref
  [(list-ref e n)
   #:with (e- (ty)) (⇑ e as List)
   #:with n- (⇑ n as Int)
   (⊢ (list-ref- e- n-) : ty)])
(define-typed-syntax member
  [(member v e)
   #:with (e- (ty)) (⇑ e as List)
   #:with [v- ty_v] (infer+erase #'(add-expected v ty))
   #:when (typecheck? #'ty_v #'ty)
   (⊢ (member- v- e-) : Bool)])
