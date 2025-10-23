;; title: Scholar
;; version: 1.0.0
;; summary: On-Chain Scholarship Disbursement System
;; description: Automatically distributes scholarship funds to students upon meeting academic requirements

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-REQUIREMENTS-NOT-MET (err u104))
(define-constant ERR-ALREADY-DISBURSED (err u105))
(define-constant ERR-INACTIVE-SCHOLARSHIP (err u106))
(define-constant ERR-INVALID-AMOUNT (err u107))
(define-constant ERR-UNAUTHORIZED (err u108))
(define-constant ERR-MILESTONE-NOT-FOUND (err u109))
(define-constant ERR-MILESTONE-ALREADY-CLAIMED (err u110))
(define-constant ERR-NO-MILESTONES (err u111))

(define-data-var contract-balance uint u0)
(define-data-var next-scholarship-id uint u1)
(define-data-var next-student-id uint u1)

(define-map scholarships
  { scholarship-id: uint }
  {
    name: (string-ascii 64),
    amount: uint,
    gpa-requirement: uint,
    credit-hours-requirement: uint,
    deadline-block: uint,
    admin: principal,
    active: bool,
    total-allocated: uint,
    recipients-count: uint
  })

(define-map students
  { student-id: uint }
  {
    wallet: principal,
    name: (string-ascii 64),
    institution: (string-ascii 64),
    current-gpa: uint,
    completed-credit-hours: uint,
    enrollment-block: uint,
    verified: bool
  })

(define-map student-scholarships
  { student-id: uint, scholarship-id: uint }
  {
    applied-block: uint,
    disbursed: bool,
    disbursement-block: (optional uint),
    amount-received: uint,
    requirements-met: bool
  })

(define-map student-wallet-to-id
  { wallet: principal }
  { student-id: uint })

(define-map scholarship-admins
  { admin: principal, scholarship-id: uint }
  { authorized: bool })

(define-map scholarship-milestones
  { scholarship-id: uint, milestone-index: uint }
  {
    gpa-requirement: uint,
    credit-hours-requirement: uint,
    payout-percentage: uint,
    description: (string-ascii 128),
    active: bool
  })

(define-map student-milestone-claims
  { student-id: uint, scholarship-id: uint, milestone-index: uint }
  {
    claimed: bool,
    claim-block: (optional uint),
    amount-received: uint
  })

(define-map scholarship-milestone-count
  { scholarship-id: uint }
  { total-milestones: uint })

(define-public (create-scholarship (name (string-ascii 64)) (amount uint) (gpa-requirement uint) (credit-hours-requirement uint) (deadline-block uint))
  (let
    (
      (scholarship-id (var-get next-scholarship-id))
    )
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> deadline-block stacks-block-height) ERR-INVALID-AMOUNT)
    (map-set scholarships
      { scholarship-id: scholarship-id }
      {
        name: name,
        amount: amount,
        gpa-requirement: gpa-requirement,
        credit-hours-requirement: credit-hours-requirement,
        deadline-block: deadline-block,
        admin: tx-sender,
        active: true,
        total-allocated: u0,
        recipients-count: u0
      })
    (map-set scholarship-admins
      { admin: tx-sender, scholarship-id: scholarship-id }
      { authorized: true })
    (var-set next-scholarship-id (+ scholarship-id u1))
    (ok scholarship-id)))

(define-public (register-student (name (string-ascii 64)) (institution (string-ascii 64)))
  (let
    (
      (student-id (var-get next-student-id))
      (existing-student (map-get? student-wallet-to-id { wallet: tx-sender }))
    )
    (asserts! (is-none existing-student) ERR-ALREADY-EXISTS)
    (map-set students
      { student-id: student-id }
      {
        wallet: tx-sender,
        name: name,
        institution: institution,
        current-gpa: u0,
        completed-credit-hours: u0,
        enrollment-block: stacks-block-height,
        verified: false
      })
    (map-set student-wallet-to-id
      { wallet: tx-sender }
      { student-id: student-id })
    (var-set next-student-id (+ student-id u1))
    (ok student-id)))

(define-public (update-academic-record (student-id uint) (gpa uint) (credit-hours uint))
  (let
    (
      (student (unwrap! (map-get? students { student-id: student-id }) ERR-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender (get wallet student)) (is-eq tx-sender CONTRACT-OWNER)) ERR-UNAUTHORIZED)
    (map-set students
      { student-id: student-id }
      (merge student { current-gpa: gpa, completed-credit-hours: credit-hours }))
    (ok true)))

(define-public (verify-student (student-id uint))
  (let
    (
      (student (unwrap! (map-get? students { student-id: student-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (map-set students
      { student-id: student-id }
      (merge student { verified: true }))
    (ok true)))

(define-public (apply-for-scholarship (student-id uint) (scholarship-id uint))
  (let
    (
      (student (unwrap! (map-get? students { student-id: student-id }) ERR-NOT-FOUND))
      (scholarship (unwrap! (map-get? scholarships { scholarship-id: scholarship-id }) ERR-NOT-FOUND))
      (existing-application (map-get? student-scholarships { student-id: student-id, scholarship-id: scholarship-id }))
    )
    (asserts! (is-eq tx-sender (get wallet student)) ERR-UNAUTHORIZED)
    (asserts! (get active scholarship) ERR-INACTIVE-SCHOLARSHIP)
    (asserts! (< stacks-block-height (get deadline-block scholarship)) ERR-INACTIVE-SCHOLARSHIP)
    (asserts! (is-none existing-application) ERR-ALREADY-EXISTS)
    (asserts! (get verified student) ERR-UNAUTHORIZED)
    (map-set student-scholarships
      { student-id: student-id, scholarship-id: scholarship-id }
      {
        applied-block: stacks-block-height,
        disbursed: false,
        disbursement-block: none,
        amount-received: u0,
        requirements-met: false
      })
    (ok true)))

(define-public (check-and-disburse (student-id uint) (scholarship-id uint))
  (let
    (
      (student (unwrap! (map-get? students { student-id: student-id }) ERR-NOT-FOUND))
      (scholarship (unwrap! (map-get? scholarships { scholarship-id: scholarship-id }) ERR-NOT-FOUND))
      (application (unwrap! (map-get? student-scholarships { student-id: student-id, scholarship-id: scholarship-id }) ERR-NOT-FOUND))
    )
    (asserts! (get active scholarship) ERR-INACTIVE-SCHOLARSHIP)
    (asserts! (not (get disbursed application)) ERR-ALREADY-DISBURSED)
    (asserts! (>= (get current-gpa student) (get gpa-requirement scholarship)) ERR-REQUIREMENTS-NOT-MET)
    (asserts! (>= (get completed-credit-hours student) (get credit-hours-requirement scholarship)) ERR-REQUIREMENTS-NOT-MET)
    (asserts! (>= (var-get contract-balance) (get amount scholarship)) ERR-INSUFFICIENT-FUNDS)
    (try! (stx-transfer? (get amount scholarship) (as-contract tx-sender) (get wallet student)))
    (var-set contract-balance (- (var-get contract-balance) (get amount scholarship)))
    (map-set student-scholarships
      { student-id: student-id, scholarship-id: scholarship-id }
      (merge application {
        disbursed: true,
        disbursement-block: (some stacks-block-height),
        amount-received: (get amount scholarship),
        requirements-met: true
      }))
    (map-set scholarships
      { scholarship-id: scholarship-id }
      (merge scholarship {
        total-allocated: (+ (get total-allocated scholarship) (get amount scholarship)),
        recipients-count: (+ (get recipients-count scholarship) u1)
      }))
    (ok true)))

(define-public (fund-contract)
  (let
    (
      (amount (stx-get-balance tx-sender))
    )
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set contract-balance (+ (var-get contract-balance) amount))
    (ok amount)))

(define-public (withdraw-funds (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (>= (var-get contract-balance) amount) ERR-INSUFFICIENT-FUNDS)
    (try! (as-contract (stx-transfer? amount tx-sender CONTRACT-OWNER)))
    (var-set contract-balance (- (var-get contract-balance) amount))
    (ok amount)))

(define-public (deactivate-scholarship (scholarship-id uint))
  (let
    (
      (scholarship (unwrap! (map-get? scholarships { scholarship-id: scholarship-id }) ERR-NOT-FOUND))
      (is-admin (default-to false (get authorized (map-get? scholarship-admins { admin: tx-sender, scholarship-id: scholarship-id }))))
    )
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (and is-admin (is-eq tx-sender (get admin scholarship)))) ERR-UNAUTHORIZED)
    (map-set scholarships
      { scholarship-id: scholarship-id }
      (merge scholarship { active: false }))
    (ok true)))

(define-public (add-scholarship-admin (scholarship-id uint) (new-admin principal))
  (let
    (
      (scholarship (unwrap! (map-get? scholarships { scholarship-id: scholarship-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get admin scholarship)) ERR-UNAUTHORIZED)
    (map-set scholarship-admins
      { admin: new-admin, scholarship-id: scholarship-id }
      { authorized: true })
    (ok true)))

(define-read-only (get-scholarship (scholarship-id uint))
  (map-get? scholarships { scholarship-id: scholarship-id }))

(define-read-only (get-student (student-id uint))
  (map-get? students { student-id: student-id }))

(define-read-only (get-student-by-wallet (wallet principal))
  (match (map-get? student-wallet-to-id { wallet: wallet })
    student-mapping (map-get? students { student-id: (get student-id student-mapping) })
    none))

(define-read-only (get-application (student-id uint) (scholarship-id uint))
  (map-get? student-scholarships { student-id: student-id, scholarship-id: scholarship-id }))

(define-read-only (get-contract-balance)
  (var-get contract-balance))

(define-read-only (get-next-scholarship-id)
  (var-get next-scholarship-id))

(define-read-only (get-next-student-id)
  (var-get next-student-id))

(define-read-only (check-eligibility (student-id uint) (scholarship-id uint))
  (match (map-get? students { student-id: student-id })
    student (match (map-get? scholarships { scholarship-id: scholarship-id })
      scholarship (ok {
        meets-gpa: (>= (get current-gpa student) (get gpa-requirement scholarship)),
        meets-credit-hours: (>= (get completed-credit-hours student) (get credit-hours-requirement scholarship)),
        is-verified: (get verified student),
        scholarship-active: (get active scholarship),
        before-deadline: (< stacks-block-height (get deadline-block scholarship))
      })
      ERR-NOT-FOUND)
    ERR-NOT-FOUND))

(define-read-only (is-scholarship-admin (admin principal) (scholarship-id uint))
  (default-to false (get authorized (map-get? scholarship-admins { admin: admin, scholarship-id: scholarship-id }))))

(define-public (add-scholarship-milestone (scholarship-id uint) (milestone-index uint) (gpa-requirement uint) (credit-hours-requirement uint) (payout-percentage uint) (description (string-ascii 128)))
  (let
    (
      (scholarship (unwrap! (map-get? scholarships { scholarship-id: scholarship-id }) ERR-NOT-FOUND))
      (is-admin (default-to false (get authorized (map-get? scholarship-admins { admin: tx-sender, scholarship-id: scholarship-id }))))
      (current-count (default-to { total-milestones: u0 } (map-get? scholarship-milestone-count { scholarship-id: scholarship-id })))
    )
    (asserts! (or (is-eq tx-sender (get admin scholarship)) is-admin) ERR-UNAUTHORIZED)
    (asserts! (<= payout-percentage u100) ERR-INVALID-AMOUNT)
    (map-set scholarship-milestones
      { scholarship-id: scholarship-id, milestone-index: milestone-index }
      {
        gpa-requirement: gpa-requirement,
        credit-hours-requirement: credit-hours-requirement,
        payout-percentage: payout-percentage,
        description: description,
        active: true
      })
    (map-set scholarship-milestone-count
      { scholarship-id: scholarship-id }
      { total-milestones: (if (> milestone-index (get total-milestones current-count)) milestone-index (get total-milestones current-count)) })
    (ok true)))

(define-public (claim-milestone (student-id uint) (scholarship-id uint) (milestone-index uint))
  (let
    (
      (student (unwrap! (map-get? students { student-id: student-id }) ERR-NOT-FOUND))
      (scholarship (unwrap! (map-get? scholarships { scholarship-id: scholarship-id }) ERR-NOT-FOUND))
      (milestone (unwrap! (map-get? scholarship-milestones { scholarship-id: scholarship-id, milestone-index: milestone-index }) ERR-MILESTONE-NOT-FOUND))
      (application (unwrap! (map-get? student-scholarships { student-id: student-id, scholarship-id: scholarship-id }) ERR-NOT-FOUND))
      (existing-claim (map-get? student-milestone-claims { student-id: student-id, scholarship-id: scholarship-id, milestone-index: milestone-index }))
      (payout-amount (/ (* (get amount scholarship) (get payout-percentage milestone)) u100))
    )
    (asserts! (is-eq tx-sender (get wallet student)) ERR-UNAUTHORIZED)
    (asserts! (get active scholarship) ERR-INACTIVE-SCHOLARSHIP)
    (asserts! (get active milestone) ERR-MILESTONE-NOT-FOUND)
    (asserts! (is-none existing-claim) ERR-MILESTONE-ALREADY-CLAIMED)
    (asserts! (>= (get current-gpa student) (get gpa-requirement milestone)) ERR-REQUIREMENTS-NOT-MET)
    (asserts! (>= (get completed-credit-hours student) (get credit-hours-requirement milestone)) ERR-REQUIREMENTS-NOT-MET)
    (asserts! (>= (var-get contract-balance) payout-amount) ERR-INSUFFICIENT-FUNDS)
    (try! (stx-transfer? payout-amount (as-contract tx-sender) (get wallet student)))
    (var-set contract-balance (- (var-get contract-balance) payout-amount))
    (map-set student-milestone-claims
      { student-id: student-id, scholarship-id: scholarship-id, milestone-index: milestone-index }
      {
        claimed: true,
        claim-block: (some stacks-block-height),
        amount-received: payout-amount
      })
    (map-set scholarships
      { scholarship-id: scholarship-id }
      (merge scholarship {
        total-allocated: (+ (get total-allocated scholarship) payout-amount)
      }))
    (ok payout-amount)))

(define-read-only (get-milestone (scholarship-id uint) (milestone-index uint))
  (map-get? scholarship-milestones { scholarship-id: scholarship-id, milestone-index: milestone-index }))

(define-read-only (get-milestone-claim (student-id uint) (scholarship-id uint) (milestone-index uint))
  (map-get? student-milestone-claims { student-id: student-id, scholarship-id: scholarship-id, milestone-index: milestone-index }))

(define-read-only (get-milestone-count (scholarship-id uint))
  (default-to { total-milestones: u0 } (map-get? scholarship-milestone-count { scholarship-id: scholarship-id })))

(define-read-only (check-milestone-eligibility (student-id uint) (scholarship-id uint) (milestone-index uint))
  (match (map-get? students { student-id: student-id })
    student (match (map-get? scholarship-milestones { scholarship-id: scholarship-id, milestone-index: milestone-index })
      milestone (ok {
        meets-gpa: (>= (get current-gpa student) (get gpa-requirement milestone)),
        meets-credit-hours: (>= (get completed-credit-hours student) (get credit-hours-requirement milestone)),
        is-verified: (get verified student),
        milestone-active: (get active milestone),
        already-claimed: (is-some (map-get? student-milestone-claims { student-id: student-id, scholarship-id: scholarship-id, milestone-index: milestone-index }))
      })
      ERR-MILESTONE-NOT-FOUND)
    ERR-NOT-FOUND))
