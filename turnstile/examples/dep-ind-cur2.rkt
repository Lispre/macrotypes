#lang turnstile/lang
(require turnstile/eval)

; a basic dependently-typed calculus
; - with inductive datatypes

;; dep-ind-cur2 is dep-ind-cur cleaned up and using better abstractions

; dep-ind-cur initially copied from dep-ind-fixed.rkt
; - extended with cur-style currying as the default

; dep-ind-fixed is mostly same as dep-ind.rkt but define-datatype has some fixes

; Π  λ ≻ ⊢ ≫ → ∧ (bidir ⇒ ⇐) τ⊑ ⇑

(provide Type (rename-out [Type *])
         (rename-out [Π/c Π] [→/c →] [∀/c ∀] [λ/c λ] [app/c #%app])
         = eq-refl eq-elim
         ann define-datatype define define-type-alias)

;; type definitions -----------------------------------------------------------

;; set (Type n) : (Type n+1)
;; Type = (Type 0)
(struct Type- (n) #:transparent) ; runtime representation
(begin-for-syntax
  (define Type-id (expand/df #'Type-))
  (define-syntax ~Type
    (pattern-expander
     (syntax-parser
       [:id #'(~Type _)]
       [(_ n)
        #'(~or
           ((~literal Type) n)   ; unexpanded
           ((~literal #%plain-app) ; expanded
            (~and C:id (~fail #:unless (free-identifier=? #'C Type-id)
                              (format "type mismatch, expected Type, given ~a"
                                      (syntax->datum #'C))))
            ((~literal quote) n)))]
       ))))

(define-typed-syntax Type
  [:id ≫ --- [≻ (Type 0)]]
  [(_ n:exact-nonnegative-integer) ≫
   #:with n+1 (+ (syntax-e #'n) 1)
  -------------
  [≻ #,(syntax-property
        (syntax-property 
         #'(Type- 'n) ':
         (syntax-property
          #'(Type n+1)
          'orig
          (list #'(Type n+1))))
        'orig
        (list #'(Type n)))]])

;; for convenience, Type that is a supertype of all (Type n)
;; TODO: get rid of this?
(define-syntax TypeTop (make-variable-like-transformer #'(Type 99)))

(define-binding-type Π #:bind ([X : TypeTop]) : [dummy : TypeTop] -> Type)

;; curried version of Π
(define-syntax (Π/c stx)
  (syntax-parse stx
    [(_ t) #'t]
    [(_ (~and xty [x:id (~datum :) τ]) . rst)
     (syntax/loc stx (Π (xty) (Π/c . rst)))]))

;; curried Π pattern expander
(begin-for-syntax
  (define-syntax ~Π/c
    (pattern-expander
     (syntax-parser
       [(_ t) #'t]
       [(_ [x (~datum :) ty] (~and (~literal ...) ooo) t_out)
        #'(~and TMP
                (~parse ([x ty] ooo t_out)
                        (let L ([ty #'TMP][xtys empty])
                          (syntax-parse ty
                            [(~Π ([x : τ_in]) rst)
                             (L #'rst (cons #'[x τ_in] xtys))]
                            [t_out
                             (reverse (cons #'t_out xtys))]))))]
       [(_ (~and xty [x:id : τ_in]) . rst)
        #'(~Π (xty) (~Π/c . rst))]))))

;; abbrevs for Π
;; (→ τ_in τ_out) == (Π (unused : τ_in) τ_out)
(define-simple-macro (→ τ_in τ_out)
  #:with X (generate-temporary #'τ_in)
  (Π ([X : τ_in]) τ_out))
;; (∀ (X) τ) == (∀ ([X : Type]) τ)
(define-simple-macro (∀ (X)  τ)
  (Π ([X : Type]) τ))

;; abbrevs for Π/c
;; (→ τ_in τ_out) == (Π (unused : τ_in) τ_out)
(define-simple-macro (→/c τ_in ... τ_out)
  #:with (X ...) (generate-temporaries #'(τ_in ...))
  (Π/c [X : τ_in] ... τ_out))
;; (∀ (X) τ) == (∀ ([X : Type]) τ)
(define-simple-macro (∀/c X ...  τ)
  (Π/c [X : Type] ... τ))

;; type check relation --------------------------------------------------------
;; - must come after type defs

(begin-for-syntax

  (define old-relation (current-typecheck-relation))
  (current-typecheck-relation
   (lambda (t1 t2)
     ;; (printf "t1 = ~a\n" (syntax->datum t1))
     ;; (printf "t2 = ~a\n" (syntax->datum t2))
     (define t1+
       (syntax-parse t1
         [((~literal Type) _) ((current-type-eval) t1)]
         [_ t1]))
     (or (type=? t1+ t2) ; equality
         (syntax-parse (list t1+ t2)
           [((~Type n) (~Type m)) (<= (stx-e #'n) (stx-e #'m))]
           [((~Π ([x1 : τ_in1]) τ_out1) (~Π ([x2 : τ_in2]) τ_out2))
            (and (type=? #'τ_in1 #'τ_in2)
                 (typecheck? (subst #'x2 #'x1 #'τ_out1) #'τ_out2))]
           [_ #f])))))

;; lambda and #%app -----------------------------------------------------------
(define-typed-syntax λ
  ;; expected ty only
  [(_ (y:id) e) ⇐ (~Π ([x:id : τ_in]) τ_out) ≫
   [[x ≫ x- : τ_in] ⊢ #,(subst #'x #'y #'e) ≫ e- ⇐ τ_out]
   ---------
   [⊢ (λ- (x-) e-)]]
  ;; both expected ty and annotations
  [(_ ([y:id (~datum :) τ_in*]) e) ⇐ (~Π ([x:id : τ_in]) τ_out) ≫
   [⊢ τ_in* ≫ τ_in** ⇐ Type]
   #:when (typecheck? #'τ_in** #'τ_in)
   [[x ≫ x- : τ_in] ⊢ #,(subst #'x #'y #'e) ≫ e- ⇐ τ_out]
   -------
   [⊢ (λ- (x-) e-)]]
  ;; annotations only
  [(_ ([x:id (~datum :) τ_in]) e) ≫
   [[x ≫ x- : τ_in] ⊢ [e ≫ e- ⇒ τ_out] [τ_in ≫ τ_in- ⇒ _]]
   -------
   [⊢ (λ- (x-) e-) ⇒ (Π ([x- : τ_in-]) τ_out)]])

(define-typerule/red (app e_fn e_arg) ≫
;  #:do[(printf "apping: ~a ------------\n" (syntax->datum #'(app e_fn e_arg)))]
  [⊢ e_fn ≫ e_fn- ⇒ (~Π ([X : τ_in]) τ_out)]
  [⊢ e_arg ≫ e_arg- ⇐ τ_in]
  #:with τ-out (reflect (subst #'e_arg- #'X #'τ_out))
  -----------------------------
  [⊢ (app/eval e_fn- e_arg-) ⇒ τ-out]
  #:where app/eval
  [(((~literal #%plain-lambda) (x) e) arg) ~> #,(subst #'arg #'x #'e)]
  [(((~literal #%expression) ((~literal #%plain-lambda) (x) e)) arg) ~> #,(subst #'arg #'x #'e)])

(define-typed-syntax (ann e (~datum :) τ) ≫
  [⊢ e ≫ e- ⇐ τ]
  --------
  [⊢ e- ⇒ τ])

;; ----------------------------------------------------------------------------
;; auto-currying λ and #%app and Π
;; - requires annotations for now
;; TODO: add other cases?
(define-syntax (λ/c stx)
  (syntax-parse stx
    [(_ e) #'e]
    [(_ x . rst) #'(λ (x) (λ/c . rst))]))

(define-syntax (app/c stx)
  (syntax-parse stx
    [(_ e) #'e]
    [(_ f e . rst) #'(app/c (app f e) . rst)]))

(define-syntax (app/eval/c stx)
  (syntax-parse stx
    [(_ e) #'e]
    [(_ f e . rst) #`(app/eval/c (app/eval f e) . rst)]))

;; TODO: move this to turnstile/eval?
;; TODO: define in terms of define-binding-type?
;; - currying is the problem: what is a partial application of a type defined with
;;   define-binding-type
;;   - requires knowlege of a function type
(define-syntax define-constructor
  (syntax-parser
    [(_ name (~datum :) ty)
     #:with (~Π/c [A+i : τ] ... τ-out) ((current-type-eval) #'ty)
     #:with name/internal (generate-temporary #'name)
     #:with name/internal-expander (mk-~ #'name/internal)
     #:with name-expander (mk-~ #'name)
     #:with OUT
     #'(begin-
         (define-binding-type name/internal #:bind () : [A+i : τ] ... -> τ-out)
         (define-syntax name
           (make-variable-like-transformer
            #'(λ/c [A+i : τ] ... (name/internal () A+i ...))))
         (begin-for-syntax
           (define-syntax name-expander
             (pattern-expander
              (syntax-parser
                [:id #'(name-expander A+i ...)] ; 0-arity case; need non-id case as well?
                [(_ A+i ...)
                 #'(name/internal-expander () A+i ...)
                 #;#'(~and
                    TMP
                    (~parse ((~literal #%plain-app) name-:id A+i ...) #'TMP)
                    (~fail #:unless (free-id=? #'name- name/internal+))
                    )])))
           ))
     #;#'(begin-
         (struct name/internal (A+i ...) #:transparent)
         (define-syntax name
           (make-variable-like-transformer
            (assign-type 
             #'(λ/c- (A+i ...) (name/internal A+i ...))
             #'ty)))
         (begin-for-syntax
           (define name/internal+ (expand/df #'name/internal))
           (define-syntax name-expander
             (pattern-expander
              (syntax-parser
                [:id #'(name-expander A+i ...)] ; 0-arity case; need non-id case as well?
                [(_ A+i ...)
                 #'(~and
                    TMP
                    (~parse ((~literal #%plain-app) (~var name- id) A+i ...) #'TMP)
                    (~fail #:unless (free-id=? #'name- name/internal+))
                    )])))
           ))
;     #:do[(pretty-print (stx->datum #'OUT))]
     #'OUT
  ]))

;; equality -------------------------------------------------------------------
;(define-internal-type-constructor =)
;(define-type-constructor = : (→/c Type Type Type))
;(define-constructor = : (Π/c [A : Type] [a : A] [b : A] Type))
(struct =- (l r) #:transparent)
(define-typed-syntax (= t1 t2) ≫
  [⊢ t1 ≫ t1- ⇒ ty]
  [⊢ t2 ≫ t2- ⇐ ty]
  ---------------------
  [⊢ (=- t1- t2-) ⇒ Type])

(define-typed-syntax (eq-refl e) ≫
  [⊢ e ≫ e- ⇒ _ (⇒ ~Type)]
  ----------
  [⊢ (#%app- void-) ⇒ (= e- e-)])

;; eq-elim: t : T
;;          P : (T -> Type)
;;          pt : (P t)
;;          w : T
;;          peq : (= t w)
;;       -> (P w)
(define-typed-syntax (eq-elim t P pt w peq) ≫
  [⊢ t ≫ t- ⇒ ty]
  [⊢ P ≫ P- ⇐ (→ ty Type)]
  [⊢ pt ≫ pt- ⇐ (app P- t-)]
  [⊢ w ≫ w- ⇐ ty]
  [⊢ peq ≫ peq- ⇐ (= t- w-)]
  --------------
  [⊢ pt- ⇒ (app P- w-)])

;; top-level ------------------------------------------------------------------
;; TODO: shouldnt need define-type-alias, should be same as define?
(define-syntax define-type-alias
  (syntax-parser
    [(_ alias:id τ)
     #'(define-syntax- alias
         (make-variable-like-transformer #'τ))]))

;; TODO: delete this?
(define-typed-syntax define
  [(_ x:id (~datum :) τ e:expr) ≫
   [⊢ e ≫ e- ⇐ τ]
   #:with y (generate-temporary #'x)
   #:with y+props (transfer-props #'e- #'y #:except '(origin))
   --------
   [≻ (begin-
        (define-syntax x (make-rename-transformer #'y+props))
        (define- y e-))]]
  [(_ x:id e) ≫
   ;This won't work with mutually recursive definitions
   [⊢ e ≫ e- ⇒ _]
   #:with y (generate-temporary #'x)
   #:with y+props (transfer-props #'e- #'y #:except '(origin))
   --------
   [≻ (begin-
        (define-syntax x (make-rename-transformer #'y+props))
        (define- y e-))]])

;; TmpTy is a placeholder for undefined names
(struct TmpTy- ())
(define-syntax TmpTy
  (syntax-parser
    [:id (assign-type #'TmpTy- #'Type)]
    ;; TODO: orig will get stuck with eg, (TmpTy A)
    [(_ . args) (assign-type #'(app/eval/c TmpTy- . args) #'Type)]))
(define-for-syntax TmpTy+ (expand/df #'TmpTy))

;; helper syntax fns
(begin-for-syntax
  ;; drops first n bindings in Π type
  (define (prune t n)
    (if (zero? n)
        t
        (syntax-parse t
          [(~Π ([_ : _]) t1)
           (prune #'t1 (sub1 n))])))
  ;; x+τss = (([x τ] ...) ...)
  ;; returns subset of each (x ...) that is recursive, ie τ = TY
  (define (find-recur TY x+τss)
    (stx-map
     (λ (x+τs)
       (stx-filtermap
        (syntax-parser [(x τ) (and (free-id=? #'τ TY) #'x)])
        x+τs))
     x+τss))
  ;; x+τss = (([x τ] ...) ...)
  ;; returns subset of each (x ...) that is recursive, ie τ = (TY . args)
  ;; along with the indices needed by each recursive x
  ;; - ASSUME: the needed indices are first `num-is` arguments in x+τss
  ;; - ASSUME: the recursive arg has type (TY . args) where TY is unexpanded
  (define (find-recur/i TY num-is x+τss)
    (stx-map
     (λ (x+τs)
       (define xs (stx-map stx-car x+τs))
       (stx-filtermap
        (syntax-parser
          ;; TODO: generalize these patterns with ~plain-app/c
          [(x (_ t:id . _)) (and (free-id=? #'t TY) (cons #'x (stx-take xs num-is)))]
          [(x (_ (_ t:id . _) . _)) (and (free-id=? #'t TY) (cons #'x (stx-take xs num-is)))]
          [_ #f])
        x+τs))
     x+τss))
  )

;; use this macro to expand e, which contains references to unbound X
(define-syntax (with-unbound stx)
  (syntax-parse stx
    [(_ X:id e)
     ;swap in a tmp (bound) id `TmpTy` for unbound X
     #:with e/tmp (subst #'TmpTy #'X #'e)
     ;; expand with the tmp id
      (expand/df #'e/tmp)]))
(define-syntax (drop-params stx)
  (syntax-parse stx
    [(_ (A ...) τ)
     (prune #'τ (stx-length #'(A ...)))]))
;; must be used with with-unbound
(begin-for-syntax
  (define-syntax ~unbound
    (pattern-expander
     (syntax-parser
       [(_ X:id pat)
        ;; un-subst tmp id in expanded stx with type X
        #'(~and TMP
                (~parse pat (reflect (subst #'X TmpTy+ #'TMP free-id=?))))])))
  )

(begin-for-syntax
  (define-syntax ~app/eval/c
    (pattern-expander
     (syntax-parser
       [(_ f) #'f]
       [(_ f e . rst)
        #'(~app/eval/c ((~literal app/eval) f e) . rst)]))))

(define-typed-syntax define-datatype
  ;; simple datatypes, eg Nat -------------------------------------------------
  ;; - ie, `TY` is an id with no params or indices
  [(_ TY:id (~datum :) τ:id [C:id (~datum :) τC] ...) ≫
   ;; need with-unbound and ~unbound bc `TY` name still undefined here
   [⊢ (with-unbound TY τC) ≫ (~unbound TY (~Π/c [x : τin] ... _)) ⇐ Type] ...
   ;; ---------- pre-define some pattern variables for cleaner output:
   ;; recursive args of each C; where (xrec ...) ⊆ (x ...)
   #:with ((xrec ...) ...) (find-recur #'TY #'(([x τin] ...) ...))
   ;; elim methods and method types
   #:with (m ...) (generate-temporaries #'(C ...))
   #:with (m- ...) (generate-temporaries #'(m ...))
   #:with (τm ...) (generate-temporaries #'(m ...))
   #:with elim-TY (format-id #'TY "elim-~a" #'TY)
   #:with eval-TY (format-id #'TY "eval-~a" #'TY)
   #:with TY/internal (generate-temporary #'TY)
   #:with (C-expander ...) (stx-map mk-~ #'(C ...))
;   #:with TY-expander (mk-~ #'TY)
   --------
   [≻ (begin-
        ;; define the type, eg "Nat"
        (define-constructor TY : τ) 

        ;; define the data constructors, eg Z and S
        (define-constructor C : τC) ...
          
        ;; elimination form
        (define-typerule/red (elim-TY v P m ...) ≫
          [⊢ v ≫ v- ⇐ TY]
;          [⊢ v ≫ v- ⇒ TY-expander]
          [⊢ P ≫ P- ⇐ (→ TY Type)] ; prop / motive
          ;; each `m` can consume 2 sets of args:
          ;; 1) args of the constructor `x` ... 
          ;; 2) IHs for each `x` that has type `TY`
          #:with (τm ...) #'((Π/c [x : τin] ...
                              (→/c (app/c P- xrec) ... (app/c P- (app/c C x ...)))) ...)
          [⊢ m ≫ m- ⇐ τm] ...
          -----------
          [⊢ (eval-TY v- P- m- ...) ⇒ (app/c P- v-)]
          #:where eval-TY ; elim reduction rule
          [((C-expander x ...) P m ...) ; elim redex
           ~> (app/eval/c m x ... (eval-TY xrec P m ...) ...)] ...)
        )]]
  ;; --------------------------------------------------------------------------
  ;; defines inductive type family `TY`, with:
  ;; - params A ...
  ;; - indices i ...
  ;; - ie, TY is a type constructor with type (Π [A : τA] ... [i τi] ... τ)
  ;; --------------------------------------------------------------------------
  [(_ TY:id [A:id (~datum :) τA] ... (~datum :) ; params
            [i:id (~datum :) τi] ... ; indices
            (~datum ->) τ
   [C:id (~datum :) τC] ...) ≫
   ; need to expand `τC` but `TY` is still unbound so use tmp id
   [⊢ (with-unbound TY τC) ≫ (~unbound TY (~Π/c [A+i+x : τA+i+x] ... τout)) ⇐ Type] ...
   ;; split τC args into params and others
   ;; TODO: check that τA matches τCA (but cant do it in isolation bc they may refer to other params?)
   #:with ((([CA τCA] ...)
            ([i+x τin] ...)) ...)
          (stx-map
           (λ (x+τs) (stx-split-at x+τs (stx-length #'(A ...))))
           #'(([A+i+x τA+i+x] ...) ...))

   ;; - each (xrec ...) is subset of (x ...) that are recur args,
   ;; ie, they are not fresh ids
   ;; - each xrec is accompanied with irec ...,
   ;;   which are the indices in i+x ... needed by xrec
   ;; ASSUME: the indices are the first (stx-length (i ...)) args in i+x ...
   ;; ASSUME: indices cannot have type (TY ...), they are not recursive
   ;;         (otherwise, cannot include indices in args to find-recur/i)
   #:with (((xrec irec ...) ...) ...)
          (find-recur/i #'TY (stx-length #'(i ...)) #'(([i+x τin] ...) ...))
   ;; ---------- pre-generate other patvars; makes nested macros below easier to read
   #:with (A- ...) (generate-temporaries #'(A ...))
   #:with (i- ...) (generate-temporaries #'(i ...))
   ;; inst'ed τin and τout (with A ...)
   #:with ((τin/A ...) ...) (stx-map generate-temporaries #'((τin ...) ...))
   #:with (τout/A ...) (generate-temporaries #'(C ...))
   ; τoutA matches the A and τouti matches the i in τout/A,
   ; - ie τout/A = (TY τoutA ... τouti ...)
   ; - also, τoutA refs (ie bound-id=) CA and τouti refs i in i+x ...
   #:with ((τoutA ...) ...) (stx-map (lambda _ (generate-temporaries #'(A ...))) #'(C ...))
   #:with ((τouti ...) ...) (stx-map (lambda _ (generate-temporaries #'(i ...))) #'(C ...))
   ;; differently named `i`, to match type of P
   #:with (j ...) (generate-temporaries #'(i ...))
   ; dup (A ...) C times, again for ellipses matching
   #:with ((A*C ...) ...) (stx-map (lambda _ #'(A ...)) #'(C ...))
   #:with (m ...) (generate-temporaries #'(C ...))
   #:with (τ1 ...) (generate-temporaries #'(C ...))
   #:with (m- ...) (generate-temporaries #'(C ...))
   #:with TY- (mk-- #'TY)
   #:with TY-patexpand (mk-~ #'TY)
   #:with elim-TY (format-id #'TY "elim-~a" #'TY)
   #:with eval-TY (format-id #'TY "match-~a" #'TY)
   #:with (τm ...) (generate-temporaries #'(m ...))
   #:with (C-expander ...) (stx-map mk-~ #'(C ...))
   ;; these are all the generated definitions that implement the define-datatype
   #:with OUTPUT-DEFS
    #'(begin-
        ;; define the type
        (define-constructor TY : (Π/c [A : τA] ... [i : τi] ... τ))

        ;; define the data constructors
        (define-constructor C : τC) ...

        ;; define eliminator-form elim-TY
        ;; v = target
        ;; - infer A ... from v
        ;; P = motive
        ;; - is a (curried) fn that consumes:
        ;;   - indices i ... with type τi
        ;;   - and TY A ... i ... 
        ;;     - where A ... args is A ... inferred from v
        ;;     - and τi also instantiated with A ...
        ;; - output is a type
        ;; m = branches
        ;; - each is a fn that consumes:
        ;;   - maybe indices i ... (if they are needed by args)
        ;;   - constructor args
        ;;     - inst with A ... inferred from v
        ;;   - maybe IH for recursive args
        (define-typerule/red (elim-TY v P m ...) ≫
          ;; target, infers A ...
          [⊢ v ≫ v- ⇒ (TY-patexpand A ... i ...)]
          
          ;; inst τin and τout with inferred A ...
          ;; - unlike in the TY def, must explicitly instantiate here
          ;; bc these types reference a different binder, ie CA instead of A
          ;; - specifically, replace CA ... with the inferred A ... params
          ;; - don't need to instantiate τi ... bc they already reference A,
          ;;   which we reused as the pattern variable above
          #:with ((τin/A ... τout/A) ...)
                 (stx-map
                  (λ (As τs) (substs #'(A ...) As τs))
                  #'((CA ...) ...)
                  #'((τin ... τout) ...))

          ;; τi here is τi above, instantiated with A ... from v-
          [⊢ P ≫ P- ⇐ (Π/c [j : τi] ... (→ (app/c TY A ... j ...) Type))]

          ;; get the params and indices in τout/A
          ;; - dont actually need τoutA, except to find τouti
          ;; - τouti dictates what what "index" args P should be applied to
          ;;   in each method output type
          ;;     ie, it is the (app P- τouti ...) below
          ;;   It is the index, "unified" with its use in τout/A
          ;;   Eg, for empty indexed list, for index n, τouti = 0
          ;;       for non-empt indx list, for index n, τouti = (Succ 0)
          ;; ASSUMING: τoutA has shape (TY . args) (ie, unexpanded)
          #:with ((~app/eval/c (~literal TY) τoutA ... τouti ...) ...) #'(τout/A ...)

          ;; each m is curried fn consuming 3 (possibly empty) sets of args:
          ;; 1,2) i+x  - indices of the tycon, and args of each constructor `C`
          ;;             the indices may not be included, when not needed by the xs
          ;; 3) IHs - for each xrec ... (which are a subset of i+x ...)
          #:with (τm ...)
                 #'((Π/c [i+x : τin/A] ... ; constructor args ; ASSUME: i+x includes indices
                         (→/c (app/c P- irec ... xrec) ... ; IHs
                              (app/c P- τouti ... (app/c C A*C ... i+x ...)))) ...)
          [⊢ m ≫ m- ⇐ τm] ...
          -----------
          [⊢ (eval-TY v- P- m- ...) ⇒ (app/c P- i ... v-)]
          #:where eval-TY ; elim reduction rule
          [((C-expander CA ... i+x ...) P m ...) ; elim redex
           ~> (app/eval/c m i+x ... (eval-TY xrec P m ...) ...)] ...)
        )
   --------
   [≻ OUTPUT-DEFS]])

