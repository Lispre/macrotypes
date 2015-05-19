#lang racket/base
(require
  (for-syntax racket/base syntax/parse racket/list syntax/stx "stx-utils.rkt")
  (for-meta 2 racket/base syntax/parse racket/list syntax/stx "stx-utils.rkt"))
(provide 
 (for-syntax (all-defined-out))
 (all-defined-out))

;; type checking functions/forms

;; General type checking strategy:
;; - Each (expanded) syntax object has a 'type syntax property that is the type
;;   of the surface form.
;; - To typecheck a surface form, it local-expands each subterm in order to get
;;   their types.
;; - With this typechecking strategy, the typechecking implementation machinery
;;   is easily inserted into each #%- form
;; - A base type is just a Racket identifier, so type equality, even with
;;   aliasing, is just free-identifier=?

;; A Type is a Syntax Object

(define-syntax (define-base-type stx)
  (syntax-parse stx
    [(_ τ:id)
     #'(define-syntax (τ stx)
         (syntax-parse stx
           [_ (error 'Int "Cannot use type at run time.")]))]))
(define-syntax (define-type-constructor stx)
  (syntax-parse stx
    [(_ τ:id)
     #'(define-syntax (τ stx)
         (syntax-parse stx
           [_ (error 'Int "Cannot use type at run time.")]))]))

(begin-for-syntax
  ;; ⊢ : Syntax Type -> Syntax
  ;; Attaches type τ to (expanded) expression e.
;  (define (⊢ e τ) (syntax-property (quasisyntax/loc e #,e) 'type τ))
  (define (⊢ e τ) (syntax-property e 'type τ))

  (define (infer/type-ctxt x+τs e)
    (typeof
     (syntax-parse x+τs
       [([x τ] ...)
        #:with
        (lam xs+ (lr-stxs+vs1 stxs1 vs1 (lr-stxs+vs2 stxs2 vs2 e+)))
        (expand/df
         #`(λ (x ...)
             (let-syntax ([x (make-rename-transformer (⊢ #'x #'τ))] ...) #,e)))
        #'e+])))

  
  (define (infer e) (typeof (expand/df e)))
  (define (infers es) (stx-map infer es))
  (define (types=? τs1 τs2)
    (stx-andmap type=? τs1 τs2))
  
  ;; typeof : Syntax -> Type or #f
  ;; Retrieves type of given stx, or #f if input has not been assigned a type.
  (define (typeof stx) (syntax-property stx 'type))
  ;; When checking for just the presence of a type, 
  ;; the name has-type? makes more sense (see expand/df for an example).
  (define has-type? typeof)

  ;; assert-type : Syntax Type -> Boolean
  ;; Returns #t if (typeof e)==τ, else type error
  (define (assert-type e τ)
    ;  (printf "~a has type " (syntax->datum e))
    ;  (printf "~a; expected: " (syntax->datum (typeof e)))
    ;  (printf "~a\n"  (syntax->datum τ))
    (or (type=? (typeof e) τ)
        (type-error #:src e 
                    #:msg "~a has type ~a, but should have type ~a" e (typeof e) τ)))

  ;; type=? : Type Type -> Boolean
  ;; Indicates whether two types are equal
  (define (type=? τ1 τ2)
    (syntax-parse #`(#,τ1 #,τ2)
      ; → should not be datum literal;
      ; adding a type constructor should extend type equality
      #:datum-literals (→)
      [(x:id y:id) (free-identifier=? τ1 τ2)]
      [((x ... → x_out) (y ... → y_out))
       (and (type=? #'x_out #'y_out)
            (stx-andmap type=? #'(x ...) #'(y ...)))]
      [_ #f]))
            

  ;; expand/df : Syntax -> Syntax
  ;; Local expands the given syntax object. 
  ;; The result always has a type (ie, a 'type stx-prop).
  ;; Note: 
  ;; local-expand must expand all the way down, ie stop-ids == null
  ;; If stop-ids is #f, then subexpressions won't get expanded and thus won't
  ;; get assigned a type.
  (define (expand/df e)
;  (printf "expanding: ~a\n" (syntax->datum e))
;  (printf "typeenv: ~a\n" (Γ))
    (cond
      ;; Handle identifiers separately.
      ;; User-defined ids don't have a 'type stx-prop yet because Racket has no
      ;; #%var form.
      ;; Built-in ids, like primops, will already have a type though, so check.
      [(identifier? e) 
       (define e+ (local-expand e 'expression null)) ; null == full expansion
       (if (has-type? e+) e+ (⊢ e (type-env-lookup e)))]
      [else (local-expand e 'expression null)]))

  ;; type-error #:src Syntax #:msg String Syntax ...
  ;; usage:
  ;; type-error #:src src-stx
  ;;            #:msg msg-string msg-args ...
  (define-syntax-rule (type-error #:src stx-src #:msg msg args ...)
    (raise-user-error
     'TYPE-ERROR
     (format (string-append "~a (~a:~a): " msg) 
             (syntax-source stx-src) (syntax-line stx-src) (syntax-column stx-src) 
             (syntax->datum args) ...))))

;; type environment -----------------------------------------------------------
(begin-for-syntax
  
  ;; A Variable is a Symbol
  ;; A TypeEnv is a [HashOf Variable => Type]
  
  ;; base-type-env : TypeEnv
  ;; Γ : [ParameterOf TypeEnv]
  ;; The keys represent variables and the values are their types.
  ;; NOTE: I can't use a free-id-table because a variable must be in the table
  ;; before expanding (ie type checking) a λ body, so the vars in the body won't
  ;; be free-id=? to the ones in the table.
  ;; Using symbols instead of ids should be fine because I'm manually managing
  ;; the entire environment, and the surface language has no macros so I know
  ;; all the binding forms ahead of time. 
  (define base-type-env (hash))
  (define Γ (make-parameter base-type-env))
  
  ;; type-env-lookup : Syntax -> Type
  ;; Returns the type of the input identifier, according to Γ.
  (define (type-env-lookup x) 
    (hash-ref (Γ) (syntax->datum x)
      (λ () (type-error #:src x
                        #:msg "Could not find type for variable ~a" x))))

  ;; type-env-extend : #'((x τ) ...) -> TypeEnv
  ;; Returns a TypeEnv extended with type associations x:τs/
  (define (type-env-extend x:τs)
    (define xs (stx-map stx-car x:τs))
    (define τs (stx-map stx-cadr x:τs))
    (apply hash-set* (Γ) (append-map (λ (x τ) (list (syntax->datum x) τ)) xs τs)))

  ;; with-extended-type-env : #'((x τ) ...) Syntax -> 
  ;; Must be macro because type env must be extended before expanding the body e.
  (define-syntax (with-extended-type-env stx)
    (syntax-parse stx
      [(_ x-τs e)
       #'(parameterize ([Γ (type-env-extend x-τs)]) e)])))

;; type classes
(begin-for-syntax
  (define-syntax-class typed-binding #:datum-literals (:)
    (pattern [x:id : τ])
    (pattern
     any
     #:with x #f
     #:with τ #f
     #:fail-when #t
     (format "Improperly formatted type annotation: ~a; should have shape [x : τ]"
             (syntax->datum #'any)))))
