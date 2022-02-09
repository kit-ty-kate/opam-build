opam-build and opam-test are two opam plugins:
  - opam-build: builds any project easily with just one command: opam build. The command will setup a local switch and install all the required dependencies.
  - opam-test: does the same thing as opam-build but runs the tests on top of it. It also circumvents issues with cyclic test dependencies in opam (where the tests require a package that needs the library it is trying to test). Such cyclic dependency is present in packages such as odoc or base. See https://github.com/ocaml/opam/issues/4594

To install it, simply call:
```
$ opam install opam-build
```
Then to use it, in the directory you want to build, simply call:
```
$ opam build
```

I hope these plugins help beginners have a more straighforward experience with OCaml.
