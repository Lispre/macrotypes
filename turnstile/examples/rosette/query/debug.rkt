#lang turnstile
(require
 (prefix-in t/ro: (only-in "../rosette2.rkt" λ ann begin C→ Nothing Bool CSolution))
 (prefix-in ro: rosette/query/debug))

(define-typed-syntax define/debug #:datum-literals (: -> →)
  [(d x:id e) ≫
   [⊢ [e ≫ e- ⇒ : τ]]
   #:with y (generate-temporary #'x)
   --------
   [_ ≻ (begin-
          (define-syntax- x (make-rename-transformer (⊢ y : τ)))
          (ro:define/debug y e-))]]
  [(d (f [x : ty] ... (~or → ->) ty_out) e ...+) ≫
;   [⊢ [e ≫ e- ⇒ : ty_e]]
   #:with f- (generate-temporary #'f)
   --------
   [_ ≻ (begin-
          (define-syntax- f (make-rename-transformer (⊢ f- : (t/ro:C→ ty ... ty_out))))
              (ro:define/debug f- 
                (t/ro:λ ([x : ty] ...) 
                        (t/ro:ann (t/ro:begin e ...) : ty_out))))]])

(define-typed-syntax debug
  [(d (solvable-pred ...+) e) ≫
   [⊢ [solvable-pred ≫ solvable-pred- ⇐ : (t/ro:C→ t/ro:Nothing t/ro:Bool)]] ...
   [⊢ [e ≫ e- ⇒ : τ]]
   --------
   [⊢ [_ ≫ (ro:debug (solvable-pred- ...) e-) ⇒ : t/ro:CSolution]]])
  
