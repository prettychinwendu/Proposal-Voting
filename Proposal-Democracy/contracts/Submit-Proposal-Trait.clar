;; File: submit-proposal-trait.clar
;; This trait defines the interface for submitting proposals

(define-trait submit-proposal-trait
  (
    ;; Submit a new proposal
    (submit-proposal ((string-ascii 100) (string-utf8 1000) (optional (buff 1024))) (response uint uint))
  )
)