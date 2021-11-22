v0.1.0 (22/11/2021)
-------------------

- A simple project with two plugins:
  - opam-build: which builds any project easily with just one command: opam build. The command will setup a local switch and install all the required dependencies.
  - opam-test: which does the same thing as opam-build but runs the tests on top of it. It also circumvents issues with cyclic test dependencies in opam (where the tests require a package that needs the library it is trying to test). Such cyclic dependency is present in packages such as odoc or base. See https://github.com/ocaml/opam/issues/4594
