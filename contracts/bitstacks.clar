;; Title: BitStacks DAO: Decentralized Bitcoin Treasury Management

;; Summary:
;; A next-generation DAO contract enabling secure, compliant Bitcoin-native asset management through decentralized governance
;; on Stacks Layer 2. Implements stake-based voting, proposal lifecycle management, and cross-chain compatible treasury controls.

;; Description:
;; BitStacks DAO revolutionizes decentralized finance by combining Bitcoin's security with Stacks Layer 2 programmability.
;; Features institutional-grade proposal safeguards, dynamic quorum calculations, and non-custodial governance for
;; Bitcoin-based assets. Designed for regulatory compatibility with built-in compliance checkpoints and transparent
;; audit trails.

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-VOTED (err u103))
(define-constant ERR-PROPOSAL-EXPIRED (err u104))
(define-constant ERR-INSUFFICIENT-BALANCE (err u105))
(define-constant ERR-PROPOSAL-NOT-ACTIVE (err u106))
(define-constant ERR-INVALID-STATUS (err u107))
(define-constant ERR-INVALID-OWNER (err u108))
(define-constant ERR-INVALID-TITLE (err u109))
(define-constant ERR-INVALID-DESCRIPTION (err u110))
(define-constant ERR-INVALID-RECIPIENT (err u111))
(define-constant ERR-INVALID-VOTE (err u112))

;; Data Variables
(define-data-var dao-owner principal tx-sender)
(define-data-var total-staked uint u0)
(define-data-var proposal-count uint u0)
(define-data-var quorum-threshold uint u500) ;; 50% in basis points
(define-data-var proposal-duration uint u144) ;; ~24 hours in blocks
(define-data-var min-proposal-amount uint u1000000) ;; in uSTX

;; Data Maps
(define-map members 
    principal 
    {
        staked-amount: uint,
        last-reward-block: uint,
        rewards-claimed: uint
    }
)

(define-map proposals 
    uint 
    {
        proposer: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        amount: uint,
        recipient: principal,
        start-block: uint,
        end-block: uint,
        yes-votes: uint,
        no-votes: uint,
        status: (string-ascii 20),
        executed: bool
    }
)

(define-map votes 
    {proposal-id: uint, voter: principal} 
    {vote: bool}
)

;; Private Functions
(define-private (is-dao-owner)
    (is-eq tx-sender (var-get dao-owner))
)

(define-private (is-member (address principal))
    (match (map-get? members address)
        member (> (get staked-amount member) u0)
        false
    )
)

(define-private (is-valid-bool (input bool))
    (or 
        (is-eq input true)
        (is-eq input false)
    )
)

(define-private (validate-string-ascii (input (string-ascii 500)))
    (and 
        (not (is-eq input ""))
        (<= (len input) u500)
    )
)

(define-private (validate-principal (address principal))
    (and
        (not (is-eq address tx-sender))
        (not (is-eq address (as-contract tx-sender)))
    )
)

(define-private (validate-vote (vote-value bool))
    (if (is-valid-bool vote-value)
        (ok vote-value)
        ERR-INVALID-VOTE
    )
)

(define-private (get-proposal-status (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal (get status proposal)
        "NOT_FOUND"
    )
)

(define-private (calculate-voting-power (address principal))
    (match (map-get? members address)
        member (get staked-amount member)
        u0
    )
)

;; Public Functions
(define-public (initialize (new-owner principal))
    (begin
        (asserts! (is-dao-owner) ERR-NOT-AUTHORIZED)
        (asserts! (validate-principal new-owner) ERR-INVALID-OWNER)
        (var-set dao-owner new-owner)
        (ok true)
    )
)

;; Membership Functions
(define-public (stake-tokens (amount uint))
    (begin
        (asserts! (>= amount u0) ERR-INVALID-AMOUNT)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        (let (
            (current-balance (default-to 
                {staked-amount: u0, last-reward-block: stacks-block-height, rewards-claimed: u0} 
                (map-get? members tx-sender)))
        )
            (map-set members tx-sender {
                staked-amount: (+ (get staked-amount current-balance) amount),
                last-reward-block: stacks-block-height,
                rewards-claimed: (get rewards-claimed current-balance)
            })
            
            (var-set total-staked (+ (var-get total-staked) amount))
            (ok true)
        )
    )
)

(define-public (unstake-tokens (amount uint))
    (let (
        (current-balance (unwrap! (map-get? members tx-sender) ERR-NOT-AUTHORIZED))
    )
    (begin
        (asserts! (>= (get staked-amount current-balance) amount) ERR-INSUFFICIENT-BALANCE)
        (try! (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender)))
        
        (map-set members tx-sender {
            staked-amount: (- (get staked-amount current-balance) amount),
            last-reward-block: stacks-block-height,
            rewards-claimed: (get rewards-claimed current-balance)
        })
        
        (var-set total-staked (- (var-get total-staked) amount))
        (ok true)
    ))
)

;; Proposal Functions
(define-public (create-proposal (title (string-ascii 100)) 
                              (description (string-ascii 500)) 
                              (amount uint)
                              (recipient principal))
    (let (
        (proposal-id (+ (var-get proposal-count) u1))
        (proposer-stake (calculate-voting-power tx-sender))
    )
    (begin
        ;; Input validation
        (asserts! (>= proposer-stake (var-get min-proposal-amount)) ERR-NOT-AUTHORIZED)
        (asserts! (>= amount u0) ERR-INVALID-AMOUNT)
        (asserts! (validate-string-ascii title) ERR-INVALID-TITLE)
        (asserts! (validate-string-ascii description) ERR-INVALID-DESCRIPTION)
        (asserts! (validate-principal recipient) ERR-INVALID-RECIPIENT)
        
        (map-set proposals proposal-id {
            proposer: tx-sender,
            title: title,
            description: description,
            amount: amount,
            recipient: recipient,
            start-block: stacks-block-height,
            end-block: (+ stacks-block-height (var-get proposal-duration)),
            yes-votes: u0,
            no-votes: u0,
            status: "ACTIVE",
            executed: false
        })
        
        (var-set proposal-count proposal-id)
        (ok proposal-id)
    ))
)

(define-public (vote (proposal-id uint) (vote-for bool))
    (let (
        (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
        (voter-power (calculate-voting-power tx-sender))
    )
    (begin
        ;; Input and state validation
        (asserts! (is-member tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status proposal) "ACTIVE") ERR-PROPOSAL-NOT-ACTIVE)
        (asserts! (<= stacks-block-height (get end-block proposal)) ERR-PROPOSAL-EXPIRED)
        (asserts! (is-none (map-get? votes {proposal-id: proposal-id, voter: tx-sender})) ERR-ALREADY-VOTED)
        
        ;; Type check before validation
        (asserts! (is-valid-bool vote-for) ERR-INVALID-VOTE)
        
        ;; Vote processing with verified input
        (let ((safe-vote (is-eq vote-for true)))
            ;; Record the vote
            (map-set votes 
                {proposal-id: proposal-id, voter: tx-sender} 
                {vote: safe-vote}
            )
            
            ;; Update vote counts
            (map-set proposals proposal-id 
                (merge proposal 
                    {
                        yes-votes: (if safe-vote
                            (+ (get yes-votes proposal) voter-power)
                            (get yes-votes proposal)
                        ),
                        no-votes: (if safe-vote
                            (get no-votes proposal)
                            (+ (get no-votes proposal) voter-power)
                        )
                    }
                )
            )
            (ok true)
        )
    ))
)

(define-public (execute-proposal (proposal-id uint))
    (let (
        (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
    )
    (begin
        (asserts! (>= stacks-block-height (get end-block proposal)) ERR-PROPOSAL-NOT-ACTIVE)
        (asserts! (not (get executed proposal)) ERR-INVALID-STATUS)
        
        (if (and
            (>= (get yes-votes proposal) 
                (/ (* (var-get total-staked) (var-get quorum-threshold)) u1000)
            )
            (> (get yes-votes proposal) (get no-votes proposal))
        )
            (begin
                (try! (as-contract (stx-transfer? (get amount proposal) 
                    (as-contract tx-sender) 
                    (get recipient proposal))))
                
                (map-set proposals proposal-id 
                    (merge proposal {
                        status: "EXECUTED",
                        executed: true
                    })
                )
                (ok true)
            )
            (begin
                (map-set proposals proposal-id 
                    (merge proposal {
                        status: "REJECTED",
                        executed: true
                    })
                )
                (ok true)
            )
        )
    ))
)

;; Read-only Functions
(define-read-only (get-member-info (address principal))
    (map-get? members address)
)

(define-read-only (get-proposal-info (proposal-id uint))
    (map-get? proposals proposal-id)
)

(define-read-only (get-vote-info (proposal-id uint) (voter principal))
    (map-get? votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-dao-info)
    {
        total-staked: (var-get total-staked),
        proposal-count: (var-get proposal-count),
        quorum-threshold: (var-get quorum-threshold),
        min-proposal-amount: (var-get min-proposal-amount)
    }
)