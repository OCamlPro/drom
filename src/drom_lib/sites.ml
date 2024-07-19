(**************************************************************************)
(*                                                                        *)
(*    Copyright 2024 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)


type t = Types.sites
[@@deriving
  show,
  protocol ~driver:(module Protocol.Toml),
  protocol ~driver:(module Protocol.Jinja2)]

let default = Types.{
  sites_name = default_sites_name;
  sites_lib = default_sites_lib;
  sites_bin = default_sites_bin;
  sites_sbin = default_sites_sbin;
  sites_toplevel = default_sites_toplevel;
  sites_share = default_sites_share;
  sites_etc = default_sites_etc;
  sites_stublibs = default_sites_stublibs;
  sites_doc = default_sites_doc;
  sites_man = default_sites_man;
}

let rec eztoml_value_to_otoml = function
  | EzToml.TYPES.TBool b -> Otoml.boolean b
  | EzToml.TYPES.TInt i -> Otoml.integer i
  | EzToml.TYPES.TFloat f -> Otoml.float f
  | EzToml.TYPES.TString s -> Otoml.string s
  | EzToml.TYPES.TArray a -> Otoml.array (eztoml_array_to_otoml a)
  | EzToml.TYPES.TTable a ->
    EzToml.TYPES.Table.bindings a |>
    List.map (fun (k, v) ->
      (EzToml.TYPES.Table.Key.to_string k, eztoml_value_to_otoml v)) |>
    Otoml.table
  | EzToml.TYPES.TDate d -> Otoml.float d

and eztoml_array_to_otoml = function
  | EzToml.TYPES.NodeEmpty -> []
  | EzToml.TYPES.NodeBool l -> List.map (fun b -> Otoml.boolean b) l
  | EzToml.TYPES.NodeInt l -> List.map (fun i -> Otoml.integer i) l
  | EzToml.TYPES.NodeFloat l -> List.map (fun f -> Otoml.float f) l
  | EzToml.TYPES.NodeString l -> List.map (fun s -> Otoml.string s) l
  | EzToml.TYPES.NodeDate l -> List.map (fun d -> Otoml.float d) l
  | EzToml.TYPES.NodeArray l ->
    List.map (fun a -> Otoml.array (eztoml_array_to_otoml a)) l
  | EzToml.TYPES.NodeTable l ->
    List.map (fun t -> eztoml_value_to_otoml (EzToml.TYPES.TTable t)) l

let of_eztoml toml =
  eztoml_value_to_otoml toml |> of_toml_exn

(* This template should be externalized with the whole dune-project template
   but it needs:
   - refactoring the whole drom templating strategy
   - await a bump for next version so that site generation would be
     available for drom itself. *)
let project_template = {|
  (sites{# lib #}
    {% for spec in sites.lib -%}
      {# if no dir, no declaration is needed #}
      {%- if spec.dir != "" -%}
        {%- if spec.exec -%}
          {%- if spec.root -%}
            (libexec_root {{ spec.dir }})
          {%- else -%}
            (libexec {{ spec.dir }})
          {%- endif -%}
        {%- else -%}
          {% if spec.root -%}
            (lib_root {{ spec.dir }})
          {% else -%}
            (lib {{ spec.dir }})
          {%- endif -%}
        {%- endif -%}
      {%- endif -%}
    {%- endfor -%}

    {# bin #}
    {%- for spec in sites.bin -%}
      {# if no dir, no declaration is needed #}
      {% if spec.dir != "" %}(bin {{ spec.dir }}){% endif %}
    {%- endfor -%}

    {# sbin #}
    {%- for spec in sites.sbin -%}
      {# if no dir, no declaration is needed #}
      {% if spec.dir != "" %}(sbin {{ spec.dir }}){% endif %}
    {%- endfor -%}

    {# toplevel #}
    {%- for spec in sites.toplevel -%}
      {# if no dir, no declaration is needed #}
      {% if spec.dir != "" %}(toplevel {{ spec.dir }}){% endif %}
    {%- endfor -%}

    {# share #}
    {%- for spec in sites.share -%}
      {# if no dir, no declaration is needed #}
      {%- if spec.dir != "" %}
        {%- if spec.root -%}
          (share_root {{ spec.dir }})
        {%- else -%}
          (share {{ spec.dir }})
        {%- endif -%}
      {%- endif -%}
    {%- endfor -%}

    {# etc #}
    {%- for spec in sites.etc -%}
      {# if no dir, no declaration is needed #}
      {% if spec.dir != "" %}(etc {{ spec.dir }}){% endif -%}
    {%- endfor -%}

    {# stublibs #}
    {%- for spec in sites.stublibs -%}
      {# if no dir, no declaration is needed #}
      {% if spec.dir != "" %}(stublibs {{ spec.dir }}){% endif -%}
    {%- endfor -%}

    {# doc #}
    {%- for spec in sites.doc -%}
      {# if no dir, no declaration is needed #}
      {% if spec.dir != "" %}(doc {{ spec.dir }}){% endif -%}
    {%- endfor %}
  )
|}

let to_dune_project t =
  let model = to_jinja2 t in
  let res = Jingoo.Jg_template.from_string project_template ~models:[
    "sites", model;
  ] in
  res

let package_template = {|
(generate_sites_module
  (module {{ sites.name }})
  (sites {{ package }}))

{% macro install_stanza (site_spec, install_spec, package, section) %}
(install{# #}
{%- if install_spec.source | contains("*") -%}{# this is a glob pattern #}
  (files
    (glob_files{%- if install_spec.recursive %}_rec{% endif %}
      {{ install_spec.source }}{# #}
      {%- if install_spec.destination != '' -%}
        with_prefix {{ install_spec.destination }}
      {%- endif %}
    )
  )
{%- elseif install_spec.recursive -%}{# this is a whole directory #}
  (source_trees
    {% if install_spec.destination == '' -%}
      {{ install_spec.source }}
    {%- else -%}
      ({{ install_spec.source }} as {{ install_spec.destination }})
    {%- endif %}
  )
{%- else -%}{# this is a simple file #}
  (files
    {% if install_spec.destination == '' -%}
      {{ install_spec.source }}
    {%- else -%}
      ({{ install_spec.source }} as {{ install_spec.destination }})
    {%- endif %}
  )
{%- endif %}
  (section
    {% if site_spec.dir != '' -%}
      (site ({{ package }} {{ spec.dir }}))
    {%- else -%}
      {{ section }}
    {%- endif %}
  )
  (package {{ package }})
)
{% endmacro -%}

{%- function section (spec, root) -%}
  {% set res = root %}
  {% if root == 'lib' -%}
    {% if spec.exec -%}{% set res += 'exec' %}{% endif -%}
    {% if spec.root -%}{% set res += '_root' %}{% endif -%}
    {{ res }}
  {%- elif root == 'share' -%}h
    {% if spec.root -%}{% set res += '_root' %}{% endif -%}
  {%- endif -%}
  {{ res }}
{%- endfunction -%}

{% for spec in sites.lib -%}
  {%- for install in spec.install -%}
    {{ install_stanza (spec, install, package, section (spec, 'lib')) }}
  {%- endfor -%}
{%- endfor -%}
{%- for spec in sites.bin -%}
  {%- for install in spec.install -%}
    {{ install_stanza(spec, install, package, section(spec, 'bin')) }}
  {%- endfor -%}
{%- endfor -%}
{%- for spec in sites.sbin -%}
  {%- for install in spec.install -%}
    {{ install_stanza(spec, install, package, section(spec, 'sbin')) }}
  {%- endfor -%}
{%- endfor -%}
{%- for spec in sites.toplevel -%}
  {%- for install in spec.install -%}
    {{ install_stanza(spec, install, package, section(spec, 'toplevel')) }}
  {%- endfor -%}
{%- endfor -%}
{%- for spec in sites.share -%}
  {%- for install in spec.install -%}
    {{ install_stanza(spec, install, package, section(spec, 'share')) }}
  {%- endfor -%}
{%- endfor -%}
{%- for spec in sites.etc -%}
  {%- for install in spec.install -%}
    {{ install_stanza(spec, install, package, section(spec, 'etc')) }}
  {%- endfor -%}
{%- endfor -%}
{%- for spec in sites.stublibs -%}
  {%- for install in spec.install -%}
    {{ install_stanza(spec, install, package, section(spec, 'stublibs')) }}
  {%- endfor -%}
{%- endfor -%}
{%- for spec in sites.doc -%}
  {%- for install in spec.install -%}
    {{ install_stanza(spec, install, package, section(spec, 'doc')) }}
  {%- endfor -%}
{%- endfor -%}
{%- for spec in sites.man -%}
  {%- for install in spec.install -%}
    {{ install_stanza(spec, install, package, section(spec, 'man')) }}
  {%- endfor -%}
{%- endfor -%}
|}


(* A regexp matcher to be used as filter. *)
let contains ?kwargs:_ pattern_value string_value  =
  try
    let p = Jingoo.Jg_types.unbox_string pattern_value in
    let s = Jingoo.Jg_types.unbox_string string_value in
    let re = Str.regexp p in
    ignore (Str.search_forward re s 0);
    Jingoo.Jg_types.box_bool true
  with _ ->
    Jingoo.Jg_types.box_bool false


let to_dune ~package t =
  let t_model = to_jinja2 t in
  let p_model = Protocol.Jinja2.of_string package in
  let res =
    Jingoo.Jg_template.from_string package_template
    ~env:Jingoo.Jg_types.{
      std_env with
      filters = [
        "contains", func_arg2 contains;
      ];
    }
    ~models:[
      "sites", t_model;
      "package", p_model;
    ] in
  res