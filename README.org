#+title: LLM Tool Collection
#+author: Ad <me@skissue.xyz>

A curated collection of tools to empower Emacs-based LLM agents.

* Table of Contents
:PROPERTIES:
:TOC:      :include all :depth 2 :force (nothing) :ignore (this) :local (nothing)
:END:
:CONTENTS:
- [[#installation][Installation]]
- [[#usage][Usage]]
- [[#tool-list][Tool List]]
  - [[#filesystem][Filesystem]]
  - [[#buffers][Buffers]]
  - [[#search][Search]]
  - [[#system][System]]
- [[#removed-tools][Removed Tools]]
- [[#contributing][Contributing]]
  - [[#faster-iteration][Faster Iteration]]
:END:

* Installation
:PROPERTIES:
:CUSTOM_ID: installation
:END:
This package is not yet in any repositories. Install it with your favorite from-Git method!

Quick and dirty: clone the repository and add it to ~load-path~.
#+begin_src elisp
  (add-to-list 'load-path "/path/to/llm-tool-collection/")
  (require 'llm-tool-collection)
#+end_src

* Usage
:PROPERTIES:
:CUSTOM_ID: usage
:END:
Quick and dirty: register every tool.
#+begin_src elisp
  ;; For gptel:
  (mapcar (apply-partially #'apply #'gptel-make-tool)
          (llm-tool-collection-get-all))

  ;; For llm:
  (mapcar (apply-partially #'apply #'llm-make-tool)
          (llm-tool-collection-get-all))
#+end_src

Every tool is defined with a symbol =llm-tc/tool-name= that has both a variable value and a function value. The variable value contains the tool specification, which can be passed to any compliant Emacs LLM client. The function value contains the function that runs the given tool. This can be instrumented or run manually.

To register just one tool:
#+begin_src elisp
  ;; For gptel:
  (apply #'gptel-make-tool llm-tc/list-directory)

  ;; For llm:
  (apply #'llm-make-tool llm-tc/list-directory)
#+end_src

Use ~llm-tool-collection-get-category~ to map over a list of tools pertaining to a specific task.
#+begin_src elisp
  ;; For gptel:
  (mapcar (apply-partially #'apply #'gptel-make-tool)
          (llm-tool-collection-get-category "filesystem"))

  ;; For llm:
  (mapcar (apply-partially #'apply #'llm-make-tool)
          (llm-tool-collection-get-category "filesystem"))

#+end_src

Use ~llm-tool-collection-get-tag~ to map over a list of tools with a specific tag.
#+begin_src elisp
  ;; For gptel:
  (mapcar (apply-partially #'apply #'gptel-make-tool)
          (llm-tool-collection-get-tag 'editing))

  ;; For llm:
  (mapcar (apply-partially #'apply #'llm-make-tool)
          (llm-tool-collection-get-tag 'editing))
#+end_src

See [[#tool-list][Tool List]] for a list of tool names, descriptions, and categories.

* Tool List
:PROPERTIES:
:CUSTOM_ID: tool-list
:END:
** Filesystem
:PROPERTIES:
:CUSTOM_ID: filesystem
:END:
*** create-file
+ Author :: @skissue
+ Tags :: filesystem, editing

Allows the LLM to create a new file with specified content. Returns an error if the file already exists.

*** create-directory
+ Author :: @skissue
+ Tags :: filesystem

Allows the LLM to create a new directory. Returns an error if the directory already exists.

*** view-file
+ Author :: @ultronozm
+ Tags   :: filesystem, editing, introspection

Views the contents of a file.  Optional /offset/ and /limit/ let you show a slice of lines.

*** edit-file
+ Author :: @ultronozm
+ Tags   :: filesystem, editing

Replaces **exactly one** occurrence of a string in a file with a new string.

*** glob
+ Author :: @ultronozm
+ Tags   :: filesystem, search

Expands a Unix‑style glob pattern (e.g. =*.el=) and returns the matching paths.

*** replace-file
+ Author :: @ultronozm
+ Tags   :: filesystem, editing

Completely overwrites a file with the supplied content.

*** ls
+ Author :: @ultronozm
+ Tags   :: filesystem

Lists directory contents, with optional regexps to ignore.

** Buffers
:PROPERTIES:
:CUSTOM_ID: buffers
:END:
*** view-buffer
+ Author :: @ultronozm
+ Tags   :: buffers, editing, introspection

Allows the LLM to view the contents of a buffer. The LLM can optionally specify a line offset to start from, as well as a limit on the number of lines to return.

*** edit-buffer
+ Author :: @ultronozm
+ Tags   :: buffers, editing

Replaces **exactly one** occurrence of a string in a buffer.

*** replace-buffer
+ Author :: @ultronozm
+ Tags   :: buffers, editing

Overwrites an entire buffer with new content.

*** buffer-search
+ Author :: @ultronozm
+ Tags   :: buffers, search, introspection

Regex search inside a buffer; returns matching line numbers plus text.

*** list-buffers
+ Author :: @ultronozm
+ Tags   :: buffers, introspection

Lists user‑relevant buffers, excluding internal/temp buffers.

** Search
:PROPERTIES:
:CUSTOM_ID: search
:END:
*** grep
+ Author :: @ultronozm
+ Tags   :: filesystem, search, system

Recursive =grep -E= with line numbers.  Supports an optional /include/ glob for files to include, /path/ to search in, and /ignore-case/ to search case-insensitively.

** System
:PROPERTIES:
:CUSTOM_ID: system
:END:
*** bash
+ Author :: @ultronozm
+ Tags   :: system, execution

Runs an arbitrary Bash command and returns its standard output (errors if exit is nonzero).

*** eval-elisp
+ Author :: @skissue
+ Tags   :: system, execution

Evaluates an arbitrary Emacs Lisp expression in the current Emacs session and returns the printed result.

* Removed Tools
To keep this collection focused and curated, the following tools were removed in favor of other tools:

+ =read-file= (@skissue) :: Removed in favor of =view-file= (@ultronozm).
+ =list-directory= (@skissue) :: Removed in favor of =ls= (@ultronozm).

* Contributing
:PROPERTIES:
:CUSTOM_ID: contributing
:END:
Contributions to this project are welcome and encouraged!

To write a new tool, use the ~llm-tool-collection-deftool~ macro. For details on its usage, see its docstring as well as the existing tools.

#+begin_src elisp
  (llm-tool-collection-deftool read-file ; Tool name
    ;; Specs
    (:category "filesystem" :tags (filesystem editing) :confirm t :include t)
    ;; Arguments, with LLM-friendly documentation and types
    ((path "Path to the file to read. Supports relative paths and '~'."
           :type string))
    ;; LLM-friendly tool documentation
    "Read the contents of a file and return its content as a string."
    ;; Implementation body
    (with-temp-buffer
      (insert-file-contents (expand-file-name path))
      (buffer-string)))
#+end_src

Some guidelines:
+ It's highly recommended to include ~:tags~, as well as appropriate values for the ~:confirm~ and ~:include~ parameters, depending on how dangerous the tool may be.
+ Docstrings should be LLM-friendly; consider instructing models on when to call a tool, what tools it may want to chain together, and invariants to keep in mind.
+ To keep this collection curated, don't create new tools that have overlapping functionality with existing tools unless there is a meaningful fundamental difference. Consider whether an existing tool could be extended or improved instead. This is a living collection!
+ After defining a tool, make sure to add it to the README! Use the existing documentation structure as an example.

When ready, submit a PR!

** Faster Iteration
:PROPERTIES:
:CUSTOM_ID: faster-iteration
:END:
There will likely be many iterations necessary to get a tool to a good state. To speed up the feedback loop, functions to immediately update the tools in an LLM interface can be added to ~llm-tool-collection-post-define-functions~. For example, to immediately add (or re-add) a tool to [[https://github.com/karthink/gptel/][gptel]] upon re-evaluating the definition:

#+begin_src elisp
  (defun llm-tool-collection-register-with-gptel (tool-spec)
    "Register a tool defined by TOOL-SPEC with gptel.
  TOOL-SPEC is a plist that can be passed to `gptel-make-tool'."
    (apply #'gptel-make-tool tool-spec))

  (add-hook 'llm-tool-collection-post-define-functions
            #'llm-tool-collection-register-with-gptel)
#+end_src
