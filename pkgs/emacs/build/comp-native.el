;;; --- -*- lexical-binding: t -*-

;; Compile all Emacs Lisp files in the default directory.
;;
;; Based on code from https://www.emacswiki.org/emacs/GccEmacs#h5o-14

(defun run-native-compile-sync ()
  (require 'bytecomp)
  (require 'comp)
  (native-compile-async (or (pop command-line-args-left)
                            (error "Specify a source directory as the argument"))
                        nil nil
                        (lambda (name)
                          (and (string-match-p "^[^.]" (file-name-nondirectory name))
                               (not (string-suffix-p "-pkg.el" name)))))
  (while (or comp-files-queue
             (> (comp-async-runnings) 0))
    ;; Calibration may be needed
    (sleep-for 0.3)))
