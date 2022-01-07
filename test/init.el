(require 'use-package)

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

;; Archived in emacsattic, which means it is only available from emacsmirror
(use-package undo-browse
  :ensure t)

;; Single-file ELPA package, which means only available from emacsmirror
(use-package undo-tree
  :ensure t)

;; ELPA external package
;; (use-package bbdb
;;   :pin gnu
;;   :ensure t)
