(require 'use-package)

(use-package dash
  :ensure t)

(use-package doom-themes
  :ensure t)

(use-package magit
  :ensure t)

(use-package ivy
  :pin gnu
  :ensure t)

;; ELPA Core package
(use-package project
  :ensure t)

;; ELPA Core package with :shell-command
;; (use-package erc
;;   :pin gnu
;;   :ensure t)

;; Archived in emacsattic, which means it is only available from emacsmirror
(use-package undo-browse
  :ensure t)

;; Single-file ELPA package, which means only available from emacsmirror
(use-package undo-tree
  :ensure t)

;; GNU ELPA external package with :auto-sync (simple)
(use-package async
  :ensure t)

;; GNU ELPA external package with :auto-sync (complex)
(use-package consult
  :ensure t)

;; GNU ELPA external package with :auto-sync and :make
(use-package org-transclusion
  :ensure t)

;; GNU ELPA external package with :auto-sync and :renames
(use-package vertico
  :ensure t)

;; GNU ELPA external package with :auto-sync, the hardest one
(use-package tramp
  :ensure t)

;; ELPA external package that should be installed from an archive
(use-package bbdb
  :pin gnu
  :ensure t)

(use-package google-translate
  :ensure t)
