#lang turnstile
(extends "ext-stlc.rkt" #:except #%app λ)
(reuse inst #:from "sysf.rkt")
(require (only-in "sysf.rkt" ∀ ~∀ ∀? Λ))
(reuse cons [head hd] [tail tl] nil [isnil nil?] List list #:from "stlc+cons.rkt")
(require (only-in "stlc+cons.rkt" ~List))
(reuse tup × proj #:from "stlc+tup.rkt")
(reuse define-type-alias #:from "stlc+reco+var.rkt")
(require (for-syntax macrotypes/type-constraints))
(provide hd tl nil? ∀)

;; (Some [X ...] τ_body (Constraints (Constraint τ_1 τ_2) ...))
(define-type-constructor Some #:arity = 2 #:bvs >= 0)
(define-type-constructor Constraint #:arity = 2)
(define-type-constructor Constraints #:arity >= 0)
(define-syntax Cs
  (syntax-parser
    [(_ [a b] ...)
     (Cs #'([a b] ...))]))
(begin-for-syntax
  (define (?∀ Xs τ)
    (if (stx-null? Xs)
        τ
        #`(∀ #,Xs #,τ)))
  (define (?Some Xs τ cs)
    (if (and (stx-null? Xs) (stx-null? cs))
        τ
        #`(Some #,Xs #,τ (Cs #,@cs))))
  (define (Cs cs)
    (syntax-parse cs
      [([a b] ...)
       #'(Constraints (Constraint a b) ...)]))
  (define-syntax ~?∀
    (pattern-expander
     (syntax-parser
       [(?∀ Xs-pat τ-pat)
        #:with τ (generate-temporary)
        #'(~and τ
                (~parse (~∀ Xs-pat τ-pat)
                        (if (∀? #'τ)
                            #'τ
                            ((current-type-eval) #'(∀ () τ)))))])))
  (define-syntax ~?Some
    (pattern-expander
     (syntax-parser
       [(?Some Xs-pat τ-pat Cs-pat)
        #:with τ (generate-temporary)
        #'(~and τ
                (~parse (~Some Xs-pat τ-pat Cs-pat)
                        (if (Some? #'τ)
                            #'τ
                            ((current-type-eval) #'(Some [] τ (Cs))))))])))
  (define-syntax ~Cs
    (pattern-expander
     (syntax-parser #:literals (...)
       [(_ [a b] ooo:...)
        #:with cs (generate-temporary)
        #'(~and cs
                (~parse (~Constraints (~Constraint a b) ooo)
                        (if (syntax-e #'cs)
                            #'cs
                            ((current-type-eval) #'(Cs)))))]))))

(begin-for-syntax
  ;; find-free-Xs : (Stx-Listof Id) Type -> (Listof Id)
  ;; finds the free Xs in the type
  (define (find-free-Xs Xs ty)
    (for/list ([X (in-list (stx->list Xs))]
               #:when (stx-contains-id? ty X))
      X))

  ;; constrainable-X? : Id Solved-Constraints (Stx-Listof Id) -> Boolean
  (define (constrainable-X? X cs Vs)
    (for/or ([c (in-list (stx->list cs))])
      (or (bound-identifier=? X (stx-car c))
          (and (member (stx-car c) Vs bound-identifier=?)
               (stx-contains-id? (stx-cadr c) X)
               ))))

  ;; find-constrainable-vars : (Stx-Listof Id) Solved-Constraints (Stx-Listof Id) -> (Listof Id)
  (define (find-constrainable-vars Xs cs Vs)
    (for/list ([X (in-list Xs)] #:when (constrainable-X? X cs Vs))
      X))

  ;; set-minus/Xs : (Listof Id) (Listof Id) -> (Listof Id)
  (define (set-minus/Xs Xs Ys)
    (for/list ([X (in-list Xs)]
               #:when (not (member X Ys bound-identifier=?)))
      X))
  ;; set-intersect/Xs : (Listof Id) (Listof Id) -> (Listof Id)
  (define (set-intersect/Xs Xs Ys)
    (for/list ([X (in-list Xs)]
               #:when (member X Ys bound-identifier=?))
      X))

  ;; some/inst/generalize : (Stx-Listof Id) Type-Stx Constraints -> Type-Stx
  (define (some/inst/generalize Xs* ty* cs1)
    (define Xs (stx->list Xs*))
    (define cs2 (add-constraints/var? Xs identifier? '() cs1))
    (define Vs (set-minus/Xs (stx-map stx-car cs2) Xs))
    (define constrainable-vars
      (find-constrainable-vars Xs cs2 Vs))
    (define constrainable-Xs
      (set-intersect/Xs Xs constrainable-vars))
    (define concrete-constrained-vars
      (for/list ([X (in-list constrainable-vars)]
                 #:when (empty? (find-free-Xs Xs (or (lookup X cs2) X))))
        X))
    (define unconstrainable-Xs
      (set-minus/Xs Xs constrainable-Xs))
    (define ty (inst-type/cs/orig constrainable-vars cs2 ty*))
    ;; pruning constraints that are useless now
    (define concrete-constrainable-Xs
      (for/list ([X (in-list constrainable-Xs)]
                 #:when (empty? (find-free-Xs constrainable-Xs (or (lookup X cs2) X))))
        X))
    (define cs3
      (for/list ([c (in-list cs2)]
                 #:when (not (member (stx-car c) concrete-constrainable-Xs bound-identifier=?)))
        c))
    (?Some
     (set-minus/Xs constrainable-Xs concrete-constrainable-Xs)
     (?∀ (find-free-Xs unconstrainable-Xs ty) ty)
     cs3))

  (define (tycons id args)
    (define/syntax-parse [X ...]
      (for/list ([arg (in-list (stx->list args))])
        (add-orig (generate-temporary arg) (get-orig arg))))
    (define/syntax-parse [arg ...] args)
    (define/syntax-parse (~∀ (X- ...) body)
      ((current-type-eval) #`(∀ (X ...) (#,id X ...))))
    (inst-type/cs #'[X- ...] #'([X- arg] ...) #'body))

  (define old-join (current-join))

  (define (new-join a b)
    (syntax-parse (list a b)
      [[(~?Some [X ...] A (~Cs [τ_1 τ_2] ...))
        (~?Some [Y ...] B (~Cs [τ_3 τ_4] ...))]
       (define AB (old-join #'A #'B))
       (?Some #'[X ... Y ...] AB #'([τ_1 τ_2] ... [τ_3 τ_4] ...))]))
  (current-join new-join)
  )

(define-typed-syntax λ
  [(λ (x:id ...) body:expr) ≫
   [#:with [X ...]
    (for/list ([X (in-list (generate-temporaries #'[x ...]))])
      (add-orig X X))]
   [([X : #%type ≫ X-] ...) ([x : X ≫ x-] ...)
    ⊢ [[body ≫ body-] ⇒ : τ_body*]]
   [#:with (~?Some [V ...] τ_body (~Cs [id_2 τ_2] ...)) (syntax-local-introduce #'τ_body*)]
   [#:with τ_fn (some/inst/generalize #'[X- ... V ...]
                                      #'(→ X- ... τ_body)
                                      #'([id_2 τ_2] ...))]
   --------
   [⊢ [[_ ≫ (λ- (x- ...) body-)] ⇒ : τ_fn]]])

(define-typed-syntax #%app
  [(_ e_fn e_arg ...) ≫
   [#:with [A ...] (generate-temporaries #'[e_arg ...])]
   [#:with B (generate-temporary 'result)]
   [⊢ [[e_fn ≫ e_fn-] ⇒ : τ_fn*]]
   [#:with (~?Some [V1 ...] τ_fn (~Cs [τ_3 τ_4] ...))
    (syntax-local-introduce #'τ_fn*)]
   [#:with τ_fn-expected (tycons #'→ #'[A ... B])]
   [⊢ [[e_arg ≫ e_arg-] ⇒ : τ_arg*] ...]
   [#:with [(~?Some [V3 ...] τ_arg (~Cs [τ_5 τ_6] ...)) ...]
    (syntax-local-introduce #'[τ_arg* ...])]
   [#:with τ_out (some/inst/generalize #'[A ... B V1 ... V3 ... ...]
                                       #'B
                                       #'([τ_fn-expected τ_fn]
                                          [τ_3 τ_4] ...
                                          [A τ_arg] ...
                                          [τ_5 τ_6] ... ...))]
   --------
   [⊢ [[_ ≫ (#%app- e_fn- e_arg- ...)] ⇒ : τ_out]]])

(define-typed-syntax define
  [(define x:id e:expr) ≫
   [⊢ [[e ≫ e-] ⇒ : τ_e]]
   [#:with tmp (generate-temporary #'x)]
   --------
   [_ ≻ (begin-
          (define-syntax- x (make-rename-transformer (⊢ tmp : τ_e)))
          (define- tmp e-))]])



