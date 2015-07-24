#lang racket/base
(require (for-syntax rackunit) rackunit "../typecheck.rkt")
(provide (all-defined-out))

(define-syntax (check-type stx)
  (syntax-parse stx #:datum-literals (:)
    [(_ e : τ ⇒ v) #'(check-type-and-result e : τ ⇒ v)]
    [(_ e : τ-expected:type)
     #:with τ (typeof (expand/df #'e))
     #:fail-unless (typecheck? #'τ ((current-type-eval) #'τ-expected))
     (format
      "Expression ~a [loc ~a:~a] has type ~a, expected ~a"
      (syntax->datum #'e) (syntax-line #'e) (syntax-column #'e)
      (syntax->datum (get-orig #'τ)) (syntax->datum (get-orig #'τ-expected)))
     #'(void)]))

(define-syntax (check-not-type stx)
  (syntax-parse stx #:datum-literals (:)
    [(_ e : not-τ:type)
     #:with τ (typeof (expand/df #'e))
     #:fail-when (typecheck? #'τ ((current-type-eval) #'not-τ.norm))
     (format
      "(~a:~a) Expression ~a should not have type ~a"
      (syntax-line stx) (syntax-column stx)
      (syntax->datum #'e) (syntax->datum #'τ))
     #'(void)]))

(define-syntax (typecheck-fail stx)
  (syntax-parse stx #:datum-literals (:)
    [(_ e (~optional (~seq #:with-msg msg-pat:str) #:defaults ([msg-pat ""])))
     #:when (check-exn
             (λ (ex) (or (exn:fail? ex) (exn:test:check? ex)))
             (λ ()
               (with-handlers
                   ; check err msg matches
                   ([exn:fail?
                     (λ (ex)
                       (unless (regexp-match? (syntax-e #'msg-pat) (exn-message ex))
                         (printf
                          (string-append
                           "ERROR: wrong err msg produced by expression ~v:\n"
                           "expected msg matching pattern ~v, got:\n ~v")
                          (syntax->datum #'e) (syntax-e #'msg-pat) (exn-message ex)))
                       (raise ex))])
                 (expand/df #'e)))
             (format
              "Expected type check failure but expression ~a has valid type, OR wrong err msg received."
              (syntax->datum #'e)))
     #'(void)]))

(define-syntax (check-type-and-result stx)
  (syntax-parse stx #:datum-literals (: ⇒)
    [(_ e : τ ⇒ v)
     #'(begin
         (check-type e : τ)
         (check-equal? e v))]))
