(let ((config-dir (expand-file-name "config" (file-name-directory load-file-name))))
  (when (file-directory-p config-dir)
    (dolist (file (sort (directory-files config-dir t "\\.el$") #'string<))
      (load file nil t))))
