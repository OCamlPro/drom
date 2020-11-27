
Sub-commands and Arguments
==========================

For version: 0.2.1-cb899cfd

Overview::
  
  build
    Build a project
  
  build-deps
    Install build dependencies only
  
  clean
    Clean the project from build files
  
  dep (since version 0.2.1)
    Manage dependency of a package
  
  dev-deps
    Install dev dependencies (odoc, ocamlformat, merlin, etc.)
  
  doc
    Generate all documentation (API and Sphinx)
  
  fmt
    Format sources with ocamlformat
  
  install
    Build & install the project in the project opam switch
  
  lock (since version 0.2.1)
    Generate a .locked file for the project
  
  new
    Create a new project
  
  odoc
    Generate API documentation using odoc in the _drom/docs/doc directory
  
  package
    Manage a package within a project
  
  project
    Update an existing project
  
  promote
    Promote detected changes after running drom test or drom fmt
  
  publish
    Update opam files with checksums and copy them to a local opam-repository for publication
  
  run
    Execute the project
  
  sphinx
    Generate documentation using sphinx
  
  test
    Run tests
  
  tree
    Display a tree of dependencies
  
  uninstall
    Uninstall the project from the project opam switch
  
  update
    Update packages in switch


drom build
~~~~~~~~~~~~

Build a project


**USAGE**
::
  
  drom build [OPTIONS]

Where options are:


* :code:`--edition VERSION`   Use this OCaml edition

* :code:`--local`   Create a local switch instead of using a global switch

* :code:`--locked`   (since version 0.2.1) Use .locked file if it exists

* :code:`--switch OPAM_SWITCH`   Use global switch SWITCH instead of creating a local switch

* :code:`--upgrade`   Upgrade project files from drom.toml

* :code:`-y` or :code:`--yes`   Reply yes to all questions


drom build-deps
~~~~~~~~~~~~~~~~~

Install build dependencies only


**USAGE**
::
  
  drom build-deps [OPTIONS]

Where options are:


* :code:`--edition VERSION`   Use this OCaml edition

* :code:`--local`   Create a local switch instead of using a global switch

* :code:`--locked`   (since version 0.2.1) Use .locked file if it exists

* :code:`--switch OPAM_SWITCH`   Use global switch SWITCH instead of creating a local switch

* :code:`--upgrade`   Upgrade project files from drom.toml

* :code:`-y` or :code:`--yes`   Reply yes to all questions


drom clean
~~~~~~~~~~~~

Clean the project from build files


**USAGE**
::
  
  drom clean [OPTIONS]

Where options are:


* :code:`--opam`   Also remove the local opam switch (_opam/ and _drom/)


drom dep (since version 0.2.1)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Manage dependency of a package



**DESCRIPTION**


Add, remove and modify dependencies from **drom.toml** and  **package.toml** files.

If the argument **--package** is not specified, the dependency is added project-wide (i.e. for all packages), updating the *drom.toml* file.

If the argument **--package** is provided, the dependency is added to the *package.toml* file for that particular package.

Dependencies can be added **--add**, removed **--remove** or just modified. The **--tool** argument should be used for tool dependencies, i.e. dependencies that are not linked to the library/program.

If no modification argument is provided, the dependency is printed in the terminal. Modification arguments are **--ver VERSION** for the version, **--lib LIBNAME** for the *dune* library name, **--doc BOOL** for documentation deps and **--test BOOL** for test deps.


**EXAMPLE**

::
  
  drom dep --package drom_lib --add ez_cmdliner --ver ">0.1"
  drom dep --package drom_lib --remove ez_cmdliner
  drom dep --add --tool odoc --ver ">1.0 <3.0" --doc true
  


**VERSION SPECIFICATION**


The version specified in the **--ver VERSION** argument should follow the following format:

* 1.
  Spaces are used to separate a conjunction of version constraints.

* 2.
  An empty string is equivalent to no version constraint.

* 3.
  Constraints are specified using a comparison operation directly followed by the version, like **>1.2** or **<=1.0**.

* 4.
  A semantic version like **1.2.3** is equivalent to the constraints  **>=1.2.3** and **<2.0.0**.

**USAGE**
::
  
  drom dep DEPENDENCY [OPTIONS]

Where options are:


* :code:`DEPENDENCY`   Name of dependency

* :code:`--add`   Add as new dependency

* :code:`--diff`   Print a diff of user-modified files that are being skipped

* :code:`--doc BOOL`   Whether dependency is only for doc

* :code:`-f` or :code:`--force`   Force overwriting modified files (otherwise, they would be skipped)

* :code:`--lib LIBNAME`   Dependency should have this libname in dune

* :code:`--package PACKAGE`   Attach dependency to this package name

* :code:`--promote-skip`   Promote user-modified files to skip field

* :code:`--remove`   Remove this dependency

* :code:`--skip FILE`   Add FILE to skip list

* :code:`--test BOOL`   Whether dependency is only for tests

* :code:`--tool`   Dependency is a tool, not a library

* :code:`--unskip FILE`   Remove FILE from skip list

* :code:`--ver VERSION`   Dependency should have this version


drom dev-deps
~~~~~~~~~~~~~~~

Install dev dependencies (odoc, ocamlformat, merlin, etc.)


**USAGE**
::
  
  drom dev-deps [OPTIONS]

Where options are:


* :code:`--edition VERSION`   Use this OCaml edition

* :code:`--local`   Create a local switch instead of using a global switch

* :code:`--locked`   (since version 0.2.1) Use .locked file if it exists

* :code:`--switch OPAM_SWITCH`   Use global switch SWITCH instead of creating a local switch

* :code:`--upgrade`   Upgrade project files from drom.toml

* :code:`-y` or :code:`--yes`   Reply yes to all questions


drom doc
~~~~~~~~~~

Generate all documentation (API and Sphinx)


**USAGE**
::
  
  drom doc [OPTIONS]

Where options are:


* :code:`--edition VERSION`   Use this OCaml edition

* :code:`--local`   Create a local switch instead of using a global switch

* :code:`--locked`   (since version 0.2.1) Use .locked file if it exists

* :code:`--switch OPAM_SWITCH`   Use global switch SWITCH instead of creating a local switch

* :code:`--upgrade`   Upgrade project files from drom.toml

* :code:`--view`   Open a browser on the documentation

* :code:`-y` or :code:`--yes`   Reply yes to all questions


drom fmt
~~~~~~~~~~

Format sources with ocamlformat


**USAGE**
::
  
  drom fmt [OPTIONS]

Where options are:


* :code:`--auto-promote`   Promote detected changes immediately

* :code:`--edition VERSION`   Use this OCaml edition

* :code:`--local`   Create a local switch instead of using a global switch

* :code:`--locked`   (since version 0.2.1) Use .locked file if it exists

* :code:`--switch OPAM_SWITCH`   Use global switch SWITCH instead of creating a local switch

* :code:`--upgrade`   Upgrade project files from drom.toml

* :code:`-y` or :code:`--yes`   Reply yes to all questions


drom install
~~~~~~~~~~~~~~

Build & install the project in the project opam switch


**USAGE**
::
  
  drom install [OPTIONS]

Where options are:


* :code:`--edition VERSION`   Use this OCaml edition

* :code:`--local`   Create a local switch instead of using a global switch

* :code:`--locked`   (since version 0.2.1) Use .locked file if it exists

* :code:`--switch OPAM_SWITCH`   Use global switch SWITCH instead of creating a local switch

* :code:`--upgrade`   Upgrade project files from drom.toml

* :code:`-y` or :code:`--yes`   Reply yes to all questions


drom lock (since version 0.2.1)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Generate a .locked file for the project



**DESCRIPTION**


This command will build the project and call **opam lock** to generate a file *${project}-deps.opam.locked* with the exact dependencies used during the build, and that file will be added to the git-managed files of the project to be committed.

The generated .locked file can be used by other developers to build in the exact same environment by calling **drom build --locked** to build the current project.

**USAGE**
::
  
  drom lock [OPTIONS]

Where options are:


* :code:`--edition VERSION`   Use this OCaml edition

* :code:`--local`   Create a local switch instead of using a global switch

* :code:`--locked`   (since version 0.2.1) Use .locked file if it exists

* :code:`--switch OPAM_SWITCH`   Use global switch SWITCH instead of creating a local switch

* :code:`--upgrade`   Upgrade project files from drom.toml

* :code:`-y` or :code:`--yes`   Reply yes to all questions


drom new
~~~~~~~~~~

Create a new project


**USAGE**
::
  
  drom new PROJECT [OPTIONS]

Where options are:


* :code:`PROJECT`   Name of the project

* :code:`--binary`   Compile to binary

* :code:`--diff`   Print a diff of user-modified files that are being skipped

* :code:`--dir DIRECTORY`   Dir where package sources are stored (src by default)

* :code:`-f` or :code:`--force`   Force overwriting modified files (otherwise, they would be skipped)

* :code:`--inplace`   Create project in the the current directory

* :code:`--javascript`   Compile to javascript

* :code:`--library`   Project contains only a library

* :code:`--program`   Project contains only a program

* :code:`--promote-skip`   Promote user-modified files to skip field

* :code:`--skeleton SKELETON`   Create project using a predefined skeleton or one specified in ~/.config/drom/skeletons/

* :code:`--skip FILE`   Add FILE to skip list

* :code:`--unskip FILE`   Remove FILE from skip list

* :code:`--virtual`   Package is virtual, i.e. no code


drom odoc
~~~~~~~~~~~

Generate API documentation using odoc in the _drom/docs/doc directory


**USAGE**
::
  
  drom odoc [OPTIONS]

Where options are:


* :code:`--edition VERSION`   Use this OCaml edition

* :code:`--local`   Create a local switch instead of using a global switch

* :code:`--locked`   (since version 0.2.1) Use .locked file if it exists

* :code:`--switch OPAM_SWITCH`   Use global switch SWITCH instead of creating a local switch

* :code:`--upgrade`   Upgrade project files from drom.toml

* :code:`--view`   Open a browser on the documentation

* :code:`-y` or :code:`--yes`   Reply yes to all questions


drom package
~~~~~~~~~~~~~~

Manage a package within a project


**USAGE**
::
  
  drom package PACKAGE [OPTIONS]

Where options are:


* :code:`PACKAGE`   Name of the package

* :code:`--binary`   Compile to binary

* :code:`--diff`   Print a diff of user-modified files that are being skipped

* :code:`--dir DIRECTORY`   Dir where package sources are stored (src by default)

* :code:`-f` or :code:`--force`   Force overwriting modified files (otherwise, they would be skipped)

* :code:`--javascript`   Compile to javascript

* :code:`--library`   Package is a library

* :code:`--new SKELETON`   Add a new package to the project with skeleton NAME

* :code:`--new-file FILENAME`   (since version 0.2.1) Add new source file

* :code:`--program`   Package is a program

* :code:`--promote-skip`   Promote user-modified files to skip field

* :code:`--remove`   (since version 0.2.1) Remove a package from the project

* :code:`--rename NEW_NAME`   Rename secondary package to a new name

* :code:`--skip FILE`   Add FILE to skip list

* :code:`--unskip FILE`   Remove FILE from skip list

* :code:`--virtual`   Package is virtual, i.e. no code


drom project
~~~~~~~~~~~~~~

Update an existing project



**DESCRIPTION**


This command is used to regenerate the files of a project after updating its description.

With argument **--upgrade**, it can also be used to reformat the toml files, from their skeletons.

**USAGE**
::
  
  drom project [OPTIONS]

Where options are:


* :code:`--binary`   Compile to binary

* :code:`--diff`   Print a diff of user-modified files that are being skipped

* :code:`-f` or :code:`--force`   Force overwriting modified files (otherwise, they would be skipped)

* :code:`--javascript`   Compile to javascript

* :code:`--library`   Project contains only a library. Equivalent to **--skeleton library**

* :code:`--program`   Project contains a program. Equivalent to **--skeleton program**. The generated project will be composed of a *library* package and a *driver* package calling the **Main.main** of the library.

* :code:`--promote-skip`   Promote user-modified files to skip field

* :code:`--skeleton SKELETON`   Create project using a predefined skeleton or one specified in ~/.config/drom/skeletons/

* :code:`--skip FILE`   Add FILE to skip list

* :code:`--unskip FILE`   Remove FILE from skip list

* :code:`--upgrade`   Force upgrade of the drom.toml file from the skeleton

* :code:`--virtual`   Package is virtual, i.e. no code. Equivalent to **--skeleton virtual**.


drom promote
~~~~~~~~~~~~~~

Promote detected changes after running drom test or drom fmt


**USAGE**
::
  
  drom promote [OPTIONS]

Where options are:


* :code:`--edition VERSION`   Use this OCaml edition

* :code:`--local`   Create a local switch instead of using a global switch

* :code:`--locked`   (since version 0.2.1) Use .locked file if it exists

* :code:`--switch OPAM_SWITCH`   Use global switch SWITCH instead of creating a local switch

* :code:`--upgrade`   Upgrade project files from drom.toml

* :code:`-y` or :code:`--yes`   Reply yes to all questions


drom publish
~~~~~~~~~~~~~~

Update opam files with checksums and copy them to a local opam-repository for publication



**DESCRIPTION**


Before running this command, you should edit the file **$HOME/.config/drom/config** and set the value of the *opam-repo* option, like:
::
  
  [user]
  author = "John Doe <john.doe@ocaml.org>"
  github-organization = "ocaml"
  license = "LGPL2"
  copyright = "OCamlPro SAS & Origin Labs SAS"
  opam-repo = "/home/john/GIT/opam-repository"
  

Alternatively, you can run it with option **--opam-repo REPOSITORY**.

In both case, **REPOSITORY** should be the absolute path to the location of a local git-managed opam repository.

**drom publish** will perform the following actions:

* 1.
  Download the source archive corresponding to the current version

* 2.
  Compute the checksum of the archive

* 3.
  Copy updated opam files to the git-managed opam repository

Note that, prior to calling **drom publish**, you should update the opam-repository to the latest version of the **master** branch:
::
  git checkout master
  git pull ocaml master

Once the opam files have been added, you should push them to your local fork of opam-repository and create a merge request:
::
  cd ~/GIT/opam-repository
  git checkout -b z-$(date --iso)-new-package-version
  git add packages
  git commit -a -m "New version of my package"
  git push
  

To download the project source archive, **drom publish** will either use the *archive* URL of the drom.toml file, or the Github URL (if the *github-organization* is set in the project), assuming in this later case that the version starts with 'v' (like v1.0.0). Two substitutions are allowed in *archive*: *${version}* for the version, *${name}* for the package name.

**USAGE**
::
  
  drom publish [OPTIONS]

Where options are:


* :code:`--md5`   Use md5 instead of sha256 for checksums

* :code:`--opam-repo DIRECTORY`   Path to local git-managed opam-repository. The path should be absolute. Overwrites the value *opam-repo* from *$HOME/.config/drom/config*


drom run
~~~~~~~~~~

Execute the project


**USAGE**
::
  
  drom run ARGUMENTS [OPTIONS]

Where options are:


* :code:`ARGUMENTS`   Arguments to the command

* :code:`--edition VERSION`   Use this OCaml edition

* :code:`--local`   Create a local switch instead of using a global switch

* :code:`--locked`   (since version 0.2.1) Use .locked file if it exists

* :code:`-p PACKAGE`   Package to run

* :code:`--switch OPAM_SWITCH`   Use global switch SWITCH instead of creating a local switch

* :code:`--upgrade`   Upgrade project files from drom.toml

* :code:`-y` or :code:`--yes`   Reply yes to all questions


drom sphinx
~~~~~~~~~~~~~

Generate documentation using sphinx


**USAGE**
::
  
  drom sphinx [OPTIONS]

Where options are:


* :code:`--edition VERSION`   Use this OCaml edition

* :code:`--local`   Create a local switch instead of using a global switch

* :code:`--locked`   (since version 0.2.1) Use .locked file if it exists

* :code:`--switch OPAM_SWITCH`   Use global switch SWITCH instead of creating a local switch

* :code:`--upgrade`   Upgrade project files from drom.toml

* :code:`--view`   Open a browser on the sphinx documentation

* :code:`-y` or :code:`--yes`   Reply yes to all questions


drom test
~~~~~~~~~~~

Run tests


**USAGE**
::
  
  drom test [OPTIONS]

Where options are:


* :code:`--edition VERSION`   Use this OCaml edition

* :code:`--local`   Create a local switch instead of using a global switch

* :code:`--locked`   (since version 0.2.1) Use .locked file if it exists

* :code:`--switch OPAM_SWITCH`   Use global switch SWITCH instead of creating a local switch

* :code:`--upgrade`   Upgrade project files from drom.toml

* :code:`-y` or :code:`--yes`   Reply yes to all questions


drom tree
~~~~~~~~~~~

Display a tree of dependencies


**USAGE**
::
  
  drom tree [OPTIONS]

Where options are:



drom uninstall
~~~~~~~~~~~~~~~~

Uninstall the project from the project opam switch


**USAGE**
::
  
  drom uninstall [OPTIONS]

Where options are:


* :code:`--edition VERSION`   Use this OCaml edition

* :code:`--local`   Create a local switch instead of using a global switch

* :code:`--locked`   (since version 0.2.1) Use .locked file if it exists

* :code:`--switch OPAM_SWITCH`   Use global switch SWITCH instead of creating a local switch

* :code:`--upgrade`   Upgrade project files from drom.toml

* :code:`-y` or :code:`--yes`   Reply yes to all questions


drom update
~~~~~~~~~~~~~

Update packages in switch


**USAGE**
::
  
  drom update [OPTIONS]

Where options are:


* :code:`--edition VERSION`   Use this OCaml edition

* :code:`--local`   Create a local switch instead of using a global switch

* :code:`--locked`   (since version 0.2.1) Use .locked file if it exists

* :code:`--switch OPAM_SWITCH`   Use global switch SWITCH instead of creating a local switch

* :code:`--upgrade`   Upgrade project files from drom.toml

* :code:`-y` or :code:`--yes`   Reply yes to all questions
