(final: prev: {
      replaceVarsWith = args:
        let
          result = prev.replaceVarsWith args;
        in
        if (args.name or "") == "systemd-boot" && (args.dir or "") == "bin"
        then result.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.patch ];
          postInstall = (old.postInstall or "") + ''
            patch --batch --fuzz=0 "$out/bin/systemd-boot" < ${./systemd-boot-mixed-generations.patch}
          '';
        })
        else result;
    })
