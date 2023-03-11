(require 'use-package)

;; This will disable :ensure option of use-package when the init file is
;; actually loaded, so it prevents package.el from installing packages.
(setq use-package-ensure-function #'ignore)

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
(use-package refactor
  :ensure t)

;; Single-file ELPA package, which means only available from emacsmirror
(use-package undo-tree
  :ensure t)

;; GNU ELPA external package
(use-package async
  :ensure t)

;; GNU ELPA external package
(use-package consult
  :ensure t)

;; GNU ELPA external package with :make
(use-package org-transclusion
  :ensure t)

;; GNU ELPA external package with :renames
(use-package vertico
  :ensure t)

;; The hardest GNU ELPA external package
(use-package tramp
  :ensure t)

;; ELPA external package that should be installed from an archive
(use-package bbdb
  :pin gnu
  :ensure t)

(use-package google-translate
  :ensure t)

(use-package drag-stuff
  :ensure t)
