(let ((custom-dir (expand-file-name "custom" (file-name-directory load-file-name))))
  (when (file-directory-p custom-dir)
    (dolist (file (sort (directory-files custom-dir t "\\.el$") #'string<))
      (load file nil t))))
