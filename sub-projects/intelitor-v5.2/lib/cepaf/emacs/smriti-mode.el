;;; smriti-mode.el --- SMRITI Knowledge Management System for Emacs -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Indrajaal Systems
;; Author: Cybernetic Architect
;; Version: 1.0.0
;; Keywords: knowledge, zettelkasten, f#, cortex
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:
;;
;; SMRITI Mode provides Emacs integration with the F# SMRITI (Knowledge
;; Management System) from the Indrajaal project.
;;
;; STAMP Constraints:
;; - SC-SMRITI-001: SQLite is authoritative holon state
;; - SC-SMRITI-002: All operations via SMRITI CLI
;; - SC-SMRITI-003: AI extraction optional (OpenRouter)
;;
;; Features:
;; - Status dashboard buffer
;; - Search interface
;; - Ingest documents
;; - View/edit holons
;; - Orphan and stale detection

;;; Code:

(require 'compile)
(require 'ansi-color)

;;; ─────────────────────────────────────────────────────────────────────
;;; Configuration
;;; ─────────────────────────────────────────────────────────────────────

(defgroup smriti nil
  "SMRITI Knowledge Management System."
  :group 'tools
  :prefix "smriti-")

(defcustom smriti-project-root nil
  "Root directory of the Indrajaal project.
If nil, will try to detect from current buffer."
  :type '(choice (const nil) directory)
  :group 'smriti)

(defcustom smriti-cli-script "lib/cepaf/scripts/SmritiIngestorCLI.fsx"
  "Path to SMRITI CLI script relative to project root."
  :type 'string
  :group 'smriti)

(defcustom smriti-default-cluster "docs"
  "Default cluster for ingestion."
  :type 'string
  :group 'smriti)

(defcustom smriti-default-max-files 10
  "Default maximum files to ingest."
  :type 'integer
  :group 'smriti)

;;; ─────────────────────────────────────────────────────────────────────
;;; Utilities
;;; ─────────────────────────────────────────────────────────────────────

(defun smriti--project-root ()
  "Find SMRITI project root."
  (or smriti-project-root
      (locate-dominating-file default-directory "CLAUDE.md")
      (locate-dominating-file default-directory "lib/cepaf")))

(defun smriti--run-command (args &optional async)
  "Run SMRITI CLI with ARGS.
If ASYNC is non-nil, run asynchronously."
  (let* ((root (smriti--project-root))
         (default-directory root)
         (cmd (format "dotnet fsi %s %s" smriti-cli-script args)))
    (if async
        (async-shell-command cmd "*SMRITI*")
      (shell-command-to-string cmd))))

(defun smriti--with-ansi-colors (output)
  "Apply ANSI color codes to OUTPUT string."
  (ansi-color-apply output))

;;; ─────────────────────────────────────────────────────────────────────
;;; Interactive Commands
;;; ─────────────────────────────────────────────────────────────────────

;;;###autoload
(defun smriti-status ()
  "Show SMRITI database status."
  (interactive)
  (let ((buf (get-buffer-create "*SMRITI Status*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (smriti--with-ansi-colors (smriti--run-command "status")))
        (goto-char (point-min))))
    (display-buffer buf)))

;;;###autoload
(defun smriti-search (query)
  "Search holons for QUERY."
  (interactive "sSearch query: ")
  (let ((buf (get-buffer-create "*SMRITI Search*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "SMRITI Search: %s\n\n" query))
        (insert (smriti--with-ansi-colors
                 (smriti--run-command (format "search '%s'" query))))
        (goto-char (point-min))))
    (display-buffer buf)))

;;;###autoload
(defun smriti-ingest (path)
  "Ingest markdown files from PATH."
  (interactive "DDirectory to ingest: ")
  (let ((max-files (read-number "Max files: " smriti-default-max-files))
        (cluster (read-string "Cluster: " smriti-default-cluster)))
    (smriti--run-command
     (format "ingest '%s' --max %d --cluster %s" path max-files cluster)
     t)))

;;;###autoload
(defun smriti-ingest-buffer ()
  "Ingest current buffer's directory."
  (interactive)
  (when buffer-file-name
    (smriti-ingest (file-name-directory buffer-file-name))))

;;;###autoload
(defun smriti-orphans ()
  "Show orphan holons (no links)."
  (interactive)
  (let ((buf (get-buffer-create "*SMRITI Orphans*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "SMRITI Orphan Holons\n\n")
        (insert (smriti--with-ansi-colors (smriti--run-command "orphans")))
        (goto-char (point-min))))
    (display-buffer buf)))

;;;###autoload
(defun smriti-stale (&optional threshold)
  "Show stale holons with entropy >= THRESHOLD."
  (interactive "nEntropy threshold (0.0-1.0): ")
  (let* ((thresh (or threshold 0.6))
         (buf (get-buffer-create "*SMRITI Stale*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "SMRITI Stale Holons (entropy >= %.2f)\n\n" thresh))
        (insert (smriti--with-ansi-colors
                 (smriti--run-command (format "stale --threshold %.2f" thresh))))
        (goto-char (point-min))))
    (display-buffer buf)))

;;;###autoload
(defun smriti-entropy ()
  "Recalculate entropy for all holons."
  (interactive)
  (message "Recalculating entropy...")
  (let ((output (smriti--run-command "entropy")))
    (message "%s" (string-trim output))))

;;; ─────────────────────────────────────────────────────────────────────
;;; SMRITI Dashboard Mode
;;; ─────────────────────────────────────────────────────────────────────

(defvar smriti-dashboard-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "g" #'smriti-dashboard-refresh)
    (define-key map "s" #'smriti-search)
    (define-key map "i" #'smriti-ingest)
    (define-key map "o" #'smriti-orphans)
    (define-key map "t" #'smriti-stale)
    (define-key map "e" #'smriti-entropy)
    (define-key map "q" #'quit-window)
    map)
  "Keymap for `smriti-dashboard-mode'.")

(define-derived-mode smriti-dashboard-mode special-mode "SMRITI"
  "Major mode for SMRITI dashboard.

\{smriti-dashboard-mode-map}"
  :group 'smriti
  (setq-local revert-buffer-function #'smriti-dashboard-refresh))

(defun smriti-dashboard-refresh (&optional _ignore-auto _noconfirm)
  "Refresh SMRITI dashboard."
  (interactive)
  (let ((inhibit-read-only t))
    (erase-buffer)
    (insert "╔════════════════════════════════════════════════════════════╗\n")
    (insert "║          SMRITI - Knowledge Management System              ║\n")
    (insert "╠════════════════════════════════════════════════════════════╣\n")
    (insert "║  Keys: g=refresh s=search i=ingest o=orphans t=stale q=quit║\n")
    (insert "╚════════════════════════════════════════════════════════════╝\n\n")
    (insert (smriti--with-ansi-colors (smriti--run-command "status")))
    (goto-char (point-min))))

;;;###autoload
(defun smriti-dashboard ()
  "Open SMRITI dashboard."
  (interactive)
  (let ((buf (get-buffer-create "*SMRITI Dashboard*")))
    (with-current-buffer buf
      (smriti-dashboard-mode)
      (smriti-dashboard-refresh))
    (switch-to-buffer buf)))

;;; ─────────────────────────────────────────────────────────────────────
;;; Transient Menu (optional, if transient.el available)
;;; ─────────────────────────────────────────────────────────────────────

(when (require 'transient nil t)
  (transient-define-prefix smriti-menu ()
    "SMRITI Command Menu"
    ["SMRITI Commands"
     ("d" "Dashboard" smriti-dashboard)
     ("s" "Search" smriti-search)
     ("i" "Ingest Directory" smriti-ingest)
     ("b" "Ingest Buffer Dir" smriti-ingest-buffer)]
    ["Analysis"
     ("o" "Orphans" smriti-orphans)
     ("t" "Stale" smriti-stale)
     ("e" "Recalculate Entropy" smriti-entropy)]
    ["Info"
     ("?" "Status" smriti-status)]))

;;; ─────────────────────────────────────────────────────────────────────
;;; Global Key Bindings (optional)
;;; ─────────────────────────────────────────────────────────────────────

;;;###autoload
(defun smriti-setup-keybindings ()
  "Set up global keybindings for SMRITI."
  (interactive)
  (global-set-key (kbd "C-c s d") #'smriti-dashboard)
  (global-set-key (kbd "C-c s s") #'smriti-search)
  (global-set-key (kbd "C-c s i") #'smriti-ingest)
  (global-set-key (kbd "C-c s o") #'smriti-orphans)
  (global-set-key (kbd "C-c s t") #'smriti-stale)
  (global-set-key (kbd "C-c s e") #'smriti-entropy)
  (when (fboundp 'smriti-menu)
    (global-set-key (kbd "C-c s z") #'smriti-menu)))

;;; ─────────────────────────────────────────────────────────────────────
;;; Org-Mode Integration
;;; ─────────────────────────────────────────────────────────────────────

(defun smriti-org-link-handler (id)
  "Handle smriti: link for holon ID."
  (smriti-search id))

(with-eval-after-load 'org
  (org-link-set-parameters
   "smriti"
   :follow #'smriti-org-link-handler
   :export (lambda (id desc backend)
             (format "[[smriti:%s][%s]]" id (or desc id)))))

(provide 'smriti-mode)

;;; smriti-mode.el ends here