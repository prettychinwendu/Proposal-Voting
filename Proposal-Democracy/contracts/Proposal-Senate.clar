;; Proposal Submission System
;; A comprehensive smart contract for submitting, voting on, and executing proposals

;; Constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u101))
(define-constant ERR_PROPOSAL_ALREADY_EXISTS (err u102))
(define-constant ERR_VOTING_PERIOD_ENDED (err u103))
(define-constant ERR_VOTING_PERIOD_NOT_ENDED (err u104))
(define-constant ERR_ALREADY_VOTED (err u105))
(define-constant ERR_INSUFFICIENT_TOKENS (err u106))
(define-constant ERR_PROPOSAL_ALREADY_EXECUTED (err u107))
(define-constant ERR_INVALID_VOTE (err u108))
(define-constant ERR_EXECUTION_FAILED (err u109))
(define-constant ERR_INVALID_PROPOSAL_DATA (err u110))
(define-constant ERR_PROPOSAL_REJECTED (err u111))

;; Governance token
(define-fungible-token governance-token)

;; Data maps

;; Proposal status enum: 0 = Active, 1 = Approved, 2 = Rejected, 3 = Executed
(define-data-var next-proposal-id uint u0)

;; Initial token distribution for governance
(define-data-var total-supply uint u1000000)

;; Reference to the executor helper contract
(define-data-var executor-helper principal tx-sender)

;; Define the executor trait interface
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

;; Define the executable trait
(define-trait executable-contract
  (
    ;; Execute function that takes a buffer of parameters and returns a success/failure response
    (execute ((buff 1024)) (response bool uint))
  )
)

;; Whitelisted contracts that can be called by proposals
(define-map whitelisted-contracts
  { contract: principal }
  { allowed: bool }
)

;; Core proposal data
(define-map proposals
  { proposal-id: uint }
  {
    title: (string-ascii 100),
    description: (string-utf8 1000),
    proposer: principal,
    voting-period-end: uint,
    votes-for: uint,
    votes-against: uint,
    executed: bool,
    execution-data: (optional (buff 1024)),
    status: uint
  }
)

;; Track who has voted on each proposal
(define-map proposal-votes
  { proposal-id: uint, voter: principal }
  { voted: bool, support: bool, weight: uint }
)

;; Contract owner - can update parameters and manage whitelist
(define-data-var contract-owner principal tx-sender)

;; Minimum tokens needed to submit a proposal
(define-data-var proposal-threshold uint u10000)

;; Default voting period in blocks
(define-data-var default-voting-period uint u144) ;; ~1 day on Stacks

;; Read-only functions

(define-read-only (get-proposal (proposal-id uint))
  (match (map-get? proposals { proposal-id: proposal-id })
    proposal (ok proposal)
    ERR_PROPOSAL_NOT_FOUND
  )
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (default-to 
    { voted: false, support: false, weight: u0 }
    (map-get? proposal-votes { proposal-id: proposal-id, voter: voter })
  )
)

(define-read-only (get-proposal-count)
  (var-get next-proposal-id)
)

(define-read-only (get-token-balance (account principal))
  (ft-get-balance governance-token account)
)

(define-read-only (is-contract-whitelisted (contract principal))
  (default-to false (get allowed (map-get? whitelisted-contracts { contract: contract })))
)

(define-read-only (can-execute-proposal (proposal-id uint))
  (match (map-get? proposals { proposal-id: proposal-id })
    proposal (begin
      (if (not (get executed proposal))
        (if (> (get voting-period-end proposal) block-height)
          (if (> (get votes-for proposal) (get votes-against proposal))
            (ok true)
            ERR_PROPOSAL_REJECTED
          )
          ERR_VOTING_PERIOD_NOT_ENDED
        )
        ERR_PROPOSAL_ALREADY_EXECUTED
      )
    )
    ERR_PROPOSAL_NOT_FOUND
  )
)

;; Write functions

;; Submit a new proposal
(define-public (submit-proposal 
    (title (string-ascii 100)) 
    (description (string-utf8 1000))
    (execution-data (optional (buff 1024)))
  )
  (let (
    (proposal-id (var-get next-proposal-id))
    (token-balance (ft-get-balance governance-token tx-sender))
    (voting-end (+ block-height (var-get default-voting-period)))
  )
    ;; Check if proposer has enough governance tokens
    (asserts! (>= token-balance (var-get proposal-threshold)) ERR_INSUFFICIENT_TOKENS)
    
    ;; Create the proposal
    (map-set proposals
      { proposal-id: proposal-id }
      {
        title: title,
        description: description,
        proposer: tx-sender,
        voting-period-end: voting-end,
        votes-for: u0,
        votes-against: u0,
        executed: false,
        execution-data: execution-data,
        status: u0 ;; Active
      }
    )
    
    ;; Increment proposal ID for next proposal
    (var-set next-proposal-id (+ proposal-id u1))
    
    ;; Return the new proposal ID
    (ok proposal-id)
  )
)

;; Cast a vote on a proposal
(define-public (vote (proposal-id uint) (support bool))
  (let (
    (voter tx-sender)
    (token-balance (ft-get-balance governance-token voter))
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
    (vote-record (get-vote proposal-id voter))
  )
    ;; Ensure proposal is still active
    (asserts! (< block-height (get voting-period-end proposal)) ERR_VOTING_PERIOD_ENDED)
    
    ;; Ensure user hasn't already voted
    (asserts! (not (get voted vote-record)) ERR_ALREADY_VOTED)
    
    ;; Ensure user has tokens to vote with
    (asserts! (> token-balance u0) ERR_INSUFFICIENT_TOKENS)
    
    ;; Record the vote
    (map-set proposal-votes
      { proposal-id: proposal-id, voter: voter }
      { voted: true, support: support, weight: token-balance }
    )
    
    ;; Update proposal vote counts
    (if support
      (map-set proposals 
        { proposal-id: proposal-id }
        (merge proposal { votes-for: (+ (get votes-for proposal) token-balance) })
      )
      (map-set proposals 
        { proposal-id: proposal-id }
        (merge proposal { votes-against: (+ (get votes-against proposal) token-balance) })
      )
    )
    
    (ok true)
  )
)

;; Execute an approved proposal
(define-public (execute-proposal (proposal-id uint) (executor-helper-contract <executor-helper-trait>))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
  )
    ;; Check if proposal voting has ended
    (asserts! (>= block-height (get voting-period-end proposal)) ERR_VOTING_PERIOD_NOT_ENDED)
    
    ;; Check if proposal has not been executed yet
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
    
    ;; Check if proposal has more votes for than against
    (asserts! (> (get votes-for proposal) (get votes-against proposal)) ERR_PROPOSAL_REJECTED)
    
    ;; Update proposal status
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { 
        executed: true,
        status: u3 ;; Executed
      })
    )
    
    ;; Execute the proposal if execution data is provided
    (match (get execution-data proposal)
      data 
        (begin
          ;; Parse the contract principal from the first part of the buffer
          (let (
            (target-contract (unwrap! (contract-call? executor-helper-contract get-target-contract data) ERR_EXECUTION_FAILED))
            (call-data (unwrap! (contract-call? executor-helper-contract get-call-data data) ERR_EXECUTION_FAILED))
          )
            ;; Check if the contract is whitelisted
            (asserts! (is-contract-whitelisted target-contract) ERR_UNAUTHORIZED)
            
            ;; Call the execute function with the parsed data
            (contract-call? executor-helper-contract execute data)
          )
        )
      (ok true) ;; No execution data, just mark as executed
    )
  )
)

;; Update proposal result after voting period ends
(define-public (finalize-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
  )
    ;; Check if proposal voting has ended
    (asserts! (>= block-height (get voting-period-end proposal)) ERR_VOTING_PERIOD_NOT_ENDED)
    
    ;; Check if proposal has not been finalized yet (status is still Active)
    (asserts! (is-eq (get status proposal) u0) ERR_PROPOSAL_ALREADY_EXECUTED)
    
    ;; Update proposal status based on votes
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { 
        status: (if (> (get votes-for proposal) (get votes-against proposal)) u1 u2) ;; 1=Approved, 2=Rejected
      })
    )
    
    (ok true)
  )
)

;; Admin functions

;; Mint initial governance tokens - only can be called by contract owner
(define-public (mint-tokens (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ft-mint? governance-token amount recipient)
  )
)

;; Update contract owner
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Add or remove a contract from the whitelist
(define-public (set-whitelisted-contract (contract principal) (allowed bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set whitelisted-contracts { contract: contract } { allowed: allowed })
    (ok true)
  )
)

;; Update proposal threshold
(define-public (set-proposal-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set proposal-threshold new-threshold)
    (ok true)
  )
)

;; Update default voting period
(define-public (set-voting-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set default-voting-period new-period)
    (ok true)
  )
)

;; Set the executor helper contract
(define-public (set-executor-helper (new-helper principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set executor-helper new-helper)
    (ok true)
  )
)

;; Initialize the contract
(define-private (initialize)
  (begin
    ;; Mint initial supply to contract owner
    (unwrap! (ft-mint? governance-token (var-get total-supply) (var-get contract-owner)) false)
    true
  )
)

;; Call initialize on contract deploy
(initialize)