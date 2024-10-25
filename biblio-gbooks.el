;;; biblio-gbooks.el --- Google Books backend for biblio.el -*- lexical-binding: t; -*-

;; Copyright (C) 2023 Joshua Rasband and contributors
;;
;; Author: Joshua Rasband and contributors
;; URL: http://github.com/jrasband/biblio-gbooks
;; Package-Requires: ((emacs "24.4") (biblio-core "0.2") (let-alist "1.0.6") (seq "2.24") (compat "29.1.4.2"))
;; Version: 1.0
;; Keywords: bib, tex
;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file is not part of GNU Emacs.

;;; Commentary:
;; This package adds a hook to `biblio-init-hook' that will enable a
;; backend for Google Books. This code is based on biblio-arxiv.el.
;; More information on querying Google Books is available at:
;; https://developers.google.com/books/docs/v1/using#q

;;; Code:
(require 'let-alist)
(require 'seq)
(require 'compat)
(require 'biblio-core)

(defgroup biblio-gbooks nil
  "Google Books support in biblio.el."
  :group 'biblio)

(defcustom biblio-gbooks-bibtex-header "Book"
  "Which header to use for BibTeX entries generated from Google Books metadata."
  :group 'biblio
  :type 'string)

(defun biblio-gbooks--forward-bibtex (metadata forward-to)
  "Forward BibTeX for Google Books entry METADATA to FORWARD-TO."
  (let-alist metadata
    (message "Forwarding bibtex.")
    (funcall forward-to (biblio-gbooks--download-bibtex (car .references )))))

(defun biblio-gbooks--download-bibtex (id)
  "Create a BibTeX record from Google Books for ID."
  (message "Downloading BibTex entry for %S." id)
  (cadr (split-string (with-current-buffer (let ((url-show-status nil)) (url-retrieve-synchronously (format "https://books.google.com/books?id=%s&output=bibtex" id)))
			(buffer-substring (point-min) (point-max))) "\n\n")))

(defun biblio-gbooks--extract-interesting-fields (item)
  "Prepare a Google Books search result ITEM for display."
  (let-alist item
    (list (cons 'doi .doi)
          (cons 'year (if .volumeInfo.publishedDate
			  (substring .volumeInfo.publishedDate 0 4)
			"Unknown"))
          (cons 'title .volumeInfo.title)
          (cons 'authors (list "author"))
          (cons 'publisher .volumeInfo.publisher)
          (cons 'container .volumeInfo.printType)
          (cons 'references (list .id "isbn"))
          (cons 'type .volumeInfo.printType)
          (cons 'url .selfLink)
          (cons 'direct-url .selfLink)
          (cons 'open-access-status "access"))))

(defun biblio-gbooks--parse-search-results ()
  "Extract search results from Google Books response."
  (message "Parsing search results.")
  (biblio-decode-url-buffer 'utf-8)
  (let-alist (json-read)
    (seq-map #'biblio-gbooks--extract-interesting-fields .items)))

(defun biblio-gbooks--url (query)
  "Create a Google books url to look up QUERY."
  (message "Querying Google Books.")
  (format "https://www.googleapis.com/books/v1/volumes\?q\=%s"
	  (url-encode-url (string-replace " " "+" query))))

;;;###autoload
(defun biblio-gbooks-backend (command &optional arg &rest more)
  "A Google Books backend for biblio.el.
COMMAND, ARG, MORE: See `biblio-backends'."
  (pcase command
    (`name "Google Books")
    (`prompt "Google Books query: ")
    (`url (biblio-gbooks--url arg))
    (`parse-buffer (biblio-gbooks--parse-search-results))
    (`forward-bibtex (biblio-gbooks--forward-bibtex arg (car more)))
    (`register (add-to-list 'biblio-backends #'biblio-gbooks-backend))))

;;;###autoload
(defun biblio-gbooks-lookup (&optional query)
  "Start a Google Books search for QUERY, prompting if needed."
  (interactive)
  (biblio-lookup #'biblio-gbooks-backend query))

;;;###autoload
(add-hook 'biblio-init-hook #'biblio-gbooks-backend)

(provide 'biblio-gbooks)
;;; biblio-gbooks.el ends here
