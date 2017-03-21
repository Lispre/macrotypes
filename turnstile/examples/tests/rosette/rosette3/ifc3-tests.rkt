#lang s-exp "../../../rosette/ifc3.rkt"
(require "../../rackunit-typechecking.rkt")

;; verify-EENI-demo.rkt

;; takes ~90min to run

(define (verify/halted [p : Prog] -> (CU Witness CTrue))
  (verify-EENI* init halted? mem≈ p))
(define (verify/halted+low [p : Prog] -> (CU Witness CTrue))
  (verify-EENI* init halted∩low? mem≈ p))
(define (verify/halted+low/steps [p : Prog] [k : CInt] -> (CU Witness CTrue))
  (verify-EENI* init halted∩low? mem≈ p k))

;; basic-bugs --------------------------------------------------
(define basic-p0 (program 3 (list Halt Noop Push Pop Add* Load* Store*AB)))
(define basic-p1 (program 3 (list Halt Noop Push Pop Add* Load* Store*B)))
(define basic-p2 (program 5 (list Halt Noop Push Pop Add* Load* Store)))
(define basic-p3 (program 7 (list Halt Noop Push Pop Add  Load* Store)))
(check-type basic-p0 : Prog)
(check-type basic-p1 : Prog)
(check-type basic-p2 : Prog)
(check-type basic-p3 : Prog)

(define basic-w0 (verify/halted basic-p0))
(define basic-w1 (verify/halted basic-p1))
(define basic-w2 (verify/halted basic-p2))
(define basic-w3 (verify/halted basic-p3))
(check-type (EENI-witness? basic-w0) : Bool -> #t)
(check-type (EENI-witness? basic-w1) : Bool -> #t)
(check-type (EENI-witness? basic-w2) : Bool -> #t)
(check-type (EENI-witness? basic-w3) : Bool -> #t)
(check-type basic-w0
 : (CU Witness CTrue)
 -> (EENI-witness
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list
               (instruction Push (@ -16 ⊥))
               (instruction Push (@ 1 ⊤))
               (instruction Store*AB)))
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list
               (instruction Push (@ -16 ⊥))
               (instruction Push (@ 0 ⊤))
               (instruction Store*AB)))
     3
     mem≈))
(check-type basic-w1
 : (CU Witness CTrue)
 -> (EENI-witness
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list
               (instruction Push (@ -16 public))
               (instruction Push (@ 1 secret))
               (instruction Store*B)))
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list
               (instruction Push (@ -16 public))
               (instruction Push (@ 0 secret))
               (instruction Store*B)))
     3
     mem≈))
(check-type basic-w2
 : (CU Witness CTrue)
 -> (EENI-witness
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list
               (instruction Push (@ -16 public))
               (instruction Push (@ 0 secret))
               (instruction Add*)
               (instruction Push (@ 1 public))
               (instruction Store)))
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list
               (instruction Push (@ -16 public))
               (instruction Push (@ 8 secret))
               (instruction Add*)
               (instruction Push (@ 1 public))
               (instruction Store)))
     5
     mem≈))
(check-type basic-w3
 : (CU Witness CTrue)
 -> (EENI-witness
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list
               (instruction Push (@ 1 secret))
               (instruction Push (@ 0 secret))
               (instruction Push (@ 1 public))
               (instruction Store)
               (instruction Load*)
               (instruction Push 0@⊥)
               (instruction Store)))
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list
               (instruction Push (@ 0 secret))
               (instruction Push (@ 0 secret))
               (instruction Push (@ 1 public))
               (instruction Store)
               (instruction Load*)
               (instruction Push 0@⊥)
               (instruction Store)))
     7
     mem≈))

;; basic-correct --------------------------------------------------
(define basic-p4 (program 7 (list Halt Noop Push Pop Add Load Store)))
(define basic-p5 (program 8 (list Halt Noop Push Pop Add Load Store)))
(check-type basic-p4 : Prog)
(check-type basic-p5 : Prog)

(define basic-w4 (verify/halted basic-p4))
(define basic-w5 (verify/halted basic-p5))
(check-type basic-w4 : (CU Witness CTrue) -> #t)
(check-type basic-w5 : (CU Witness CTrue) -> #t)


;; jump-bugs --------------------------------------------------
(define jump-p0 (program 6 (list Halt Noop Push Pop Add Load Store Jump*AB)))
(define jump-p1 (program 4 (list Halt Noop Push Pop Add Load Store Jump*B)))
(check-type jump-p0 : Prog)
(check-type jump-p1 : Prog)

(define jump-w0 (verify/halted jump-p0))
(define jump-w1 (verify/halted jump-p1))
(check-type jump-w0 : (CU Witness CTrue)
 -> (EENI-witness
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list (instruction Noop)
                    (instruction Push (@ 0 ⊤))
                    (instruction Push (@ 4 ⊤))
                    (instruction Jump*AB)
                    (instruction Push (@ 1 ⊥))
                    (instruction Store)))
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list (instruction Noop)
                    (instruction Push (@ 6 ⊤))
                    (instruction Push (@ 3 ⊤))
                    (instruction Jump*AB)
                    (instruction Push (@ 1 ⊥))
                    (instruction Store)))
     6
     mem≈))
(check-type jump-w1 : (CU Witness CTrue)
 -> (EENI-witness
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list (instruction Push (@ 2 ⊤))
                    (instruction Jump*B)
                    (instruction Push (@ 4 ⊥))
                    (instruction Jump*B)))
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list (instruction Push (@ 4 ⊤))
                    (instruction Jump*B)
                    (instruction Push (@ 4 ⊥))
                    (instruction Jump*B)))
     4
     mem≈))

;; jump-correct --------------------------------------------------
(define jump-p2 (program 7 (list Halt Noop Push Pop Add Load Store Jump)))
(define jump-p3 (program 8 (list Halt Noop Push Pop Add Load Store Jump)))
(check-type jump-p2 : Prog)
(check-type jump-p3 : Prog)

(define jump-w2 (verify/halted jump-p2))
(define jump-w3 (verify/halted jump-p3))
(check-type jump-w2 : (CU Witness CTrue) -> #t)
(check-type jump-w3 : (CU Witness CTrue) -> #t)

;; call-return-bugs --------------------------------------------------
(define call-return-p0
  (program 7 (list Halt Noop Push Pop Add Load Store Call*B Return*AB)))
(define call-return-p1
  (program 8 (list Halt Noop Push Pop Add Load StoreCR Call*B Return*AB)))
(define call-return-p2
  (program 8 (list Halt Noop Push Pop Add Load StoreCR Call*B Return*B)))
(define call-return-p3
  (program 10 (list Halt Noop Push Pop Add Load StoreCR Call Return)))
(check-type call-return-p0 : Prog)
(check-type call-return-p1 : Prog)
(check-type call-return-p2 : Prog)
(check-type call-return-p3 : Prog)

(define call-return-w0 (verify/halted+low call-return-p0))
(define call-return-w1 (verify/halted+low call-return-p1))
(define call-return-w2 (verify/halted+low call-return-p2))
(define call-return-w3 (verify/halted+low call-return-p3))
(check-type call-return-w0 : (CU Witness CTrue)
 -> (EENI-witness
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list (instruction Push (@ 3 ⊤))
                    (instruction Call*B 0@⊥)
                    (instruction Halt)
                    (instruction Push (@ 4 ⊥))
                    (instruction Push 0@⊥)
                    (instruction Store)
                    (instruction Return*AB (@ 1 ⊥))))
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list (instruction Push (@ 6 ⊤))
                    (instruction Call*B 0@⊥)
                    (instruction Halt)
                    (instruction Push (@ 4 ⊥))
                    (instruction Push 0@⊥)
                    (instruction Store)
                    (instruction Return*AB (@ 1 ⊥))))
     7
     mem≈))
(check-type call-return-w1 : (CU Witness CTrue)
 -> (EENI-witness
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list (instruction Push (@ 0 ⊤))
                    (instruction Push (@ 6 ⊤))
                    (instruction Call*B (@ 1 ⊥))
                    (instruction Push 0@⊥)
                    (instruction StoreCR)
                    (instruction Halt)
                    (instruction Push (@ -9 ⊥))
                    (instruction Return*AB (@ 1 ⊥))))
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list (instruction Push (@ 0 ⊤))
                    (instruction Push (@ 7 ⊤))
                    (instruction Call*B (@ 1 ⊥))
                    (instruction Push 0@⊥)
                    (instruction StoreCR)
                    (instruction Halt)
                    (instruction Push (@ -9 ⊥))
                    (instruction Return*AB (@ 1 ⊥))))
     8
     mem≈))
(check-type call-return-w2 : (CU Witness CTrue)
 -> (EENI-witness
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list (instruction Push (@ 5 ⊥))
                    (instruction Call*B 0@⊥)
                    (instruction Push (@ 1 ⊥))
                    (instruction StoreCR)
                    (instruction Halt)
                    (instruction Push 0@⊥)
                    (instruction Push (@ 0 ⊤))
                    (instruction Return*B (@ 1 ⊥))))
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list (instruction Push (@ 5 ⊥))
                    (instruction Call*B 0@⊥)
                    (instruction Push (@ 1 ⊥))
                    (instruction StoreCR)
                    (instruction Halt)
                    (instruction Push 0@⊥)
                    (instruction Push (@ -4 ⊤))
                    (instruction Return*B (@ 1 ⊥))))
     8
     mem≈))

(check-type call-return-w3 : (CU Witness CTrue)
 -> (EENI-witness
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list (instruction Push (@ 6 ⊥))
                    (instruction Call 0@⊥ (@ 1 ⊥))
                    (instruction Halt)
                    (instruction Pop)
                    (instruction Push (@ 4 ⊥))
                    (instruction Return)
                    (instruction Push (@ 3 ⊤))
                    (instruction Call (@ 1 ⊥) (@ 1 ⊥))
                    (instruction Push 0@⊥)
                    (instruction StoreCR)))
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list (instruction Push (@ 6 ⊥))
                    (instruction Call 0@⊥ (@ 1 ⊥))
                    (instruction Halt)
                    (instruction Pop)
                    (instruction Push (@ 4 ⊥))
                    (instruction Return)
                    (instruction Push (@ 4 ⊤))
                    (instruction Call (@ 1 ⊥) (@ 1 ⊥))
                    (instruction Push 0@⊥)
                    (instruction StoreCR)))
     10
     mem≈))

;; call-return-correct --------------------------------------------------
(define call-return-p4
  (program 10 (list Halt Noop Push PopCR Add Load StoreCR Call Return)))
(check-type call-return-p4 : Prog)
(define call-return-w4 (verify/halted+low call-return-p4))
(check-type call-return-w4 : (CU Witness CTrue) -> #t)


;; reproduce-bugs --------------------------------------------------
;; ~45sec
(define reproduce-p0
  (program (list Push Call*B Halt Push Push Store Return*AB)))
(define reproduce-p1
  (program (list Push Push Call*B Push StoreCR Halt Push Return*AB)))
(define reproduce-p2
  (program (list Push Push Call*B Push StoreCR Halt Return*B Push Return*B)))
(define reproduce-p3
  (program (list Push Call Push StoreCR Halt Push Push Call Pop Push Return)))
(check-type reproduce-p0 : Prog)
(check-type reproduce-p1 : Prog)
(check-type reproduce-p2 : Prog)
(check-type reproduce-p3 : Prog)

(define reproduce-w0 (verify/halted+low reproduce-p0))
(define reproduce-w1 (verify/halted+low reproduce-p1))
(define reproduce-w2 (verify/halted+low reproduce-p2))
(define reproduce-w3 (verify/halted+low/steps reproduce-p3 13))
(check-type reproduce-w0 : (CU Witness CTrue)
 -> (EENI-witness
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list (instruction Push (@ 3 ⊤))
                    (instruction Call*B 0@⊥)
                    (instruction Halt)
                    (instruction Push (@ 4 ⊤))
                    (instruction Push 0@⊥)
                    (instruction Store)
                    (instruction Return*AB 0@⊥)))
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list (instruction Push (@ 6 ⊤))
                    (instruction Call*B 0@⊥)
                    (instruction Halt)
                    (instruction Push (@ 4 ⊤))
                    (instruction Push 0@⊥)
                    (instruction Store)
                    (instruction Return*AB 0@⊥)))
     7
     mem≈))
(check-type reproduce-w1 : (CU Witness CTrue)
 -> (EENI-witness
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list (instruction Push 0@⊥)
                    (instruction Push (@ 6 ⊤))
                    (instruction Call*B (@ 1 ⊥))
                    (instruction Push (@ 1 ⊥))
                    (instruction StoreCR)
                    (instruction Halt)
                    (instruction Push (@ 1 ⊥))
                    (instruction Return*AB (@ 1 ⊥))))
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list (instruction Push 0@⊥)
                    (instruction Push (@ 7 ⊤))
                    (instruction Call*B (@ 1 ⊥))
                    (instruction Push (@ 1 ⊥))
                    (instruction StoreCR)
                    (instruction Halt)
                    (instruction Push (@ 1 ⊥))
                    (instruction Return*AB (@ 1 ⊥))))
     8
     mem≈))
(check-type reproduce-w2 : (CU Witness CTrue)
 -> (EENI-witness
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list (instruction Push 0@⊥)
                    (instruction Push (@ 7 ⊥))
                    (instruction Call*B 1@⊥)
                    (instruction Push 0@⊥)
                    (instruction StoreCR)
                    (instruction Halt)
                    (instruction Return*B (@ -1 ⊤))
                    (instruction Push 1@⊤)
                    (instruction Return*B 1@⊥)))
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list (instruction Push 0@⊥)
                    (instruction Push (@ 7 ⊥))
                    (instruction Call*B 1@⊥)
                    (instruction Push 0@⊥)
                    (instruction StoreCR)
                    (instruction Halt)
                    (instruction Return*B (@ 1 ⊤))
                    (instruction Push 0@⊤)
                    (instruction Return*B 1@⊥)))
     9
     mem≈))
(check-type reproduce-w3 : (CU Witness CTrue)
 -> (EENI-witness
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list (instruction Push (@ 6 ⊥))
                    (instruction Call 0@⊥ 1@⊥)
                    (instruction Push 0@⊥)
                    (instruction StoreCR)
                    (instruction Halt)
                    (instruction Push (@ -1 ⊤))
                    (instruction Push (@ 9 ⊤))
                    (instruction Call 0@⊥ 1@⊥)
                    (instruction Pop)
                    (instruction Push 1@⊥)
                    (instruction Return)))
     (machine 0@⊥
              (list)
              (list 0@⊥ 0@⊥)
              (list (instruction Push (@ 6 ⊥))
                    (instruction Call 0@⊥ 1@⊥)
                    (instruction Push 0@⊥)
                    (instruction StoreCR)
                    (instruction Halt)
                    (instruction Push (@ -3 ⊤))
                    (instruction Push (@ 8 ⊤))
                    (instruction Call 0@⊥ 1@⊥)
                    (instruction Pop)
                    (instruction Push 1@⊥)
                    (instruction Return)))
     13
     mem≈))

;; (define (valid-case name ended? prog [k #f])
;;   (test-case name (check-true (verify-EENI* init ended? mem≈ prog k))))

;; (define-syntax-rule (define-tests id desc expr ...)
;;   (define id
;;     (test-suite+ 
;;      desc 
;;      (begin expr ...))))

;; ; Checks for counterexamples for bugs in basic semantics. 
;; (define-tests basic-bugs "IFC: counterexamples for bugs in basic semantics"
;;   (cex-case "Fig. 1" halted? (program 3 (list Halt Noop Push Pop Add* Load* Store*AB))) 
;;   (cex-case "Fig. 2" halted? (program 3 (list Halt Noop Push Pop Add* Load* Store*B)))  
;;   (cex-case "Fig. 3" halted? (program 5 (list Halt Noop Push Pop Add* Load* Store)))  
;;   (cex-case "Fig. 4" halted? (program 7 (list Halt Noop Push Pop Add Load* Store))))  

;; (define-tests basic-correct "IFC: no bounded counterexamples for correct basic semantics"
;;   (valid-case "*" halted? (program 7 (list Halt Noop Push Pop Add Load Store)))  
;;   (valid-case "+" halted? (program 8 (list Halt Noop Push Pop Add Load Store))))  

;; (define-tests jump-bugs "IFC: counterexamples for bugs in jump+basic semantics"
;;   (cex-case "11" halted? (program 6 (list Halt Noop Push Pop Add Load Store Jump*AB)))  
;;   (cex-case "12" halted? (program 4 (list Halt Noop Push Pop Add Load Store Jump*B)))) 

;; (define-tests jump-correct "IFC: no bounded counterexamples for correct jump+basic semantics"
;;   (valid-case "**" halted? (program 7 (list Halt Noop Push Pop Add Load Store Jump)))    
;;   (valid-case "++" halted? (program 8 (list Halt Noop Push Pop Add Load Store Jump))))    

;; (define-tests call-return-bugs "IFC: counterexamples for buggy call+return+basic semantics"
;;   (cex-case "Fig. 13" halted∩low? (program 7 (list Halt Noop Push Pop Add Load Store Call*B Return*AB)))
;;   (cex-case "Fig. 15" halted∩low? (program 8 (list Halt Noop Push Pop Add Load StoreCR Call*B Return*AB)))
;;   (cex-case "Fig. 16" halted∩low? (program 8 (list Halt Noop Push Pop Add Load StoreCR Call*B Return*B)))
;;   (cex-case "Fig. 17" halted∩low? (program 10 (list Halt Noop Push Pop Add Load StoreCR Call Return))))

;; (define-tests reproduce-bugs "IFC: counterexamples that are structurally similar to those in prior work"
;;   (cex-case "Fig. 13*" halted∩low? (program (list Push Call*B Halt Push Push Store Return*AB)))
;;   (cex-case "Fig. 15*" halted∩low? (program (list Push Push Call*B Push StoreCR Halt Push Return*AB)))
;;   (cex-case "Fig. 16*" halted∩low? (program (list Push Push Call*B Push StoreCR Halt Return*B Push Return*B)))
;;   (cex-case "Fig. 17*" 
;;             halted∩low? 
;;             (program (list Push Call Push StoreCR Halt Push Push Call Pop Push Return))
;;             13))

;; (define (fast-tests)
;;   (time (run-tests basic-bugs))       ; ~10 sec
;;   (time (run-tests basic-correct))    ; ~20 sec
;;   (time (run-tests jump-bugs)))       ; ~7 sec

;; (define (slow-tests)
;;   (time (run-tests jump-correct))     ; ~52 sec
;;   (time (run-tests call-return-bugs)) ; ~440 sec
;;   (time (run-tests reproduce-bugs)))  ; ~256 sec

;; (module+ fast
;;   (fast-tests))

;; (module+ test
;;   (fast-tests)
;;   (slow-tests))
