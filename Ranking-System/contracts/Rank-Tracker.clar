;; Comprehensive Leaderboard Smart Contract
;; Features: Multiple leaderboards, admin controls, scoring system, rewards
;; Improved version with enhanced input validation

;; ===== CONSTANTS =====
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-score (err u103))
(define-constant err-leaderboard-not-found (err u104))
(define-constant err-insufficient-funds (err u105))
(define-constant err-invalid-participant (err u106))
(define-constant err-leaderboard-inactive (err u107))
(define-constant err-invalid-parameters (err u108))
(define-constant err-reward-not-available (err u109))
(define-constant err-invalid-principal (err u110))

;; Maximum entries per leaderboard
(define-constant max-leaderboard-entries u1000)

;; ===== DATA VARIABLES =====
;; Global contract settings
(define-data-var contract-active bool true)
(define-data-var next-leaderboard-id uint u1)
(define-data-var total-leaderboards uint u0)

;; ===== DATA MAPS =====
;; Leaderboard metadata
(define-map leaderboards 
    { leaderboard-id: uint }
    {
        name: (string-ascii 64),
        description: (string-ascii 256),
        owner: principal,
        active: bool,
        max-participants: uint,
        current-participants: uint,
        reward-pool: uint,
        created-at: uint,
        end-time: (optional uint)
    }
)

;; Individual scores within leaderboards
(define-map leaderboard-scores
    { leaderboard-id: uint, participant: principal }
    {
        score: uint,
        rank: uint,
        last-updated: uint,
        games-played: uint
    }
)

;; Top performers for efficient querying
(define-map leaderboard-rankings
    { leaderboard-id: uint, rank: uint }
    {
        participant: principal,
        score: uint
    }
)

;; Admin permissions
(define-map admins
    { admin: principal }
    { authorized: bool }
)

;; Participant statistics across all leaderboards
(define-map participant-stats
    { participant: principal }
    {
        total-games: uint,
        total-score: uint,
        leaderboards-joined: uint,
        rewards-earned: uint
    }
)

;; Reward distribution tracking
(define-map reward-claims
    { leaderboard-id: uint, participant: principal }
    { claimed: bool, amount: uint }
)

;; ===== VALIDATION FUNCTIONS =====
(define-private (is-valid-principal (user principal))
    ;; Check if principal is not contract address and not empty
    (and 
        (not (is-eq user (as-contract tx-sender)))
        (not (is-eq user 'SP000000000000000000002Q6VF78)) ;; Null principal check
    )
)

(define-private (is-valid-string (input (string-ascii 64)))
    (and (> (len input) u0) (<= (len input) u64))
)

(define-private (is-valid-description (input (string-ascii 256)))
    (and (> (len input) u0) (<= (len input) u256))
)

(define-private (validate-leaderboard-id (leaderboard-id uint))
    (and (> leaderboard-id u0) (< leaderboard-id (var-get next-leaderboard-id)))
)

;; ===== AUTHORIZATION FUNCTIONS =====
(define-private (is-contract-owner)
    (is-eq tx-sender contract-owner)
)

(define-private (is-admin (user principal))
    (default-to false (get authorized (map-get? admins { admin: user })))
)

(define-private (is-authorized (user principal))
    (or (is-contract-owner) (is-admin user))
)

;; ===== ADMIN FUNCTIONS =====
;; Add admin with enhanced validation
(define-public (add-admin (new-admin principal))
    (begin
        (asserts! (is-contract-owner) err-owner-only)
        (asserts! (is-valid-principal new-admin) err-invalid-principal)
        (asserts! (not (is-admin new-admin)) err-already-exists)
        (ok (map-set admins { admin: new-admin } { authorized: true }))
    )
)

;; Remove admin with enhanced validation
(define-public (remove-admin (admin-to-remove principal))
    (begin
        (asserts! (is-contract-owner) err-owner-only)
        (asserts! (is-valid-principal admin-to-remove) err-invalid-principal)
        (asserts! (is-admin admin-to-remove) err-not-found)
        (asserts! (not (is-eq admin-to-remove contract-owner)) err-invalid-parameters)
        (ok (map-delete admins { admin: admin-to-remove }))
    )
)

;; Toggle contract active status
(define-public (set-contract-status (active bool))
    (begin
        (asserts! (is-contract-owner) err-owner-only)
        (ok (var-set contract-active active))
    )
)

;; ===== LEADERBOARD MANAGEMENT =====
;; Create new leaderboard with enhanced validation
(define-public (create-leaderboard 
    (name (string-ascii 64))
    (description (string-ascii 256))
    (max-participants uint)
    (end-time (optional uint))
)
    (let
        (
            (leaderboard-id (var-get next-leaderboard-id))
            (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
        )
        (asserts! (var-get contract-active) err-leaderboard-inactive)
        (asserts! (is-valid-string name) err-invalid-parameters)
        (asserts! (is-valid-description description) err-invalid-parameters)
        (asserts! (and (> max-participants u0) (<= max-participants max-leaderboard-entries)) err-invalid-parameters)
        
        ;; Validate end-time if provided
        (if (is-some end-time)
            (asserts! (> (unwrap-panic end-time) current-time) err-invalid-parameters)
            true
        )
        
        (map-set leaderboards 
            { leaderboard-id: leaderboard-id }
            {
                name: name,
                description: description,
                owner: tx-sender,
                active: true,
                max-participants: max-participants,
                current-participants: u0,
                reward-pool: u0,
                created-at: current-time,
                end-time: end-time
            }
        )
        
        (var-set next-leaderboard-id (+ leaderboard-id u1))
        (var-set total-leaderboards (+ (var-get total-leaderboards) u1))
        (ok leaderboard-id)
    )
)

;; Update leaderboard settings with enhanced validation
(define-public (update-leaderboard
    (leaderboard-id uint)
    (name (string-ascii 64))
    (description (string-ascii 256))
    (active bool)
)
    (let
        (
            (leaderboard (unwrap! (map-get? leaderboards { leaderboard-id: leaderboard-id }) err-leaderboard-not-found))
        )
        (asserts! (validate-leaderboard-id leaderboard-id) err-invalid-parameters)
        (asserts! (or (is-eq tx-sender (get owner leaderboard)) (is-authorized tx-sender)) err-owner-only)
        (asserts! (is-valid-string name) err-invalid-parameters)
        (asserts! (is-valid-description description) err-invalid-parameters)
        
        (ok (map-set leaderboards 
            { leaderboard-id: leaderboard-id }
            (merge leaderboard {
                name: name,
                description: description,
                active: active
            })
        ))
    )
)

;; Add funds to reward pool with enhanced validation
(define-public (add-reward-pool (leaderboard-id uint) (amount uint))
    (let
        (
            (leaderboard (unwrap! (map-get? leaderboards { leaderboard-id: leaderboard-id }) err-leaderboard-not-found))
        )
        (asserts! (validate-leaderboard-id leaderboard-id) err-invalid-parameters)
        (asserts! (> amount u0) err-invalid-parameters)
        (asserts! (get active leaderboard) err-leaderboard-inactive)
        
        ;; Transfer STX to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        (ok (map-set leaderboards 
            { leaderboard-id: leaderboard-id }
            (merge leaderboard {
                reward-pool: (+ (get reward-pool leaderboard) amount)
            })
        ))
    )
)

;; ===== SCORING FUNCTIONS =====
;; Submit score to leaderboard with enhanced validation
(define-public (submit-score (leaderboard-id uint) (score uint))
    (let
        (
            (leaderboard (unwrap! (map-get? leaderboards { leaderboard-id: leaderboard-id }) err-leaderboard-not-found))
            (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
            (existing-score (map-get? leaderboard-scores { leaderboard-id: leaderboard-id, participant: tx-sender }))
            (participant-stat (default-to 
                { total-games: u0, total-score: u0, leaderboards-joined: u0, rewards-earned: u0 }
                (map-get? participant-stats { participant: tx-sender })
            ))
        )
        
        ;; Enhanced validation checks
        (asserts! (validate-leaderboard-id leaderboard-id) err-invalid-parameters)
        (asserts! (var-get contract-active) err-leaderboard-inactive)
        (asserts! (get active leaderboard) err-leaderboard-inactive)
        (asserts! (> score u0) err-invalid-score)
        
        ;; Check if leaderboard has ended
        (if (is-some (get end-time leaderboard))
            (asserts! (< current-time (unwrap-panic (get end-time leaderboard))) err-leaderboard-inactive)
            true
        )
        
        ;; Check participant limit
        (asserts! 
            (or 
                (is-some existing-score)
                (< (get current-participants leaderboard) (get max-participants leaderboard))
            ) 
            err-invalid-participant
        )
        
        ;; Update or create score entry
        (if (is-some existing-score)
            (let ((some-existing (unwrap-panic existing-score)))
                ;; Update existing score if new score is better
                (if (> score (get score some-existing))
                    (map-set leaderboard-scores
                        { leaderboard-id: leaderboard-id, participant: tx-sender }
                        {
                            score: score,
                            rank: u0, ;; Will be recalculated
                            last-updated: current-time,
                            games-played: (+ (get games-played some-existing) u1)
                        }
                    )
                    (map-set leaderboard-scores
                        { leaderboard-id: leaderboard-id, participant: tx-sender }
                        (merge some-existing {
                            last-updated: current-time,
                            games-played: (+ (get games-played some-existing) u1)
                        })
                    )
                )
            )
            (begin
                ;; Create new score entry
                (map-set leaderboard-scores
                    { leaderboard-id: leaderboard-id, participant: tx-sender }
                    {
                        score: score,
                        rank: u0, ;; Will be recalculated
                        last-updated: current-time,
                        games-played: u1
                    }
                )
                ;; Update leaderboard participant count
                (map-set leaderboards 
                    { leaderboard-id: leaderboard-id }
                    (merge leaderboard {
                        current-participants: (+ (get current-participants leaderboard) u1)
                    })
                )
            )
        )
        
        ;; Update participant statistics
        (map-set participant-stats 
            { participant: tx-sender }
            {
                total-games: (+ (get total-games participant-stat) u1),
                total-score: (+ (get total-score participant-stat) score),
                leaderboards-joined: (if (is-none existing-score) 
                    (+ (get leaderboards-joined participant-stat) u1)
                    (get leaderboards-joined participant-stat)
                ),
                rewards-earned: (get rewards-earned participant-stat)
            }
        )
        
        (ok true)
    )
)

;; ===== REWARD FUNCTIONS =====
;; Claim rewards with enhanced validation
(define-public (claim-reward (leaderboard-id uint))
    (let
        (
            (leaderboard (unwrap! (map-get? leaderboards { leaderboard-id: leaderboard-id }) err-leaderboard-not-found))
            (participant-score (unwrap! (map-get? leaderboard-scores { leaderboard-id: leaderboard-id, participant: tx-sender }) err-not-found))
            (reward-claim (map-get? reward-claims { leaderboard-id: leaderboard-id, participant: tx-sender }))
            (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
        )
        
        ;; Enhanced validation
        (asserts! (validate-leaderboard-id leaderboard-id) err-invalid-parameters)
        
        ;; Check if already claimed
        (if (is-some reward-claim)
            (asserts! (not (get claimed (unwrap-panic reward-claim))) err-reward-not-available)
            true
        )
        
        ;; Check if leaderboard has ended (if end-time is set)
        (if (is-some (get end-time leaderboard))
            (asserts! (>= current-time (unwrap-panic (get end-time leaderboard))) err-leaderboard-inactive)
            true
        )
        
        ;; Calculate reward based on rank (top 3 get rewards)
        (let
            (
                (participant-rank (get rank participant-score))
                (total-pool (get reward-pool leaderboard))
                (reward-amount 
                    (if (is-eq participant-rank u1)
                        (/ (* total-pool u50) u100) ;; 50% for 1st place
                        (if (is-eq participant-rank u2)
                            (/ (* total-pool u30) u100) ;; 30% for 2nd place
                            (if (is-eq participant-rank u3)
                                (/ (* total-pool u20) u100) ;; 20% for 3rd place
                                u0
                            )
                        )
                    )
                )
            )
            
            (asserts! (> reward-amount u0) err-reward-not-available)
            (asserts! (>= total-pool reward-amount) err-insufficient-funds)
            
            ;; Transfer reward
            (try! (as-contract (stx-transfer? reward-amount tx-sender tx-sender)))
            
            ;; Mark as claimed
            (map-set reward-claims
                { leaderboard-id: leaderboard-id, participant: tx-sender }
                { claimed: true, amount: reward-amount }
            )
            
            ;; Update participant stats
            (let
                (
                    (participant-stat (unwrap-panic (map-get? participant-stats { participant: tx-sender })))
                )
                (map-set participant-stats 
                    { participant: tx-sender }
                    (merge participant-stat {
                        rewards-earned: (+ (get rewards-earned participant-stat) reward-amount)
                    })
                )
            )
            
            ;; Update leaderboard reward pool
            (map-set leaderboards 
                { leaderboard-id: leaderboard-id }
                (merge leaderboard {
                    reward-pool: (- total-pool reward-amount)
                })
            )
            
            (ok reward-amount)
        )
    )
)

;; ===== READ-ONLY FUNCTIONS =====
;; Get leaderboard details with validation
(define-read-only (get-leaderboard (leaderboard-id uint))
    (if (validate-leaderboard-id leaderboard-id)
        (map-get? leaderboards { leaderboard-id: leaderboard-id })
        none
    )
)

;; Get participant score in a leaderboard with validation
(define-read-only (get-participant-score (leaderboard-id uint) (participant principal))
    (if (and (validate-leaderboard-id leaderboard-id) (is-valid-principal participant))
        (map-get? leaderboard-scores { leaderboard-id: leaderboard-id, participant: participant })
        none
    )
)

;; Get participant statistics with validation
(define-read-only (get-participant-stats (participant principal))
    (if (is-valid-principal participant)
        (map-get? participant-stats { participant: participant })
        none
    )
)

;; Get leaderboard ranking at specific position with validation
(define-read-only (get-ranking-at-position (leaderboard-id uint) (rank uint))
    (if (and (validate-leaderboard-id leaderboard-id) (> rank u0))
        (map-get? leaderboard-rankings { leaderboard-id: leaderboard-id, rank: rank })
        none
    )
)

;; Check if user is admin with validation
(define-read-only (is-user-admin (user principal))
    (if (is-valid-principal user)
        (is-admin user)
        false
    )
)

;; Get contract status
(define-read-only (get-contract-status)
    {
        active: (var-get contract-active),
        total-leaderboards: (var-get total-leaderboards),
        next-leaderboard-id: (var-get next-leaderboard-id),
        owner: contract-owner
    }
)

;; Get reward claim status with validation
(define-read-only (get-reward-claim-status (leaderboard-id uint) (participant principal))
    (if (and (validate-leaderboard-id leaderboard-id) (is-valid-principal participant))
        (map-get? reward-claims { leaderboard-id: leaderboard-id, participant: participant })
        none
    )
)

;; Calculate potential reward for a participant with enhanced validation
(define-read-only (calculate-potential-reward (leaderboard-id uint) (participant principal))
    (if (not (and (validate-leaderboard-id leaderboard-id) (is-valid-principal participant)))
        (err err-invalid-parameters)
        (let
            (
                (leaderboard (unwrap! (map-get? leaderboards { leaderboard-id: leaderboard-id }) (err err-leaderboard-not-found)))
                (participant-score (unwrap! (map-get? leaderboard-scores { leaderboard-id: leaderboard-id, participant: participant }) (err err-not-found)))
                (participant-rank (get rank participant-score))
                (total-pool (get reward-pool leaderboard))
            )
            (ok 
                (if (is-eq participant-rank u1)
                    (/ (* total-pool u50) u100)
                    (if (is-eq participant-rank u2)
                        (/ (* total-pool u30) u100)
                        (if (is-eq participant-rank u3)
                            (/ (* total-pool u20) u100)
                            u0
                        )
                    )
                )
            )
        )
    )
)

;; Helper function to check if leaderboard is active and not expired with validation
(define-read-only (is-leaderboard-active (leaderboard-id uint))
    (if (not (validate-leaderboard-id leaderboard-id))
        false
        (match (get-leaderboard leaderboard-id)
            some-leaderboard 
                (let
                    (
                        (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
                    )
                    (and 
                        (get active some-leaderboard)
                        (if (is-some (get end-time some-leaderboard))
                            (< current-time (unwrap-panic (get end-time some-leaderboard)))
                            true
                        )
                    )
                )
            false
        )
    )
)