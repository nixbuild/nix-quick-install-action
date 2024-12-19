{ inputs, cell }:
let
  l = pkgs.lib // builtins;
  inherit (inputs.std) lib std;
  inherit (cell) pkgs;
in
rec {
  editorconfig = lib.dev.mkNixago lib.cfg.editorconfig {
    data = {
      root = true;

      "*" = {
        charset = "utf-8";
        end_of_line = "lf";
        indent_size = 8;
        indent_style = "tab";
        insert_final_newline = true;
        trim_trailing_whitespace = true;
      };

      "{*.diff,*.patch,flake.lock}" = {
        end_of_line = "unset";
        indent_size = "unset";
        indent_style = "unset";
        insert_final_newline = "unset";
        trim_trailing_whitespace = "unset";
      };

      "*.json" = {
        indent_size = 2;
        indent_style = "space";
      };

      "*.md" = {
        indent_size = 2;
        indent_style = "space";
        trim_trailing_whitespace = false;
      };

      "*.nix" = {
        indent_size = 2;
        indent_style = "space";
      };

      "*.yaml" = {
        indent_size = 2;
        indent_style = "space";
      };
    };
  };

  statix = lib.dev.mkNixago {
    output = "statix.toml";

    data = {
      disabled = [ ];
      ignore = [ ".direnv" ];
    };
  };

  treefmt = lib.dev.mkNixago lib.cfg.treefmt {

    # NOTE(ttlgcc): Whenever in doubt about how to fix tool conflicts,
    # follow this simple rule: format, then lint.

    # FIXME(ttlgcc): Separate settings per ecosystem.

    data = {
      global = {
        excludes = [
          "nix/*/sources/generated.*"
          "*.diff"
          "*.patch"
          "*.txt"
          "*flake.lock"
        ];
      };

      # All files
      formatter = {
        # https://waterlan.home.xs4all.nl/dos2unix.html
        dos2unix = {
          command = l.getExe' pkgs.dos2unix "dos2unix";
          options = l.cli.toGNUCommandLine { } {
            add-eol = true;
            keepdate = true;
          };
          includes = [ "*" ];
          priority = -10;
        };

        # https://github.com/google/keep-sorted
        keep-sorted = {
          command = l.getExe pkgs.keep-sorted;
          includes = [ "*" ];
          priority = 10;
        };
      };

      # JSON
      formatter = {
        # https://github.com/caarlos0/jsonfmt
        jsonfmt = {
          command = l.getExe pkgs.jsonfmt;
          options = l.cli.toGNUCommandLine { } {
            w = true;
          };
          includes = [ "*.json" ];
          excludes = [ "*release-please-manifest.json" ];
        };
      };

      # Markdown
      formatter = {
        # https://zimbatm.github.io/mdsh/
        mdsh = {
          command = l.getExe pkgs.mdsh;
          options = l.cli.toGNUCommandLine { } {
            inputs = true;
          };
          includes = [ "README.md" ];
          priority = -1;
        };

        # https://mdformat.readthedocs.io
        # FIXME(ttlgcc): Install plugins.
        mdformat = {
          command = l.getExe pkgs.python3Packages.mdformat;
          includes = [ "*.md" ];
          excludes = [ "CHANGELOG.md" ];
        };
      };

      # Nix
      formatter = {
        # https://github.com/astro/deadnix
        deadnix = {
          command = l.getExe pkgs.deadnix;
          options = [ "--edit" ];
          includes = [ "*.nix" ];
          priority = -1;
        };

        # https://github.com/NixOS/nixfmt
        nixfmt = {
          command = l.getExe pkgs.nixfmt-rfc-style;
          includes = [ "*.nix" ];
        };

        statix = {
          command = l.getExe (
            pkgs.writeShellScriptBin "statix-fix" ''
              for file in "''$@"
              do
                '${l.getExe pkgs.statix}' fix --config '${statix.configFile}' "''$file"
              done
            ''
          );
          includes = [ "*.nix" ];
          priority = 1;
        };
      };

      # Ruby
      formatter = {
        # https://docs.rubocop.org
        rubocop = {
          command = l.getExe pkgs.rubocop;
          includes = [ "*Brewfile" ];
        };
      };

      # Sh
      formatter = {
        # https://www.shellcheck.net/wiki/Home
        shellcheck = {
          command = l.getExe pkgs.shellcheck;
          includes = [
            "*.bash"
            "*.sh"
            # direnv
            "*.envrc"
            "*.envrc.*"
          ];
          priority = 1;
        };

        # https://github.com/mvdan/sh#shfmt
        shfmt = {
          command = l.getExe pkgs.shfmt;
          options = [
            "--binary-next-line"
            "--simplify"
            "--write"
          ];
          includes = [
            "*.bash"
            "*.sh"
            # direnv
            "*.envrc"
            "*.envrc.*"
          ];
        };
      };

      # YAML
      formatter = {
        # https://github.com/google/yamlfmt/
        yamlfmt = {
          command = l.getExe pkgs.yamlfmt;
          options = [ "-conf=${yamlfmt.configFile}" ];
          includes = [ "*.yaml" ];
        };
      };
    };
  };

  yamlfmt = lib.dev.mkNixago {
    output = "yamlfmt.yaml";

    data = {
      line_ending = "lf";
      gitignore_excludes = true;
      formatter = {
        type = "basic";
        include_document_start = true;
        scan_folded_as_literal = true;
        trim_trailing_whitespace = true;
        eof_newline = true;
      };
    };
  };
}
