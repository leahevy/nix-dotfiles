(let ((packages-dir (expand-file-name "packages" (file-name-directory load-file-name))))
  (when (file-directory-p packages-dir)
    (dolist (file (sort (directory-files packages-dir t "\\.el$") #'string<))
      (load file nil t))))
