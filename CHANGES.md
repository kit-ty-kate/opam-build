v0.2.0 (25/02/2024)
-------------------

- Upgrade to opam 2.2
- Upgrade to cmdliner 1.1
- Now requires the xdg library
- Now requires OCaml >= 5.1
- Improve performance
- Add a new --global and --local command line argument to signify whether to use a local switch or a global switch
- Add a new config file storing the user preference and which kind of switch to use by default
- Remove the command line directory argument
- Fix building unreleased packages in local mode
- Do not show the "No invariant was set..." warning when creating a local switch
- Document the tools and command line arguments in --help

v0.1.0 (22/11/2021)
-------------------

- A simple project with two plugins:
  - opam-build: which builds any project easily with just one command: opam build. The command will setup a local switch and install all the required dependencies.
  - opam-test: which does the same thing as opam-build but runs the tests on top of it. It also circumvents issues with cyclic test dependencies in opam (where the tests require a package that needs the library it is trying to test). Such cyclic dependency is present in packages such as odoc or base. See https://github.com/ocaml/opam/issues/4594
