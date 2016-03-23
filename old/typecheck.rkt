#lang racket/base
(require (for-syntax racket/base syntax/parse syntax/stx racket/syntax
                     racket/set racket/list racket/function
                     "stx-utils.rkt")
         (for-meta 2 racket/base syntax/parse))
(provide (all-defined-out)
         (for-syntax (all-defined-out)))

(begin-for-syntax
  ;; usage:
  ;; type-error #:src src-stx
  ;;            #:msg msg-string msg-args ...
  ;; msg-args should be syntax
  (define-syntax-rule (type-error #:src stx-src #:msg msg args ...)
    (raise-user-error
     'TYPE-ERROR
     (format (string-append "~a (~a:~a): " msg) 
             (syntax-source stx-src) (syntax-line stx-src) (syntax-column stx-src) 
             (syntax->datum args) ...))))

;; for types, just need the identifier bound
(define-syntax-rule (define-and-provide-builtin-type τ) 
  (begin (define τ #f) (provide τ)))
(define-syntax-rule (define-and-provide-builtin-types τ ...) 
  (begin (define-and-provide-builtin-type τ) ...))

(define-syntax (define-primop stx)
  (syntax-parse stx #:datum-literals (:)
    [(_ op:id : ((~and τ_arg (~not (~literal ...))) ... (~optional (~and ldots (~literal ...)))
                 (~and arr (~datum →)) 
                 τ_result))
;     #:with lit-→ (datum->syntax stx '→)
     #:with (~datum →) #'arr
     #:with op/tc (format-id #'op "~a/tc" #'op)
     #`(begin
         (provide (rename-out [op/tc op]))
         (define-syntax (op/tc stx)
           (syntax-parse stx
             [f:id ; HO case
              (⊢ (syntax/loc stx op) 
                 #,(if (attribute ldots)
                       #'#'(τ_arg ... (... (... ...)) arr τ_result)
                       #'#'(τ_arg ... arr τ_result)))]
                 ;; TODO: for now, just drop the ...
;                 #'(τ_arg ... arr τ_result))]
             [(_ e (... ...))
              #:with es+ (stx-map expand/df #'(e (... ...))) 
              #:with τs #'(τ_arg ...)
              #:fail-unless (let ([es-len (stx-length #'es+)]
                                  [τs-len (stx-length #'τs)])
                              (or (and #,(if (attribute ldots) #t #f)
                                       (>= (- es-len (sub1 τs-len)) 0))
                                  (= es-len τs-len)))
                            #,(if (attribute ldots)
                                  #'(format "Wrong number of arguments, given ~a, expected at least ~a"
                                            (stx-length #'es+) (sub1 (stx-length #'τs)))
                                  #'(format "Wrong number of arguments, given ~a, expected ~a" 
                                            (stx-length #'es+) (stx-length #'τs)))
              #:with τs-ext #,(if (attribute ldots)
                                #'(let* ([diff (- (stx-length #'es+) (sub1 (stx-length #'τs)))]
                                         [last-τ (stx-last #'τs)]
                                         [last-τs (build-list diff (λ _ last-τ))])
                                    (append (drop-right (syntax->list #'τs) 1) last-τs))
                                #'#'τs)
              #:when (stx-andmap assert-type #'es+ #'τs-ext)
              (⊢ (syntax/loc stx (op . es+)) #'τ_result)])))]))

;; general type-checking functions

(define-for-syntax (type=? τ1 τ2)
;  (printf "type= ~a ~a\n" (syntax->datum τ1) (syntax->datum τ2))
  (syntax-parse #`(#,τ1 #,τ2) #:datum-literals (∀ →)
    [(x:id y:id) (free-identifier=? τ1 τ2)]
    [(∀τ1 ∀τ2)
     #:with (∀ τvars1 τ_body1) #'∀τ1 
     #:fail-unless (stx-pair? #'τvars1) "Must provide a list of type variables."
     #:fail-when (check-duplicate-identifier (syntax->list #'τvars1)) "Given duplicate identifiers"
     #:with (∀ τvars2 τ_body2) #'∀τ2
     #:fail-unless (stx-pair? #'τvars2) "Must provide a list of type variables."
     #:fail-when (check-duplicate-identifier (syntax->list #'τvars2)) "Given duplicate identifiers"
     #:with fresh-τvars (generate-temporaries #'τvars1)
     ;; to handle α-equiv, for apply-forall with same vars
     (and (= (length (syntax->list #'τvars1))
             (length (syntax->list #'τvars2)))
          (type=? (apply-forall #'∀τ1 #'fresh-τvars) (apply-forall #'∀τ2 #'fresh-τvars)))]
    ;; ldots on lhs
    [(((~and τ_arg1 (~not (~literal ...))) ... τ_repeat (~and ldots (~literal ...)) → τ_result1) 
      ((~and τ_arg2 (~not (~literal ...))) ... → τ_result2))
     (let ([num-arg1 (stx-length #'(τ_arg1 ...))]
           [num-arg2 (stx-length #'(τ_arg2 ...))])
       (define diff (- num-arg2 num-arg1))
       (define extra-τs (build-list diff (λ _ #'τ_repeat)))
       (with-syntax ([(τ_arg1/ext ...) (append (syntax->list #'(τ_arg1 ...)) extra-τs)])
         (and (= (length (syntax->list #'(τ_arg1/ext ...))) (length (syntax->list #'(τ_arg2 ...))))
          (stx-andmap type=? #'(τ_arg1/ext ...) #'(τ_arg2 ...))
          (type=? #'τ_result1 #'τ_result2))))]
    ;; ldots on rhs
    [(((~and τ_arg2 (~not (~literal ...))) ... → τ_result2) 
      ((~and τ_arg1 (~not (~literal ...))) ... τ_repeat (~and ldots (~literal ...)) → τ_result1))
     (let ([num-arg1 (stx-length #'(τ_arg1 ...))]
           [num-arg2 (stx-length #'(τ_arg2 ...))])
       (define diff (- num-arg2 num-arg1))
       (define extra-τs (build-list diff (λ _ #'τ_repeat)))
       (with-syntax ([(τ_arg1/ext ...) (append (syntax->list #'(τ_arg1 ...)) extra-τs)])
         (and (= (length (syntax->list #'(τ_arg1/ext ...))) (length (syntax->list #'(τ_arg2 ...))))
          (stx-andmap type=? #'(τ_arg1/ext ...) #'(τ_arg2 ...))
          (type=? #'τ_result1 #'τ_result2))))]
    ;; ldots on both lhs and rhs
    [(((~and τ_arg1 (~not (~literal ...))) ... τ_repeat1 (~and ldots1 (~literal ...)) → τ_result1) 
      ((~and τ_arg2 (~not (~literal ...))) ... τ_repeat2 (~and ldots2 (~literal ...)) → τ_result2))
     (let ([num-arg1 (stx-length #'(τ_arg1 ...))]
           [num-arg2 (stx-length #'(τ_arg2 ...))])
       (cond [(> num-arg2 num-arg1)
              (define diff (- num-arg2 num-arg1))
              (define extra-τs (build-list diff (λ _ #'τ_repeat1)))
              (with-syntax ([(τ_arg1/ext ...) (append (syntax->list #'(τ_arg1 ...)) extra-τs)])
                (and (= (length (syntax->list #'(τ_arg1/ext ...))) (length (syntax->list #'(τ_arg2 ...))))
                     (stx-andmap type=? #'(τ_arg1/ext ...) #'(τ_arg2 ...))
                     (type=? #'τ_result1 #'τ_result2)))]
             [else
              (define diff (- num-arg1 num-arg2))
              (define extra-τs (build-list diff (λ _ #'τ_repeat2)))
              (with-syntax ([(τ_arg2/ext ...) (append (syntax->list #'(τ_arg2 ...)) extra-τs)])
                (and (= (length (syntax->list #'(τ_arg2/ext ...))) (length (syntax->list #'(τ_arg1 ...))))
                     (stx-andmap type=? #'(τ_arg2/ext ...) #'(τ_arg1 ...))
                     (type=? #'τ_result1 #'τ_result2)))]))]
    [((τ_arg1 ... → τ_result1) (τ_arg2 ... → τ_result2))
     (and (= (length (syntax->list #'(τ_arg1 ...))) (length (syntax->list #'(τ_arg2 ...))))
          (stx-andmap type=? #'(τ_arg1 ...) #'(τ_arg2 ...))
          (type=? #'τ_result1 #'τ_result2))]
    [((tycon1:id τ1 ...) (tycon2:id τ2 ...)) 
     (and (free-identifier=? #'tycon1 #'tycon2)
          (= (length (syntax->list #'(τ1 ...))) (length (syntax->list #'(τ2 ...))))
          (stx-andmap type=? #'(τ1 ...) #'(τ2 ...)))]
    [_ #f]))

;; return #t if (typeof e)=τ, else type error
(define-for-syntax (assert-type e τ)
;  (printf "~a has type " (syntax->datum e))
;  (printf "~a; expected: " (syntax->datum (typeof e)))
;  (printf "~a\n"  (syntax->datum τ))
  (or (type=? (typeof e) τ)
      (type-error #:src e 
                  #:msg "~a has type ~a, but should have type ~a" e (typeof e) τ)))

;; attaches type τ to e (as syntax property)
(define-for-syntax (⊢ e τ) (syntax-property e 'type τ))

;; retrieves type of τ (from syntax property)
(define-for-syntax (typeof stx) (syntax-property stx 'type))
(define-for-syntax has-type? typeof)

;; type environment -----------------------------------------------------------
(begin-for-syntax
  (define base-type-env (hash))
  ;; Γ : [Hashof var-symbol => type-stx]
  ;; - can't use free-identifier=? for the hash table (or free-id-table)
  ;;   because env must be set before expanding λ body (ie before going under λ)
  ;;   so x's in the body won't be free-id=? to the one in the table
  ;; use symbols instead of identifiers for now --- should be fine because
  ;; I'm manually managing the environment, and surface language has no macros
  ;; so I know all the binding forms
  (define Γ (make-parameter base-type-env))
  
  (define (type-env-lookup x) 
    (hash-ref (Γ) (syntax->datum x)
              (λ () 
                (type-error #:src x
                            #:msg "Could not find type for variable ~a" x))))

  ;; returns a new hash table extended with type associations x:τs
  (define (type-env-extend x:τs)
    (define xs (stx-map stx-car x:τs))
    (define τs (stx-map stx-cadr x:τs))
    (apply hash-set* (Γ) (append-map (λ (x τ) (list (syntax->datum x) τ)) xs τs)))

  ;; must be macro because type env must be extended first, before expandinb body
  (define-syntax (with-extended-type-env stx)
    (syntax-parse stx
      [(_ x-τs e)
       #'(parameterize ([Γ (type-env-extend x-τs)]) e)])))

;; apply-forall ---------------------------------------------------------------
(define-for-syntax (subst x τ mainτ)
  (syntax-parse mainτ #:datum-literals (∀ →)
    [y:id
     #:when (free-identifier=? #'y x)
     τ]
    [y:id #'y]
    [∀τ
     #:with (∀ tyvars τbody) #'∀τ
     #:when (stx-member x #'tyvars)
     #'∀τ]
    [∀τ
     #:with (∀ tyvars τbody) #'∀τ
     #:when (not (stx-member x #'tyvars))
     #`(∀ tyvars #,(subst x τ #'τbody))]
    ;; need the ~and because for the result, I need to use the → literal 
    ;; from the context of the input, and not the context here
    [(τ_arg ... (~and (~datum →) arrow) τ_result)
     #:with (τ_arg/subst ... τ_result/subst) 
            (stx-map (curry subst x τ) #'(τ_arg ... τ_result))
      #'(τ_arg/subst ... arrow τ_result/subst)]
    [(tycon:id τarg ...)
     #:with (τarg/subst ...) (stx-map (curry subst x τ) #'(τarg ...))
     #'(tycon τarg/subst ...)]))
(define-for-syntax (apply-forall ∀τ τs)
  (syntax-parse ∀τ #:datum-literals (∀)
    [(∀ (X ...) body)
     (foldl subst #'body (syntax->list #'(X ...)) (syntax->list τs))]))
#;(define-for-syntax (apply-forall ∀τ τs)
;  (printf "applying ∀:~a to ~a\n" (syntax->datum ∀τ) (syntax->datum τs))
  (define ctx (syntax-local-make-definition-context))
  (define id (generate-temporary))
  (syntax-local-bind-syntaxes
   (list id)
   (syntax-parse ∀τ #:datum-literals (∀/internal)
     [(∀/internal (X ...) τbody)
      #'(λ (stx)
          (syntax-parse stx
            [(_ (τ (... ...)))
             #:with (X ...) #'(τ (... ...))
             #'τbody]))])
   ctx)
  (local-expand #`(#,id #,τs) 'expression (list #'#%app) ctx))

;; expand/df ------------------------------------------------------------------
;; depth-first expand
(define-for-syntax (expand/df e [ctx #f])
;  (printf "expanding: ~a\n" (syntax->datum e))
;  (printf "typeenv: ~a\n" (Γ))
  (cond
    ;; 1st case handles struct constructors that are not the same name as struct
    ;; (should always be an identifier)
    [(syntax-property e 'constructor-for) => (λ (Cons) 
     (⊢ e (type-env-lookup Cons)))]
    ;; 2nd case handles identifiers that are not struct constructors
    [(identifier? e) 
     ; handle this here bc there's no #%var form
     ; but some ids, like primops, may already have type
     (define e+ (local-expand e 'expression null ctx))
     (if (has-type? e+) e+ (⊢ e (type-env-lookup e)))] 
    ;; local-expand must expand all the way down, ie have no stop-list, ie stop list can't be #f
    ;; ow forms like lambda and app won't get properly assigned types
    [else (local-expand e 'expression null ctx)]))
(define-for-syntax (expand/df/module-ctx def)
  (local-expand def 'module #f))
(define-for-syntax (expand/df/mb-ctx def)
  (local-expand def 'module-begin #f))

