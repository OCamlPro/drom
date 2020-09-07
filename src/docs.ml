(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let initial_api_doc =
  {|!{:create}
<h1>API documentation for !{name:html}</h1>
<p>You need to run the following commands in the project to generate this doc:
<pre>
make doc
</pre>
or
<pre>
drom doc
</pre>
and then:
<pre>
git add docs/doc
</pre>
</p>
|}

let initial_sphinx_doc =
  {|!{:create}
<h1>Sphinx doc for !{name}</h1>
<p>You need to run the following commands in the project to generate this doc:
<pre>
make sphinx
</pre>
or
<pre>
drom sphinx
</pre>
and then:
<pre>
git add docs/sphinx
</pre>
</p>
|}

let template_README_md =
  {|
!{badge-ci}
!{badge-release}

# !{name}

!{description}

* Website: !{homepage}
* General Documentation: !{doc-gen}
* API Documentation: !{doc-api}
* Sources: !{dev-repo}
|}

let template_CHANGES_md =
  {|
## v0.1.0 ( !{year}-!{month}-!{day} )

* Initial commit
|}

let project_files =
  [ ("CHANGES.md", template_CHANGES_md); ("README.md", template_README_md) ]
  @ Misc.add_skip "docs"
      [
        ("docs/index.html", Sphinx.docs_index_html);
        ("docs/style.css", Sphinx.docs_style_css);
        ("docs/doc/index.html", initial_api_doc);
        ("docs/sphinx/index.html", initial_sphinx_doc);
      ]
