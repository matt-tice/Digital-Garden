;; scripts/build-env.el
;; Core Compilation Engine - Tracked publicly on GitHub

;; --- 1. Dynamic Local Environment Injection ---
(let ((local-config (expand-file-name "scripts/local-env.el" default-directory)))
  (when (file-exists-p local-config)
    (load local-config)))

;; --- 2. Package Manager Package Initialization Engine ---
(require 'package)
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("gnu"   . "https://elpa.gnu.org/packages/")))
(package-initialize)

(unless (and (package-installed-p 'org)
             (package-installed-p 'ox-pandoc))
  (package-refresh-contents))

(unless (package-installed-p 'org) (package-install 'org))
(unless (package-installed-p 'ox-pandoc) (package-install 'ox-pandoc))

(require 'ox-pandoc)

;; --- 3. Parsing & Redaction Filters ---
(defun my/org-export-private-to-stub (text backend info)
  "A robust filter to turn private links into stubs."
  (when (org-export-derived-backend-p backend 'gfm)
    (let* ((case-fold-search t)
           (private-regex "\\[\\(.*?\\)\\].*/private/\\(.*?\\)\\.\\(org\\|md\\)"))
      (if (string-match private-regex text)
          (let ((link-text (match-string 1 text)))
            (format "**%s** [?? Note currently private]" link-text))
        text))))

(defun my/org-export-sanitize-documents-path (text backend info)
  "Scrub the user's home directory from the final GitHub output."
  (when (org-export-derived-backend-p backend 'gfm)
    (let ((user-home (expand-file-name "~")))
      (replace-regexp-in-string (regexp-quote user-home) "[HOME]/" text))))

;; Turn org-roam links into regular org-links (which github can understand)
(defun my/org-export-resolve-org-ids (tree backend info)
  "Traverses the Org AST and mutates raw 'id:' link objects into standard relative 'file:' links."
  (org-element-map tree 'link
    (lambda (link)
      (let ((link-type (org-element-property :type link))
            (link-path (org-element-property :path link)))
        ;; Only target links that use the id protocol
        (when (string= link-type "id")
          (let ((target-file (org-id-find-id-file link-path)))
	    (cond (target-file
		   (let*
		       ((rel-path-from-root (file-relative-name target-file "notes"))
			(base-path (file-name-sans-extension rel-path-from-root))
			(html-path (concat "./" base-path ".html"))
			)
		     (org-element-put-property link :type "file")
		     (org-element-put-property link :path html-path)
		     tree)) 		;; Since you're modifying the AST, you need to return the whole tree at the end
		  (t
		   (message "[WARNING] Broken org-id link found in file: %s (Target ID: %s)" (buffer-file-name) link-path)
		   (org-element-put-property link :type "customid")
		   (org-element-put-property link :path "broken-link"))
		  tree)
	    ))))
  ;; Return the mutated tree back to the export pipeline
  tree))

;; --- 4. The Unified Cloud Export Driver ---
;; The original exporter turned things into markdown files, which was perfect for when we were just navigating in the repo
;; but now that we want to set up a github pages site, we'll need html files instead
(defun my-cloud-export (infile outfile)
  "Convert INFILE to OUTFILE via Pandoc."
  (let* ((abs-infile (expand-file-name infile))
         (abs-outfile (expand-file-name outfile))
         (dest-dir (file-name-directory abs-outfile))
         (temp-org (concat abs-outfile ".tmp.org")))
    
    (make-directory dest-dir t)

    (with-current-buffer (find-file-noselect abs-infile)
      (let ((org-export-filter-parse-tree-functions
	     '(my/org-export-private-to-stub
	       my/org-export-resolve-org-ids))
            (org-export-filter-final-output-functions '(my/org-export-sanitize-documents-path))
            (default-directory dest-dir))
        (org-export-to-file 'org temp-org nil nil nil nil nil))
      (kill-buffer))

    ;; (let* ((pandoc-cmd (format "pandoc -f org -t gfm -o %s %s" 
    (let* ((pandoc-cmd (format "pandoc -f org -t html5 -s -o %s %s"                                (shell-quote-argument abs-outfile)
			       (shell-quote-argument temp-org)))
           (exit-code (shell-command pandoc-cmd)))
      
      (if (file-exists-p temp-org) (delete-file temp-org))
      
      (if (zerop exit-code)
          (message "Successfully compiled: %s" abs-outfile)
        (error "Compilation Error: Pandoc execution returned failure status: %d" exit-code)))))
