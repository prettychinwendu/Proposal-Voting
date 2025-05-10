;; Executor Helper Trait
;; This trait defines the interface for the executor helper

(define-trait executor-helper-trait
  (
    ;; Extract the target contract principal from the execution data
    (get-target-contract ((buff 1024)) (response principal uint))
    
    ;; Extract the call data from the execution data
    (get-call-data ((buff 1024)) (response (buff 1024) uint))
    
    ;; Execute the proposal data
    (execute ((buff 1024)) (response bool uint))
  )
)