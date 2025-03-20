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

(defvar llm-tool-collection--all-tools nil
  "A list of all tool definition symbols.")

(defun llm-tool-collection--name-to-symbol (name)
  "Convert tool NAME into a namespaced symbol by prepending `llm-tc/'."
  (intern (concat "llm-tc/" (symbol-name name))))

(defun llm-tool-collection--make-llm-name (name)
  "Replace dashes with underscores to make tool NAME LLM-friendly."
  (string-replace "-" "_" (symbol-name name)))

(defmacro llm-tool-collection-deftool (name specs arguments &rest body)
  "Declare a generic LLM tool named NAME.
The SPECS should be a plist specifying the standard attributes of a LLM
tool. The `:name' attribute should be set to a LLM-friendly name. If it
is not set, the NAME argument (with dashes replaced with underscores)
will be used by default.

SPECS may also contain extra keywords used by certain clients, such as
`:include' and `:confirm' for gptel. Conformant clients should ignore
all unsupported keywords. Tool definitions should contain a `:category'
value and a list of symbols for `:tags' to make it convenient for users
to select tools.

ARGUMENTS contains the argument list for the tool function; BODY
contains the function body.

The resulting tool definition will be under `llm-tc/NAME'"
  (declare (indent defun))
  (let* ((sym (llm-tool-collection--name-to-symbol name))
         (name (unless (plist-get specs :name)
                 `(:name ,(llm-tool-collection--make-llm-name name)))))
    `(progn
       (defconst ,sym
         '(,@name
           ,@specs
           :function #',sym))
       (defun ,sym ,arguments
         ,(concat (plist-get specs :description) "\n\n"
                  "Definition generated by `llm-tool-collection'.")
         ,@body)
       (push ',sym llm-tool-collection--all-tools))))

(defun llm-tool-collection-get-category (category)
  "Return a list of all tool definitions in the collection part of CATEGORY.

Mapping over this list with `gptel-make-tool', `llm-make-tool', or
similar will add all tools to the respective client:

 (mapcar (apply-partially #'apply #'gptel-make-tool)
         (llm-tool-collection-get-category \"filesystem\"))"
  (seq-filter (lambda (tool) (string= (plist-get tool :category) category))
              (llm-tool-collection-get-all)))

(defun llm-tool-collection-get-all ()
  "Return a list of all tool definitions in the collection.

Mapping over this list with `gptel-make-tool', `llm-make-tool', or
similar will add all tools to the respective client:

 (mapcar (apply-partially #'apply #'gptel-make-tool)
         (llm-tool-collection-get-all))"
  (mapcar #'symbol-value llm-tool-collection--all-tools))

(llm-tool-collection-deftool read-file
  (:description "Read the contents of a file."
                :args (list '(:name "path"
                                    :type "string"
                                    :description "Path to the file to read. Supports relative paths and ~."))
                :category "filesystem"
                :confirm t
                :include t)
  (path)
  (with-temp-buffer
    (insert-file-contents (expand-file-name path))
    (buffer-string)))

(llm-tool-collection-deftool "list_directory"
  :description "List the contents of a specified directory"
  :args (list '(:name "path"
                      :type "string"
                      :description "Path to the directory. Supports relative paths and ~."))
  :function (lambda (path)
              (let ((expanded-path (expand-file-name path)))
                (if (file-directory-p expanded-path)
                    (string-join `(,(format "Contents of %s:" path)
                                   ,@(directory-files expanded-path))
                                 "\n")
                  (error "%s is not a directory" expanded-path))))
  :category "filesystem"
  :confirm t
  :include t)

(llm-tool-collection-deftool "create_file"
  :description "Create a new file with specified content"
  :args (list '(:name "path"
                      :type "string"
                      :description "Path to the new file. Supports relative paths and ~.")
              '(:name "content"
                      :type "string"
                      :description "Content to write to the file"))
  :function (lambda (path content)
              (let ((expanded-path (expand-file-name path)))
                (if (file-exists-p expanded-path)
                    (error "File already exists: %s" expanded-path)
                  (with-temp-file expanded-path
                    (insert content))
                  (format "File created successfully: %s" path))))
  :category "filesystem"
  :confirm t)

(llm-tool-collection-deftool "create_directory"
  :description "Create a new directory at the specified path"
  :args (list '(:name "path"
                      :type "string"
                      :description "Path to the new directory. Supports relative paths and ~."))
  :function (lambda (path)
              (let ((expanded-path (expand-file-name path)))
                (if (file-exists-p expanded-path)
                    (error "Directory already exists: %s" expanded-path)
                  (make-directory expanded-path t)
                  (format "Directory created successfully: %s" path))))
  :category "filesystem"
  :confirm t)

(provide 'llm-tool-collection)

;;; llm-tool-collection.el ends here
