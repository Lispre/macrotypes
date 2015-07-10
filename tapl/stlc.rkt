#lang racket/base
(require "typecheck.rkt")
(provide (rename-out [λ/tc λ] [app/tc #%app]))
(provide (for-syntax type=? types=? same-types? current-type=? type-eval))
(provide #%module-begin #%top-interaction #%top require) ; from racket
 
;; Simply-Typed Lambda Calculus
;; - no base type so cannot write any terms
;; Types: →
;; Terms:
;; - var
;; - multi-arg lambda
;; - multi-arg app

(begin-for-syntax
  ;; type eval
  ;; - for now, type-eval = full expansion
  ;; - must expand because:
  ;;   - checks for unbound identifiers (ie, undefined types)
  (define (type-eval τ)
    (add-orig (expand/df τ) τ))
  (current-type-eval type-eval))

(begin-for-syntax
  ;; type=? : Type Type -> Boolean
  ;; Indicates whether two types are equal
  ;; type equality == structurally free-identifier=?
  (define (type=? τ1 τ2)
;    (printf "(τ=) t1 = ~a\n" #;τ1 (syntax->datum τ1))
;    (printf "(τ=) t2 = ~a\n" #;τ2 (syntax->datum τ2))
    (syntax-parse (list τ1 τ2)
      [(x:id y:id) (free-identifier=? τ1 τ2)]
      [((τa ...) (τb ...)) (types=? #'(τa ...) #'(τb ...))]
      [_ #f]))

  (define current-type=? (make-parameter type=?))
  (current-typecheck-relation type=?)

  (define (types=? τs1 τs2)
    (and (= (stx-length τs1) (stx-length τs2))
         (stx-andmap (current-type=?) τs1 τs2)))
  (define (same-types? τs)
    (define τs-lst (syntax->list τs))
    (or (null? τs-lst)
        (andmap (λ (τ) ((current-type=?) (car τs-lst) τ)) (cdr τs-lst)))))

(define-type-constructor →)

(define-syntax (λ/tc stx)
  (syntax-parse stx 
    [(_ (b:typed-binding ...) e)
     #:with (xs- e- τ_res) (infer/type-ctxt+erase #'(b ...) #'e)
     (⊢ #'(λ xs- e-) #'(→ b.τ ... τ_res))]))

(define-syntax (app/tc stx)
  (syntax-parse stx
    [(_ e_fn e_arg ...)
     #:with (e_fn- τ_fn) (infer+erase #'e_fn)
     #:fail-unless (→? #'τ_fn)
                   (format "Type error: Attempting to apply a non-function ~a with type ~a\n"
                           (syntax->datum #'e_fn) (syntax->datum #'τ_fn))
     #:with (τ ... τ_res) (→-args #'τ_fn)
     #:with ((e_arg- τ_arg) ...) (infers+erase #'(e_arg ...))
     #:fail-unless (stx-length=? #'(τ_arg ...) #'(τ ...))
                   (string-append
                    (format
                     "Wrong number of args given to function ~a:\ngiven: "
                     (syntax->datum #'e_fn))
                    (string-join
                     (map
                      (λ (e t) (format "~a : ~a" e t))
                      (syntax->datum #'(e_arg ...))
                      (syntax->datum #`#,(stx-map get-orig #'(τ_arg ...))))
                     ", ")
                    (format "\nexpected: ~a argument(s)." (stx-length #'(τ ...))))
     #:fail-unless (typechecks? #'(τ_arg ...) #'(τ ...))
                   (string-append
                    (format
                     "Arguments to function ~a have wrong type:\ngiven: "
                     (syntax->datum #'e_fn))
                    (string-join
                     (map
                      (λ (e t) (format "~a : ~a" e t))
                      (syntax->datum #'(e_arg ...))
                      (syntax->datum #`#,(stx-map get-orig #'(τ_arg ...))))
                     ", ")
                    "\nexpected arguments with type: "
                    (string-join
                     (map ~a (syntax->datum #`#,(stx-map get-orig #'(τ ...))))
                     ", "))
     (⊢ #'(#%app e_fn- e_arg- ...) #'τ_res)]))
