---
categories:
 - til
date: 2022-12-16T15:27:21.270328
title: HOWTO build a robust CLI application using Cookiecutter, click and Nix
description:  TIL how to build a CLI tool that won't break at next upgrade
---


I don't know about you but usually, when I develop a quick&dirty tool, I usually create one
from scratch in in my `~/projects` folder and then I create a symbolic link within one of my
`$PATH` entries.

Eventually, it will stop working because of broken dependancies, repository renamed or 
worst case: Migrating to a new workstation without bulk importing my `$HOME` folder.

Today, I needed to create [a new tool](https://github.com/nbareil/til-manager) and resisted
copy/pasting and joggling around as usual. Instead, I listened to [James Clear wisdom](https://jamesclear.com/atomic-habits):

> If you’re having trouble changing your habits, the problem isn’t you. The problem is your system. Bad habits repeat themselves not because you don’t want to change, but because you have the wrong system for change.

And the reality is that I had never invested having "*something that works*".

To make it worked, I did three things:
- I finally took the time to learn the minimum vital about [setuptools](https://setuptools.pypa.io/en/latest/) and deploying console applications.
- I [created a cookiecutter template](https://github.com/nbareil/cookiecutter-py-cli) that includes most of the usual suspects (and the new setuptool's skill I learned today). 
  <br /> 
  From now on, when I want to create a new Python CLI tool, it boils down to:
  ```
  $ cd ~/projects/
  $ cookiecutter https://github.com/nbareil/cookiecutter-py-cli
  project_name [Dummy project name]: test tote
  project_slug [test_tote]:
  $ ls test_tote/
  default.nix  pyproject.toml  test_tote.py
  ```

- I added the new tool into my Nix home-manager setup:

  ```
  { config, lib, pkgs, ... }:

  let
    til-manager = pkgs.python3.pkgs.buildPythonPackage rec {
    pname = "til-manager";
    version = "0.0.1";

    format = "pyproject";

    src = pkgs.fetchgit {
        url = "https://github.com/nbareil/til-manager.git";
        rev = "03f0fba023e931dc31b5a793231ab2ea4679e464";
        sha256 = "1g565rkfik16xzk5cf0jwjk97nbj9fpxsg6igaza9ygnx5c05k26";
    };

    buildInputs = [
      pkgs.python3Packages.build
    ];
    propagatedBuildInputs = [
      pkgs.python3Packages.awesome-slugify
      pkgs.python3Packages.jinja2
      pkgs.python3Packages.click
      pkgs.python3Packages.colorama
      pkgs.python3Packages.humanize
    ];
    doCheck = false;
  };

  in {
    ...
    home.packages = [
       ...
       til-manager
    ];
  }

And voila! I now have a functionnal and sustainable system: I am guaranteed
that everything will work on the long term: Dependencies will never be broken,
the CLI tool will always be within my `$PATH` folders as any other application.

