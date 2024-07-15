open Drom_lib

let package = {
  Globals.dummy_package with
  name = "foo";
  p_sites = {
    Sites.default with
    sites_lib = [
      {
        sites_spec_dir = "bar";
        sites_spec_root = false;
        sites_spec_exec = true;
        sites_spec_install = [
          {
            install_source = "bar/*";
            install_recursive = false;
            install_destination = "";
          }
        ];
      }
    ];
    sites_share = [
      {
        sites_spec_dir = "www";
        sites_spec_root = false;
        sites_spec_exec = false;
        sites_spec_install = [
          {
            install_source = "javascript";
            install_recursive = true;
            install_destination = "js";
          }
        ];
      };
      {
        sites_spec_dir = "";
        sites_spec_root = true;
        sites_spec_exec = false;
        sites_spec_install = [
          {
            install_source = "index.html";
            install_recursive = false;
            install_destination = "";
          }
        ];
      }
    ]
  }
}

let project = {
  Globals.dummy_project with
  packages = [package];
}

let () =
  let sites = package.p_sites in
  Fmt.pr "Sites (project):@\n%s@." @@
    Sites.to_dune_project sites;
  Fmt.pr "Sites (package):@\n%s@." @@
    Sites.to_dune ~package:package.name sites;
  exit 0
