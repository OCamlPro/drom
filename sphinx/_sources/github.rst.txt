
Github Projects
===============

:code:`drom` has builtins to ease the deployment of your project on
`Github <https://github.com>__`.

To configure your account, edit the file
:code:`$HOME/.config/drom/config` and setup the
:code:`github-organization` field. Every project that will be created
now will contain this organization.

Every project description contains a field
:code:`github-organization`. If you have configured your account, this
field will automatically be initializaed with your account value. You
may also edit it directly.

If the field :code:`github-organization` is not set in your project
description, and you set it in your account configuration, you can use
the following command to update it::

  $ drom project --upgrade
  Updating file drom.toml
  Calling git add .drom drom.toml

For Github projects, :code:`drom` will automatically:

* Generate a :code:`README.md` file with badges for the CI and the releases
* Infer most links, i.e. documentation on Github Pages, development
  repository, issue tracker, release archives, to put in :code:`opam`
  files and in the documentation
* Use Github Actions to generate documentation and copy it in the
  :code:`gh-pages` branch, compatible with Github Pages
* Configure the project to use Github Actions for the CI,
  i.e. :code:`.github/workflows` files

Once you have created your project and pushed it on Github, the only
necessary step is to activate Github Pages. For that:

* go in your project settings on Github
* scroll down to the Github Pages section
* For the Source field, select the :code:`gh-pages` branch
* Keep  the "/ (root)" directory
* Click on the Save button

Your project should appear a few minutes later on Github Pages.

  
