{
  description = "A Nix-flake-based MkDocs development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    actions-nix = {
      url = "github:nialov/actions.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mkdocs-flake = {
      url = "github:applicative-systems/mkdocs-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    # See https://flake.parts/module-arguments for module arguments
    flake-parts.lib.mkFlake { inherit inputs; } (
      top@{
        config,
        withSystem,
        moduleWithSystem,
        ...
      }:
      {
        imports = [
          inputs.actions-nix.flakeModules.default
          inputs.mkdocs-flake.flakeModules.default
          inputs.pre-commit-hooks.flakeModule
          inputs.treefmt-nix.flakeModule
        ];
        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ];
        perSystem =
          {
            config,
            self',
            inputs',
            pkgs,
            lib,
            ...
          }:
          {
            # https://flake.parts/options/treefmt-nix.html
            # Example: https://github.com/nix-community/buildbot-nix/blob/main/nix/treefmt/flake-module.nix
            treefmt = {
              projectRootFile = "flake.nix";
              settings.global.excludes = [
                ".github/workflows/**"
              ];

              programs.nixfmt.enable = true;
              programs.prettier = {
                enable = true;
                # Use Prettier 2.x for CJK pangu formatting
                package = pkgs.nodePackages.prettier.override {
                  version = "2.8.8";
                  src = pkgs.fetchurl {
                    url = "https://registry.npmjs.org/prettier/-/prettier-2.8.8.tgz";
                    sha512 = "tdN8qQGvNjw4CHbY+XXk0JgCXn9QiF21a55rBe5LJAU+kDyC4WQn4+awm2Xfk2lQMk5fKup9XgzTZtGkjBdP9Q==";
                  };
                };
                settings.editorconfig = true;
              };
            };

            # https://flake.parts/options/git-hooks-nix.html
            # Example: https://github.com/cachix/git-hooks.nix/blob/master/template/flake.nix
            pre-commit.settings.addGcRoot = true;
            pre-commit.settings.hooks = {
              commitizen.enable = true;
              eclint.enable = true;
              editorconfig-checker.enable = true;
              treefmt.enable = true;
              autocorrect = {
                enable = true;
                name = "autocorrect";
                description = "Linter and formatter to help you to improve copywriting, correct spaces, words, and punctuations between CJK (Chinese, Japanese, Korean)";
                package = pkgs.autocorrect;
                entry = "${pkgs.autocorrect}/bin/autocorrect --lint";
                types_or = [ "markdown" ];
              };
            };

            # Equivalent to  inputs'.nixpkgs.legacyPackages.hello;
            # packages.hello = pkgs.hello;

            # Build the docs:
            # `nix build .#documentation`
            # Run in watch mode for live-editing-rebuilding:
            # `nix run .#watch-documentation`
            documentation.mkdocs-root = ./docs;

            # NOTE: You can also use `config.pre-commit.devShell` or `config.treefmt.build.devShell`
            devShells.default = pkgs.mkShell {
              shellHook = ''
                ${config.pre-commit.installationScript}
                echo 1>&2 "Welcome to the development shell!"
              '';
              packages = config.pre-commit.settings.enabledPackages ++ [ config.treefmt.build.wrapper ];
            };
          };
        flake.actions-nix = {
          pre-commit.enable = true;
          defaults.jobs = {
            runs-on = "ubuntu-latest";
            timeout-minutes = 20;
          };
          workflows = {
            ".github/workflows/check.yaml" = {
              name = "Check with flake";
              on = {
                push = { };
                pull_request = { };
              };
              jobs.nix-flake-check = {
                steps = [
                  {
                    uses = "actions/checkout@v4";
                  }
                  {
                    uses = "nixbuild/nix-quick-install-action@v30";
                    # uses = "cachix/install-nix-action@v31";
                  }
                  {
                    name = "Check flake";
                    run = "nix -Lv flake check";
                  }
                ];
              };
            };
            ".github/workflows/mkdocs.yaml" = {
              name = "Build MkDocs";
              on = {
                push = {
                  branches = [ "main" ];
                };
              };
              permissions = {
                contents = "write";
              };
              jobs.mkdocs-ci = {
                steps = [
                  {
                    uses = "actions/checkout@v4";
                  }
                  {
                    uses = "nixbuild/nix-quick-install-action@v30";
                    # uses = "cachix/install-nix-action@v31";
                  }
                  {
                    name = "Build MkDocs static site";
                    run = ''
                      nix build .#documentation
                      mkdir -p site
                      cp -r result/* site/
                    '';
                  }
                  {
                    name = "Commit changes";
                    uses = "EndBug/add-and-commit@v9";
                    "with" = {
                      author_name = "github-actions[bot]";
                      author_email = "anecdote+github-actions[bot]@users.noreply.github.com";
                      message = "[bot] Build MkDocs site";
                      add = "site/";
                    };
                  }
                ];
              };

            };
          };
        };
      }
    );
}
