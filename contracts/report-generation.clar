;; Report Generation Contract
;; Automates business report creation and management

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u300))
(define-constant err-not-found (err u301))
(define-constant err-already-exists (err u302))
(define-constant err-invalid-data (err u303))
(define-constant err-unauthorized (err u304))

;; Data Variables
(define-data-var next-report-id uint u1)
(define-data-var next-template-id uint u1)

;; Data Maps
(define-map report-templates
  { template-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    template-type: (string-ascii 20),
    parameters: (string-ascii 300),
    created-by: principal,
    created-at: uint,
    is-active: bool
  }
)

(define-map reports
  { report-id: uint }
  {
    template-id: uint,
    title: (string-ascii 100),
    generated-by: principal,
    generated-at: uint,
    status: (string-ascii 20),
    data-sources: (string-ascii 200),
    report-hash: (string-ascii 64),
    version: uint
  }
)

(define-map report-permissions
  { report-id: uint, user: principal }
  {
    permission-type: (string-ascii 20),
    granted-by: principal,
    granted-at: uint
  }
)

(define-map report-versions
  { report-id: uint, version: uint }
  {
    report-hash: (string-ascii 64),
    updated-by: principal,
    updated-at: uint,
    change-notes: (string-ascii 200)
  }
)

;; Read-only functions
(define-read-only (get-report-template (template-id uint))
  (map-get? report-templates { template-id: template-id })
)

(define-read-only (get-report (report-id uint))
  (map-get? reports { report-id: report-id })
)

(define-read-only (get-report-permission (report-id uint) (user principal))
  (map-get? report-permissions { report-id: report-id, user: user })
)

(define-read-only (get-report-version (report-id uint) (version uint))
  (map-get? report-versions { report-id: report-id, version: version })
)

(define-read-only (has-report-access (report-id uint) (user principal))
  (match (get-report-permission report-id user)
    permission true
    (match (get-report report-id)
      report (is-eq user (get generated-by report))
      false
    )
  )
)

(define-read-only (get-next-report-id)
  (var-get next-report-id)
)

(define-read-only (get-next-template-id)
  (var-get next-template-id)
)

;; Public functions
(define-public (create-report-template (name (string-ascii 50)) (description (string-ascii 200)) (template-type (string-ascii 20)) (parameters (string-ascii 300)))
  (let
    (
      (template-id (var-get next-template-id))
    )
    (map-set report-templates
      { template-id: template-id }
      {
        name: name,
        description: description,
        template-type: template-type,
        parameters: parameters,
        created-by: tx-sender,
        created-at: block-height,
        is-active: true
      }
    )

    (var-set next-template-id (+ template-id u1))
    (ok template-id)
  )
)

(define-public (generate-report (template-id uint) (title (string-ascii 100)) (data-sources (string-ascii 200)) (report-hash (string-ascii 64)))
  (let
    (
      (report-id (var-get next-report-id))
      (template (unwrap! (get-report-template template-id) err-not-found))
    )
    (asserts! (get is-active template) err-invalid-data)

    (map-set reports
      { report-id: report-id }
      {
        template-id: template-id,
        title: title,
        generated-by: tx-sender,
        generated-at: block-height,
        status: "generated",
        data-sources: data-sources,
        report-hash: report-hash,
        version: u1
      }
    )

    (map-set report-versions
      { report-id: report-id, version: u1 }
      {
        report-hash: report-hash,
        updated-by: tx-sender,
        updated-at: block-height,
        change-notes: "Initial report generation"
      }
    )

    (var-set next-report-id (+ report-id u1))
    (ok report-id)
  )
)

(define-public (update-report (report-id uint) (new-hash (string-ascii 64)) (change-notes (string-ascii 200)))
  (let
    (
      (report (unwrap! (get-report report-id) err-not-found))
      (new-version (+ (get version report) u1))
    )
    (asserts! (has-report-access report-id tx-sender) err-unauthorized)

    (map-set reports
      { report-id: report-id }
      (merge report {
        report-hash: new-hash,
        version: new-version
      })
    )

    (map-set report-versions
      { report-id: report-id, version: new-version }
      {
        report-hash: new-hash,
        updated-by: tx-sender,
        updated-at: block-height,
        change-notes: change-notes
      }
    )

    (ok new-version)
  )
)

(define-public (grant-report-access (report-id uint) (user principal) (permission-type (string-ascii 20)))
  (let
    (
      (report (unwrap! (get-report report-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get generated-by report)) err-unauthorized)

    (map-set report-permissions
      { report-id: report-id, user: user }
      {
        permission-type: permission-type,
        granted-by: tx-sender,
        granted-at: block-height
      }
    )

    (ok true)
  )
)

(define-public (update-report-status (report-id uint) (new-status (string-ascii 20)))
  (let
    (
      (report (unwrap! (get-report report-id) err-not-found))
    )
    (asserts! (has-report-access report-id tx-sender) err-unauthorized)

    (map-set reports
      { report-id: report-id }
      (merge report { status: new-status })
    )

    (ok true)
  )
)

(define-public (deactivate-template (template-id uint))
  (let
    (
      (template (unwrap! (get-report-template template-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get created-by template)) err-unauthorized)

    (map-set report-templates
      { template-id: template-id }
      (merge template { is-active: false })
    )

    (ok true)
  )
)
