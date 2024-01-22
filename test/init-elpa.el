(require 'use-package)

;; This will disable :ensure option of use-package when the init file is
;; actually loaded, so it prevents package.el from installing packages.
(setq use-package-ensure-function #'ignore)

;; Test :renames
(use-package magit-section
  :ensure t)
