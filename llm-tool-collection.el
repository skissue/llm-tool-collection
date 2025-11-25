;;; llm-tool-collection.el --- Crowdsourced tools for LLMs -*- lexical-binding: t -*-

;; Author: Ad <me@skissue.xyz>
;; Maintainer: Ad <me@skissue.xyz>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1"))
;; Homepage: https://github.com/skissue/llm-tool-collection
;; Keywords: tools, convenience


;; This file is not part of GNU Emacs

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.


;;; Commentary:

;; Crowdsourced collection of tools for LLMs in Emacs

;;; Code:

(require 'seq)
(require 'cl-lib)

(defvar llm-tool-collection--all-tools nil
  "A list of all tool definition symbols.")

(eval-and-compile
  (defun llm-tool-collection--name-to-symbol (name)
    "Convert tool NAME into a namespaced symbol by prepending `llm-tc/'."
    (intern (concat "llm-tc/" (symbol-name name))))

  (defun llm-tool-collection--make-llm-name (name)
    "Replace dashes with underscores to make tool NAME LLM-friendly."
    (string-replace "-" "_" (symbol-name name))))

(defvar llm-tool-collection-post-define-functions nil
  "Functions called after defining a new LLM tool.
Each function is called with one argument, the tool's plist definition.")

(defmacro llm-tool-collection-deftool (name specs args description &rest body)
  "Declare a generic LLM tool named NAME.

SPECS should be a plist specifying the standard attributes of an LLM
tool:

- :name.  The LLM-friendly name for the tool.  If not set, the NAME
  argument (with dashes replaced with underscores) will be used by
  default.

- :category.  Required.  A string categorizing the tool, such as
  \"filesystem\", \"buffers\", \"system\".

- :tags.  A list of symbols for tagging the tool to enable more precise
  filtering.  These can be arbitrary symbols, such as `buffers',
  `introspection', `programming', `editing'.

SPECS may also contain other extra keywords used by specific clients.
Conformant clients should ignore all unsupported keywords.  Recommended
examples:

- :confirm.  Boolean flag to indicate whether user confirmation should be
  requested before executing the tool (used by `gptel').

- :include.  Boolean flag to indicate whether the tool result should be
  included as part of the LLM output (used by `gptel').

ARGS is a list where each element is of the form

  (ARGNAME \"DESCRIPTION\" :type TYPE [...]).

Arguments after the special symbol `&optional' are marked as optional.
TYPE and further properties [...] can include:

- :type.  Required.  One of the symbols string, number, integer, boolean,
  array, object, or null.

- :enum.  For enumerated types, a vector of strings representing allowed
  values.  Note that :type is still required even with enums.

- :items.  Required if :type is array.  Must be a plist including at least
  the item's :type.

- :properties.  Required if :type is object.  Must be a plist that can be
  serialized into a JSON object specification via `json-serialize', with
  the exception that :type specifications in this plist must be symbols.

- :required.  For object types, a vector of strings listing required
  object keys.

For example, a weather tool might have ARGS defined as:

  ((location \"The city and state, e.g. San Francisco, CA\" :type string)
   &optional
   (unit \"The unit of temperature, either \\='celsius\\=' or \\='fahrenheit\\='\"
         :type string
         :enum [\"celsius\" \"fahrenheit\"]))

This would translate to a tool specification, in the sense described at
the URL
`https://github.com/ahyatt/llm/discussions/124#discussioncomment-11877109',
with args:

  ((:name \"location\"
    :type string
    :description \"The city and state, e.g. San Francisco, CA\")
   (:name \"unit\"
    :type string
    :enum [\"celsius\" \"fahrenheit\"]
    :description \"The unit of temperature, either \\='celsius\\=' or \\='fahrenheit\\='\"
    :optional t))

DESCRIPTION is the tool's documentation string.

BODY contains the function body.

This macro defines a constant with the tool's specs and a function whose
docstring is DESCRIPTION with the tool's body under `llm-tc/NAME'. After
the tool is defined, it is additionally made available via
`llm-tool-collection-get-all' and `llm-tool-collection-get-category',
and all functions in `llm-tool-collection-post-define-functions' are
called with the tool's spec as their argument."
  (declare (indent 4)
           (doc-string 4)
           (debug (&define symbolp sexp sexp stringp def-body)))
  (let* ((optional nil)
         (arg-syms '())
         (arg-specs '()))
    (when (plist-get specs :async) (push 'callback-fn arg-syms))
    (dolist (arg args)
      (if (eq arg '&optional)
          (progn
            (setq optional t)
            (push arg arg-syms))
        (let ((argname (car arg))
              (argdesc (cadr arg))
              (argrest (cddr arg)))
          (push argname arg-syms)
          (push `(:name ,(llm-tool-collection--make-llm-name argname)
                        :description ,argdesc
                        ,@(when optional '(:optional t))
                        ,@argrest)
                arg-specs))))
    (setq arg-syms (reverse arg-syms)
          arg-specs (reverse arg-specs))
    (let* ((sym (llm-tool-collection--name-to-symbol name))
           (name-spec (unless (plist-get specs :name)
                        `(:name ,(llm-tool-collection--make-llm-name name)))))
      `(progn
         (defconst ,sym
           '(,@name-spec
             :description ,description
             ,@specs
             :args ,arg-specs
             :function ,sym))
         (defun ,sym ,arg-syms
           ,(concat description "\n\n"
                    "Definition generated by `llm-tool-collection'.")
           ,@body)
         (cl-pushnew ',sym llm-tool-collection--all-tools)
         (run-hook-with-args
          'llm-tool-collection-post-define-functions (symbol-value ',sym))))))

;;;###autoload
(defun llm-tool-collection-get-category (category)
  "Return a list of all tool definitions in the collection part of CATEGORY.

Mapping over this list with `gptel-make-tool', `llm-make-tool', or
similar will add all tools to the respective client:

 (mapcar (apply-partially #\\='apply #\\='gptel-make-tool)
         (llm-tool-collection-get-category \"filesystem\"))"
  (seq-filter (lambda (tool) (string= (plist-get tool :category) category))
              (llm-tool-collection-get-all)))

;;;###autoload
(defun llm-tool-collection-get-tag (tag)
  "Return a list of all tool definitions in the collection tagged with TAG.

Mapping over this list with `gptel-make-tool', `llm-make-tool', or
similar will add all tools to the respective client:

 (mapcar (apply-partially #\\='apply #\\='gptel-make-tool)
         (llm-tool-collection-get-tag \\='buffer))"
  (seq-filter (lambda (tool) (memq tag (plist-get tool :tags)))
              (llm-tool-collection-get-all)))

;;;###autoload
(defun llm-tool-collection-get-all ()
  "Return a list of all tool definitions in the collection.

Mapping over this list with `gptel-make-tool', `llm-make-tool', or
similar will add all tools to the respective client:

 (mapcar (apply-partially #\\='apply #\\='gptel-make-tool)
         (llm-tool-collection-get-all))"
  (mapcar #'symbol-value llm-tool-collection--all-tools))

;;; Imenu

;;;###autoload
(cl-pushnew (list "LLM Tools"
                  (concat "^\\s-*("
                          (regexp-opt '("llm-tool-collection-deftool") t)
                          "\\s-+\\(" lisp-mode-symbol-regexp "\\)")
                  2)
            lisp-imenu-generic-expression :test #'equal)

;;; Font-Lock

;;;###autoload
(defconst llm-tool-collection-font-lock-keywords
  '(("(\\(llm-tool-collection-deftool\\)\\_>[ \t'(]*\\(\\(?:\\sw\\|\\s_\\)+\\)?"
     (1 'font-lock-keyword-face)
     (2 'font-lock-function-name-face nil t))))

;;;###autoload
(font-lock-add-keywords 'emacs-lisp-mode llm-tool-collection-font-lock-keywords)

;;; Tools

(llm-tool-collection-deftool read-file
    (:category "filesystem" :tags (filesystem editing) :confirm t :include t)
    ((path "Path to the file to read. Supports relative paths and '~'."
           :type string))
    "Read the contents of a file and return its content as a string."
  (with-temp-buffer
    (insert-file-contents (expand-file-name path))
    (buffer-string)))

(llm-tool-collection-deftool list-directory
    (:category "filesystem" :tags (filesystem) :confirm t :include t)
    ((path "Path to the directory. Supports relative paths and '~'."
           :type string))
    "List the contents of a specified directory."
  (let ((expanded-path (expand-file-name path)))
    (if (file-directory-p expanded-path)
        (string-join `(,(format "Contents of %s:" path)
                       ,@(directory-files expanded-path))
                     "\n")
      (error "%s is not a directory" expanded-path))))

(llm-tool-collection-deftool create-file
    (:category "filesystem" :tags (filesystem editing) :confirm t)
    ((path "Path to the new file. Supports relative paths and '~'." :type string)
     (content "Content to write to the file." :type string))
    "Create a new file with the specified content if it does not already exist."
  (let ((expanded-path (expand-file-name path)))
    (if (file-exists-p expanded-path)
        (error "File already exists: %s" expanded-path)
      (with-temp-file expanded-path
        (insert content))
      (format "File created successfully: %s" path))))

(llm-tool-collection-deftool create-directory
    (:category "filesystem" :tags (filesystem) :confirm t)
    ((path "Path to the new directory. Supports relative paths and '~'."
           :type string))
    "Create a new directory at the specified path if it does not already
exist."
  (let ((expanded-path (expand-file-name path)))
    (if (file-exists-p expanded-path)
        (error "Directory already exists: %s" expanded-path)
      (make-directory expanded-path t)
      (format "Directory created successfully: %s" path))))

(defun llm-tool-collection--view-text (lines offset limit)
  "Process LINES array with OFFSET and LIMIT parameters.
OFFSET is 0-based line number to start from.
LIMIT is maximum number of lines to return.
Returns selected lines joined with newlines."
  (let* ((total-lines (length lines))
         (offset-value (or offset 0)))
    (when (< offset-value 0)
      (error "Offset must be non-negative, got %s" offset-value))
    (when (>= offset-value total-lines)
      (error "Offset %s exceeds line count %s" offset-value total-lines))
    (let* ((start offset-value)
           (end (min (+ start (or limit total-lines)) total-lines))
           (selected-lines (seq-subseq lines start end)))
      (string-join selected-lines "\n"))))

(llm-tool-collection-deftool view-buffer
    (:category "buffers" :tags (buffers editing introspection))
    ((buffer-name "Name of the buffer to view." :type string)
     &optional
     (offset "Line number to start reading from (0-based)." :type integer)
     (limit "Maximum number of lines to return." :type integer))
    "View contents of BUFFER-NAME with optional OFFSET and LIMIT."
  (if-let* ((buf (get-buffer buffer-name)))
      (with-current-buffer buf
        (let ((lines (split-string (buffer-string) "\n")))
          (llm-tool-collection--view-text lines offset limit)))
    (error "Buffer not found: %s" buffer-name)))

(llm-tool-collection-deftool view-file
    (:category "filesystem" :tags (filesystem editing introspection) :include t)
    ((file "Absolute or relative path to the file to read. Supports '~'."
           :type string)
     &optional
     (offset "Line number to start reading from (0-based)." :type integer)
     (limit "Number of lines to read" :type integer))
    "Read file contents with optional OFFSET and LIMIT."
  (if (not (file-exists-p file))
      (error "File does not exist: %s" file)
    (with-temp-buffer
      (insert-file-contents file)
      (let ((lines (split-string (buffer-string) "\n")))
        (llm-tool-collection--view-text lines offset limit)))))

(defun llm-tool-collection--make-edit (buffer-or-file old-string new-string)
  "Replace exactly one occurrence of OLD-STRING with NEW-STRING.
BUFFER-OR-FILE is either a buffer object or a file path string."
  (when (string= old-string "")
    (error "`old_string' cannot be empty"))
  (let* ((is-file? (not (bufferp buffer-or-file)))
         (name (if is-file?
                   (concat "file " buffer-or-file)
                 (concat "buffer " (buffer-name buffer-or-file)))))
    (with-current-buffer (if is-file?
                             (let ((temp-buf (generate-new-buffer " *temp*")))
                               (with-current-buffer temp-buf
                                 (insert-file-contents
                                  (expand-file-name buffer-or-file)))
                               temp-buf)
                           buffer-or-file)
      (prog1
          (let ((case-fold-search nil))
            (save-excursion
              (goto-char (point-min))
              (let ((count 0)
                    (first-match-pos nil))
                (while (search-forward old-string nil 'noerror)
                  (setq count (1+ count))
                  (unless first-match-pos
                    (setq first-match-pos (match-beginning 0))))
                (cond
                 ((= count 0)
                  (error "Could not find text '%s' to replace in %s"
                         old-string name))
                 ((> count 1)
                  (error "Found %d matches for '%s' in %s, need exactly one"
                         count old-string name))
                 (t
                  (goto-char first-match-pos)
                  (search-forward old-string nil 'noerror)
                  (replace-match new-string 'fixedcase 'literal)
                  (when is-file?
                    (write-file (expand-file-name buffer-or-file)))
                  (format "Successfully edited %s" name))))))
        (when is-file?
          (kill-buffer))))))

(llm-tool-collection-deftool edit-buffer
    (:category "buffers" :tags (buffers editing))
    ((buffer-name "Name of the buffer to modify" :type string)
     (old-string "Text to replace (must match exactly)" :type string)
     (new-string "Text to replace old_string with" :type string))
    "Edits Emacs buffers by replacing exactly one occurrence of old_string."
  (let ((buffer (get-buffer buffer-name)))
    (unless buffer
      (error "Buffer not found: %s" buffer-name))
    (llm-tool-collection--make-edit buffer old-string new-string)))

(llm-tool-collection-deftool edit-file
    (:category "filesystem" :tags (filesystem editing) :confirm t)
    ((file "Absolute or relative path to the file to modify" :type string)
     (old-string "Text to replace (must match exactly)" :type string)
     (new-string "Text to replace old_string with" :type string))
    "Edit file by replacing exactly one match of OLD-STRING with NEW-STRING."
  (let ((expanded-file (expand-file-name file)))
    (unless (file-exists-p expanded-file)
      (error "File does not exist: %s" expanded-file))
    (llm-tool-collection--make-edit expanded-file old-string new-string)))

(llm-tool-collection-deftool glob
    (:category "filesystem" :tags (filesystem search) :include t)
    ((pattern "Glob pattern to match files" :type string)
     &optional
     (path "Directory to search in" :type string))
    "File pattern matching"
  (let* ((default-directory (or path default-directory))
         (files (file-expand-wildcards pattern)))
    (string-join files "\n")))
(llm-tool-collection-deftool replace-buffer
    (:category "buffers" :tags (buffers editing) :confirm t)
    ((buffer-name "Name of the buffer to overwrite" :type string)
     (content "Content to write to the buffer" :type string))
    "Completely overwrites the contents of BUFFER-NAME with CONTENT."
  (if-let* ((buffer (get-buffer buffer-name)))
      (progn
        (with-current-buffer buffer
          (let ((buffer-read-only nil))
            (erase-buffer)
            (insert content)))
        (format "Buffer content replaced: %s" buffer-name))
    (error "Buffer does not exist: %s" buffer-name)))

(llm-tool-collection-deftool replace-file
    (:category "filesystem" :tags (filesystem editing) :confirm t)
    ((file "Absolute or relative path to file to write.  \
Supports '~'." :type string)
     (content "Content to write to the file" :type string))
    "Completely overwrites file at FILE with the given CONTENT."
  (let ((expanded-path (expand-file-name file)))
    (unless (file-exists-p expanded-path)
      (error "File does not exist: %s" expanded-path))
    (with-temp-buffer
      (insert content)
      (write-file expanded-path)
      (format "File replaced: %s" file))))

(llm-tool-collection-deftool grep
    (:category "filesystem" :tags (filesystem search system) :async t :include t)
    ((pattern "Regex pattern to search for in file contents."
              :type string)
     &optional
     (include "Glob pattern for files to limit search to. Defaults to searching all
files."
              :type string)
     (path "Directory to search in. Must be an absolute path or start with `~`.
Defaults to the current directory."
           :type string)
     (ignore-case "Whether to ignore case in the search pattern. Defaults to
case-sensitive."
                  :type boolean))
    "Recursively search for a regular expression using grep."
  (if (and path (not (file-directory-p path)))
      (funcall callback-fn
               (format "Error: path %s does not exist or is not a directory"
                       path))
    (let* ((default-directory (or path default-directory))
           (output-buffer (generate-new-buffer " *grep-output*"))
           (include-arg (if include
                            (concat "--include=" include)
                          "--include=*"))
           (case-arg (if ignore-case
                         "--ignore-case"
                       "--no-ignore-case"))
           (process (start-process "grep" output-buffer
                                   "grep" "-r" "-n" "-E"
                                   include-arg case-arg
                                   pattern)))
      (set-process-query-on-exit-flag process nil)
      (set-process-sentinel
       process
       (lambda (_process _event)
         (let ((result (with-current-buffer output-buffer
                         (string-trim (buffer-string)))))
           (if (string-empty-p result)
               (funcall callback-fn "No matches found")
             (funcall callback-fn result)))
         (kill-buffer output-buffer))))))

(llm-tool-collection-deftool ls
    (:category "filesystem" :tags (filesystem) :include t)
    ((path "Absolute or relative path to directory to list.  \
Supports '~'." :type string)
     &optional
     (ignore "Array of Elisp regexp patterns (e.g., \"\\\\.pdf$\") to ignore"
             :type array :items (:type string)))
    "Lists files and directories"
  (let* ((path (expand-file-name path))
         (files (directory-files path)))
    (when (and files ignore)
      (let ((ignore-patterns (if (vectorp ignore)
                                 (append ignore nil)
                               (list ignore))))
        (dolist (pattern ignore-patterns)
          (setq files (seq-remove (lambda (f)
                                    (string-match-p pattern
                                                    (file-name-nondirectory f)))
                                  files)))))
    (string-join (mapcar #'file-name-nondirectory files) "\n")))

(llm-tool-collection-deftool buffer-search
    (:category "buffers" :tags (buffers search introspection) :include t)
    ((pattern "Regex pattern to search for in buffer contents.
Regex syntax is that of Emacs -- parentheses are NOT escaped!
  example: search for \"'(defun\", not \"\\\\(defun\"."
              :type string)
     (buffer
      "Name of buffer in which to search"
      :type string))
    "Search within a Emacs buffer using Emacs regex"
  (let ((buf (get-buffer buffer)))
    (unless buffer
      (error "Buffer '%s' does not exist" buffer))
    (with-current-buffer buf
      (save-excursion
        (condition-case err
            (let ((matched-lines '()))
              (goto-char (point-min))
              (while (re-search-forward pattern nil t)
                (push (line-number-at-pos) matched-lines)
                (forward-line 1))
              (setq matched-lines (delete-dups (nreverse matched-lines)))
              (if matched-lines
                  (mapconcat
                   (lambda (line-num)
                     (save-excursion
                       (goto-char (point-min))
                       (forward-line (1- line-num))
                       (format "%d: %s" line-num
                               (buffer-substring-no-properties
                                (line-beginning-position)
                                (line-end-position)))))
                   matched-lines
                   "\n")
                (error "No matches found")))
          (invalid-regexp
           (error "\
Invalid regexp pattern: %s.
Remember Emacs regex syntax (e.g., \\(group\\) not (group)).
Error: %s"
                  pattern
                  (error-message-string err))))))))

(defun llm-tool-collection--user-buffer-p (buf)
  "Return t if BUF is a user-relevant buffer."
  (let ((buf-name (buffer-name buf)))
    (and buf-name
         (not (string-prefix-p " " buf-name))
         (not (string-prefix-p "*" buf-name)) ; maybe not a good idea?
         (buffer-live-p buf))))

(llm-tool-collection-deftool list-buffers
    (:category "buffers" :tags (buffers introspection) :include t)
    ()
    "Lists active, user-relevant buffers (excluding internal buffers)."
  (let* ((all-buffers (buffer-list))
         (user-buffers (seq-filter
                        (lambda (buf)
                          (llm-tool-collection--user-buffer-p buf))
                        all-buffers))
         (sorted-buffers (sort user-buffers
                               (lambda (a b)
                                 (string< (buffer-name a)
                                          (buffer-name b))))))
    (if sorted-buffers
        (mapconcat (lambda (buf)
                     (concat
                      (buffer-name buf)
                      (when-let* ((file-name (buffer-file-name buf)))
                        (format " (visiting file: %s)" file-name))))
                   sorted-buffers
                   "\n")
      (error "No user-relevant buffers found"))))

(llm-tool-collection-deftool bash
    (:category "system" :tags (system execution) :async t :confirm t)
    ((command "Command string to execute in bash" :type string))
    "Executes bash COMMAND, returning its standard output.
Signals an error if the command fails (non-zero exit code)."
  (let* ((output-buffer (generate-new-buffer " *bash-output*"))
         (process (start-process "bash" output-buffer
                                 "bash" "-c" command)))
    (set-process-query-on-exit-flag process nil)
    (set-process-sentinel
     process
     (lambda (_process _event)
       (let ((exit-code (process-exit-status process))
             (output (with-current-buffer output-buffer
                       (buffer-string))))
         (if (zerop exit-code)
             (funcall callback-fn output)
           (funcall
            callback-fn
            (format "Command failed with exit code %d\n\nOutput:\n%s"
                    exit-code (if (string-empty-p output)
                                  "<no output>"
                                output))))
         (kill-buffer output-buffer))))))

(provide 'llm-tool-collection)

;;; llm-tool-collection.el ends here
