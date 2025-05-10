;; Generic Executable Trait
;; This trait defines the standard interface for contracts that can be called by the proposal system

(define-trait executable-trait
  (
    ;; Execute function that takes a buffer of parameters and returns a success/failure response
    (execute ((buff 1024)) (response bool uint))
  )
)