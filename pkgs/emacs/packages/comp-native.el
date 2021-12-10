;;; --- -*- lexical-binding: t -*-

;; Compile all Emacs Lisp files in the default directory.
;;
;; Based on code from https://www.emacswiki.org/emacs/GccEmacs#h5o-14

;; (dolist (dir (split-string (getenv "ELNLOADPATH") ":"))
;;   (push dir native-comp-eln-load-path))

(defun native-compile-sync-default-directory ()
  (let ((target-directory (expand-file-name "eln-cache/" default-directory)))
    (make-directory target-directory)
    (push target-directory native-comp-eln-load-path)
    (setq native-compile-target-directory target-directory))
  (condition-case err
      (native-compile-async default-directory 'recursively)
    (error (message "%s" err)))
  (while (or comp-files-queue
             (> (comp-async-runnings) 0))
    ;; Calibration may be needed
    (sleep-for 0.3)))
