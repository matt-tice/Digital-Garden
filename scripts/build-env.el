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

(defun my-generate-global-id-db ()
  "Scans the entire garden repository to generate the missing scripts/.org-id-locations file."
  (let ((notes-dir (expand-file-name "notes" default-directory)))
    (if (file-directory-p notes-dir)
        (let ((all-files (directory-files-recursively notes-dir "\\.org$")))
          (message "Scanning %d files to build global cross-reference matrix..." (length all-files))
          (setq org-id-locations nil) ; Clear any old state
          (org-id-update-id-locations all-files)
          (org-id-locations-save)
          (message "[SUCCESS] Generated %s containing all cross-links." org-id-locations-file))
      (error "Critical Error: 'notes' directory not found inside execution context."))))

;; --- 3. Parsing & Redaction Filters ---
(defun my/org-export-private-to-stub (text backend info)
  "A robust filter to turn private links into stubs."
  (when (org-export-derived-backend-p backend 'org) ; In this part of the program, we're creating a tmp org file
    (let* ((case-fold-search t)
           (private-regex "\\[\\(.*?\\)\\].*/private/\\(.*?\\)\\.\\(org\\|html\\|md\\)"))
      (if (string-match private-regex text)
          (let ((link-text (match-string 1 text)))
            (format "**%s** [?? Note currently private]" link-text))
        text))))

(defun my/org-export-sanitize-documents-path (text backend info)
  "Scrub the user's home directory from the final GitHub output."
  (when (org-export-derived-backend-p backend 'org)
    (let ((user-home (expand-file-name "~")))
      (replace-regexp-in-string (regexp-quote user-home) "[HOME]/" text))))

;; Turn org-roam links into regular org-links (which github can understand)
(defun my/org-export-resolve-org-ids (tree backend info)
  "Traverses the Org AST and mutates raw 'id:' link objects into standard relative 'file:' links."

  (when (org-export-derived-backend-p backend 'org)
  (org-element-map tree 'link
    (lambda (link)
      (let ((link-type (org-element-property :type link))
            (link-path (org-element-property :path link)))
        ;; Only target links that use the id protocol
        (when (string= link-type "id")
          (let ((target-file (org-id-find-id-file link-path)))
	    (cond (target-file
		   (let ((normalized-target (expand-file-name target-file)))
		     (if (string-match "/private/" normalized-target)
			 (let* ((contents (org-element-contents link))
				(link-text (if (stringp (car contents))
					       (car contents)
					     (org-element-interpret-data contents)))
				(clean-text (if (or (null link-text) (string-empty-p link-text)) "Note" link-text))
				;; Generate a clean inline stub object
				(stub-text (format "%s [?? Note currently private]" clean-text))
				(stub-node (org-element-create 'bold nil stub-text)))
                           ;; Replace the link element entirely with a text stub node
                           (org-element-set-element link stub-node))
		       (let* (
			      (notes-root (expand-file-name "../../notes" ))
			      (rel-path-from-notes (file-relative-name normalized-target notes-root))
			      (base-path (file-name-sans-extension rel-path-from-notes))
			      (html-path (concat "/Digital-Garden/" base-path ".html"))
			      (new-link (org-element-create 'link
							    (list :type "https"
								  :path html-path
								  :raw-link html-path
								  :format (org-element-property :format link)))))
			 (org-element-set-contents new-link (org-element-contents link))
			 (org-element-set-element link new-link)))))
		  (t
		   (message "[WARNING] Broken org-id link found in file: %s (Target ID: %s)" (buffer-file-name) link-path)
		   (org-element-put-property link :type "customid")
		   (org-element-put-property link :path "broken-link"))
		  )
	    ))))))
;; Since you're modifying the AST, you need to return the whole tree at the end
  tree)

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
	     '(my/org-export-resolve-org-ids))
            (org-export-filter-final-output-functions
	     '(my/org-export-private-to-stub
	       my/org-export-sanitize-documents-path
	       ))
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
