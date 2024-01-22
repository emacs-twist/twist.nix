{
  bbdb = _: super: {
    files = builtins.removeAttrs super.files [
      "bbdb-notmuch.el"
      "bbdb-vm.el"
      "bbdb-vm-aux.el"
    ];
  };
}
