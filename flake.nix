{
  description = "Dependency-free, SBCL-only date/time library with IANA time zone support, inspired by java.time, chrono, and Temporal";

  inputs = {
    # nixos-unstable, not nixpkgs-unstable: it advances only after the NixOS
    # release tests pass, so it is less likely to land a broken build.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # cl-weave is a test-only dependency (see cl-date-kit.asd), so only its
    # source tree is needed here, not its flake outputs.
    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.3.0";
      flake = false;
    };

    # The org-standard "crane for Common Lisp" -- builds ASDF systems, wires
    # up run-tests.lisp-based checks/apps, and extracts .asd metadata, so
    # this flake no longer hand-rolls any of that itself.
    cl-nix-forge = {
      url = "github:nerima-lisp/cl-nix-forge/v0.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      cl-weave,
      cl-nix-forge,
      treefmt-nix,
      ...
    }:
    let
      # x86_64-linux is what CI gates; aarch64-darwin is the development
      # machine. Every per-system output -- packages, checks, apps AND devShells
      # -- comes from this one list, so leaving aarch64-darwin out takes `nix
      # build` and `nix develop` off the development machine as well. That trade
      # was made on 2026-08-01 and reverted on 2026-08-02; aarch64-darwin carries
      # no CI gate, which PACKAGE_STANDARD.md's "systems" section accepts
      # explicitly. aarch64-linux and x86_64-darwin are nobody's verification and
      # are not declared.
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Keep the process-level deadlines consistent across checks and apps.
      testTimeoutSeconds = 120;
      # SB-COVER recompiles the whole project with instrumentation before tests.
      coverageTimeoutSeconds = 900;
      benchmarkTimeoutSeconds = 120;
      # Matches the `timeout --kill-after=10s` every check/app used before
      # cl-nix-forge (whose own mkScriptCheck/mkTestApp default to 30s).
      killAfterSeconds = 10;

      # treefmt drives `nix fmt` and the `checks.<system>.formatting` gate.
      # Scope is Nix only: YAML formatters mangle the GitHub Actions `on:` key
      # and Markdown reformatting would churn the whole docs tree.
      # cl-nix-forge has no formatting story of its own, so this stays exactly
      # as it was.
      treefmtEval = forAllSystems (
        system:
        treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = true;
        }
      );
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          cl = cl-nix-forge.lib.${system};

          # Single source of truth for the package version: the `:version`
          # form in cl-date-kit.asd, read by cl-nix-forge's own .asd lexer
          # instead of a hand-rolled Nix regex.
          version = cl.fromAsdSystem ./cl-date-kit.asd;

          # ALLOWLIST sources (.asd/.lisp only) rather than raw `self`/
          # `cl-weave`, so a working tree with local .fasl/run-tests.lisp
          # leftovers (coverage/, result, ...) cannot change the build's
          # input hash. Both trees are git-ignored already (see
          # .gitignore), so this is belt-and-suspenders on top of that.
          #
          # `lib.fileset` requires an actual `path`-typed value, but both
          # `self` and a non-flake input like `cl-weave` evaluate to a
          # string-like store path (at least whenever the working tree is
          # dirty, which it is on a checkout with in-progress changes) --
          # `/. + "${x}"` is the standard idiom to recover a real `path`
          # from that string.
          toPath = x: /. + builtins.unsafeDiscardStringContext "${x}";
          cl-weave-src = cl.mkLispSource { root = toPath cl-weave; };
          cl-date-kit-src = cl.mkLispSource { root = toPath self; };

          # Read from cl-weave's own .asd, exactly as `version` above is read
          # from ours. Spelling "1.1.0" here as a literal made the input pin
          # and the derivation's version two places to edit, and the flake had
          # no way to notice when they disagreed. Bound out here rather than
          # inside the `rec` below, where `cl-weave` names the derivation being
          # defined rather than the flake input.
          cl-weave-version = cl.fromAsdSystem "${cl-weave}/cl-weave.asd";
        in
        rec {
          cl-weave = cl.lispDerivation {
            lispSystem = "cl-weave";
            src = cl-weave-src;
            version = cl-weave-version;
          };

          cl-date-kit = cl.lispDerivation {
            lispSystem = "cl-date-kit";
            src = cl-date-kit-src;
            inherit version;
            # Only pulled into CL_SOURCE_REGISTRY when doCheck = true, i.e.
            # via `.enableCheck` (see checks.default and devShells.default
            # below) -- the plain package build stays dependency-free, same
            # as `cl-date-kit.asd`'s own `:depends-on ()`.
            lispCheckDependencies = [ cl-weave ];
          };
          default = cl-date-kit;

          # Rendered documentation site (Material for MkDocs). Built fully
          # offline: Material for MkDocs bundles all of its assets, so no
          # network access is required inside the Nix sandbox. --strict
          # (the default) promotes broken links and unlisted pages to build
          # failures.
          docs = cl.mkDocsSite {
            root = ./docs;
            pname = "cl-date-kit-docs";
            inherit version;
            meta = {
              description = "Rendered MkDocs (Material) documentation for cl-date-kit";
              homepage = "https://github.com/nerima-lisp/cl-date-kit";
              license = pkgs.lib.licenses.mit;
            };
          };
        }
      );

      # `nix fmt` entry point.
      formatter = forAllSystems (system: treefmtEval.${system}.config.build.wrapper);

      # Granularity lives here, NOT in extra GitHub Actions jobs.
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          cl = cl-nix-forge.lib.${system};
          clDateKit = self.packages.${system}.cl-date-kit;

          # The time-zone tests read real IANA data through TZDIR rather
          # than a bundled copy (see docs/src/reference/compatibility.md), so the Nix
          # sandbox needs its own zoneinfo tree: nixpkgs' `tzdata` package,
          # not whatever the host happens to have at /usr/share/zoneinfo
          # (which is not visible inside the sandbox anyway).
          #
          # cl-nix-forge's mkScriptCheck has no dedicated "extra env var"
          # argument, so TZDIR is added with `overrideAttrs` after the
          # check derivation is built. `env` is a real mkDerivation
          # argument (exported for every phase, including checkPhase), so
          # this reaches the SBCL process exactly like the hand-written
          # `checks.default` used to.
          tzdir = "${pkgs.tzdata}/share/zoneinfo";
        in
        {
          default =
            (cl.mkScriptCheck {
              drv = clDateKit;
              entryPoint = "run-tests.lisp";
              timeoutSeconds = testTimeoutSeconds;
              inherit killAfterSeconds;
            }).overrideAttrs
              (old: {
                env = (old.env or { }) // {
                  TZDIR = tzdir;
                };
              });

          formatting = treefmtEval.${system}.config.build.check self;

          docs = self.packages.${system}.docs;

          # This catches ASDF/Nix packaging failures that a source-tree test
          # cannot see, such as an omitted system dependency or source file.
          package = self.packages.${system}.cl-date-kit;
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          cl = cl-nix-forge.lib.${system};
          clWeave = self.packages.${system}.cl-weave;
          clDateKit = self.packages.${system}.cl-date-kit;
          tzdir = "${pkgs.tzdata}/share/zoneinfo";

          # CL_SOURCE_REGISTRY for the custom, cl-nix-forge-independent
          # scripts below (coverage, benchmark): cl-weave's built fasls
          # plus this repository's own source, as plain non-recursive
          # `:directory` entries -- both trees have their .asd directly at
          # their root, and cl-nix-forge's own internal `registryPathOf`
          # (lib/core/asdf-derivation.nix, not part of its public API) does
          # exactly this for its own lispDerivation results.
          sourceRegistry = "${clWeave}:${self}";

          isolatedLispEnvironment = ''
            temporary_home="$(mktemp -d "$TMPDIR/cl-date-kit.XXXXXX")"
            trap 'rm -rf "$temporary_home"' EXIT
            export HOME="$temporary_home/home"
            export XDG_CACHE_HOME="$temporary_home/cache"
            mkdir -p "$HOME" "$XDG_CACHE_HOME"
          '';
          isolatedLispCache = ''
            ${isolatedLispEnvironment}
            export ASDF_OUTPUT_TRANSLATIONS="(:output-translations (t (\"$temporary_home/fasl/\" :implementation)) :inherit-configuration)"
            mkdir -p "$temporary_home/fasl"
          '';
          benchmarkScript = pkgs.writeText "cl-date-kit-benchmark.lisp" ''
            (require :asdf)

            (defun benchmark-environment-integer (name default &key allow-zero)
              (let ((value (uiop/os:getenv name)))
                (if value
                    (let ((number
                            (handler-case
                                (parse-integer value :junk-allowed nil)
                              (parse-error ()
                                (error "~A must be a ~:[positive~;non-negative~] integer, got ~S"
                                       name allow-zero value)))))
                      (if (if allow-zero
                              (not (minusp number))
                              (plusp number))
                          number
                          (error "~A must be a ~:[positive~;non-negative~] integer, got ~S"
                                 name allow-zero value)))
                    default)))

            (defun run-operations (iterations thunk)
              (let ((result nil))
                (dotimes (iteration iterations result)
                  (declare (ignore iteration))
                  (setf result (funcall thunk)))))

            (defun measure-sample (iterations thunk)
              (let ((bytes-before (sb-ext:get-bytes-consed))
                    (start (get-internal-real-time)))
                (run-operations iterations thunk)
                (let* ((elapsed-ticks (- (get-internal-real-time) start))
                       (elapsed-seconds (/ elapsed-ticks internal-time-units-per-second))
                       (bytes (- (sb-ext:get-bytes-consed) bytes-before)))
                  (values (* 1000000000d0 (/ elapsed-seconds iterations))
                          (/ bytes iterations)))))

            (defun median (numbers)
              (let* ((sorted (sort (copy-list numbers) #'<))
                     (count (length sorted))
                     (middle (floor count 2)))
                (if (oddp count)
                    (nth middle sorted)
                    (/ (+ (nth (1- middle) sorted) (nth middle sorted)) 2d0))))

            (defun print-statistics (label values unit)
              (format t "  ~A: median ~,1F ~A, min ~,1F, max ~,1F~%"
                      label
                      (median values)
                      unit
                      (reduce #'min values)
                      (reduce #'max values)))

            (defun benchmark-case (name iterations warmup-iterations samples thunk)
              (run-operations warmup-iterations thunk)
              (let ((measurements
                      (loop repeat samples
                            collect (multiple-value-list (measure-sample iterations thunk)))))
                (format t "~A: ~D samples x ~D iterations after ~D warm-up iterations~%"
                        name samples iterations warmup-iterations)
                (print-statistics "ns/op" (mapcar #'first measurements) "ns/op")
                (print-statistics "bytes/op" (mapcar #'second measurements) "bytes/op")
                (finish-output)))

            (let ((iterations
                    (benchmark-environment-integer "CL_DATE_KIT_BENCHMARK_ITERATIONS" 100000))
                  (warmup-iterations
                    (benchmark-environment-integer "CL_DATE_KIT_BENCHMARK_WARMUP_ITERATIONS" 10000
                                                   :allow-zero t))
                  (samples
                    (benchmark-environment-integer "CL_DATE_KIT_BENCHMARK_SAMPLES" 7)))
              (asdf:load-system "cl-date-kit")
              (format t "cl-date-kit benchmarks: ~D samples, ~D iterations, ~D warm-up iterations~%"
                      samples iterations warmup-iterations)
              (finish-output)
              (let* ((find-time-zone
                      (symbol-function (find-symbol "FIND-TIME-ZONE" "CL-DATE-KIT")))
                     (local-date-time-of
                      (symbol-function (find-symbol "LOCAL-DATE-TIME-OF" "CL-DATE-KIT")))
                     (parse-instant
                      (symbol-function (find-symbol "PARSE-INSTANT" "CL-DATE-KIT")))
                     (resolve-local-date-time
                      (symbol-function (find-symbol "RESOLVE-LOCAL-DATE-TIME" "CL-DATE-KIT")))
                     (zoned-date-time-of-local
                      (symbol-function (find-symbol "ZONED-DATE-TIME-OF-LOCAL" "CL-DATE-KIT")))
                     (make-local-date
                      (symbol-function (find-symbol "MAKE-LOCAL-DATE" "CL-DATE-KIT")))
                     (make-rrule
                      (symbol-function (find-symbol "MAKE-RRULE" "CL-DATE-KIT")))
                     (make-rrule-schedule
                      (symbol-function (find-symbol "MAKE-RRULE-SCHEDULE" "CL-DATE-KIT")))
                     (map-rrule-occurrences
                      (symbol-function (find-symbol "MAP-RRULE-OCCURRENCES" "CL-DATE-KIT")))
                     (make-rrule-set
                      (symbol-function (find-symbol "MAKE-RRULE-SET" "CL-DATE-KIT")))
                     (map-rrule-set-occurrences
                      (symbol-function (find-symbol "MAP-RRULE-SET-OCCURRENCES" "CL-DATE-KIT")))
                     (zone (funcall find-time-zone "America/New_York"))
                     (local (funcall local-date-time-of 2024 6 15 12 0 0))
                     (canonical-instant-string "2024-06-15T16:00:00Z")
                     (lowercase-instant-string "2024-06-15t16:00:00z")
                     (offset-instant-string "2024-06-15T12:00:00-04:00")
                    (rrule-set
                      (funcall make-rrule-set
                               :schedules
                               (list (funcall make-rrule-schedule
                                              (funcall make-local-date 2024 1 1)
                                              (funcall make-rrule :frequency :daily :count 8)))))
                     (yearly-rrule-schedule
                      (funcall make-rrule-schedule
                               (funcall make-local-date 2024 1 1)
                               (funcall make-rrule
                                        :frequency :yearly
                                        :count 8
                                        :by-month '(2 3)
                                        :by-month-day '(-1 1 15 31)))))
                (benchmark-case "runner-overhead/no-op" iterations warmup-iterations samples
                                (lambda () nil))
                (benchmark-case "parse-instant/canonical-utc" iterations warmup-iterations samples
                                (lambda () (funcall parse-instant canonical-instant-string)))
                (benchmark-case "parse-instant/lowercase-utc" iterations warmup-iterations samples
                                (lambda () (funcall parse-instant lowercase-instant-string)))
                (benchmark-case "parse-instant/numeric-offset" iterations warmup-iterations samples
                                (lambda () (funcall parse-instant offset-instant-string)))
                (benchmark-case "resolve-local-date-time" iterations warmup-iterations samples
                                (lambda () (funcall resolve-local-date-time local zone)))
                (benchmark-case "zoned-date-time-of-local" iterations warmup-iterations samples
                                (lambda () (funcall zoned-date-time-of-local local zone)))
                (benchmark-case "map-rrule-set-occurrences/no-rdate-no-exdate"
                                iterations warmup-iterations samples
                                (lambda ()
                                  (funcall map-rrule-set-occurrences
                                           (lambda (occurrence)
                                             (declare (ignore occurrence))
                                             t)
                                           rrule-set
                                           :max-periods 8)))
                (benchmark-case "map-rrule-occurrences/yearly-direct"
                                iterations warmup-iterations samples
                                (lambda ()
                                  (funcall map-rrule-occurrences
                                           (lambda (occurrence)
                                             (declare (ignore occurrence))
                                             t)
                                           yearly-rrule-schedule
                                           :max-periods 8))))))
          '';

          # `nix run .#test`: cl-nix-forge's mkTestApp is the org-standard
          # helper for this (it runs the repo's own run-tests.lisp in place,
          # the same PACKAGE_STANDARD.md-mandated entry point mkScriptCheck
          # drives above). It has no extra-environment-variable argument
          # either, so it is wrapped in a thin writeShellApplication that
          # only adds `export TZDIR=...` before exec-ing the app it builds --
          # everything else (CL_SOURCE_REGISTRY, the isolated HOME,
          # timeout -k) stays exactly what mkTestApp already does.
          testApp = cl.mkTestApp {
            pname = "cl-date-kit";
            src = self;
            lispDependencies = [ clWeave ];
            timeoutSeconds = testTimeoutSeconds;
            inherit killAfterSeconds;
            description = "Run the cl-date-kit test suite";
          };
          test = pkgs.writeShellApplication {
            name = "cl-date-kit-test";
            text = ''
              export TZDIR="${tzdir}"
              exec ${testApp.program} "$@"
            '';
          };

          # No cl-nix-forge equivalent: mkCoverageReport (lib/batteries/
          # coverage.nix) is derivation-shaped -- its report always lands at
          # a fixed path under the check's own $out -- so it cannot support
          # `nix run .#coverage -- <caller-chosen-directory>`, which is the
          # documented, argv-driven contract `run-coverage.lisp` and this
          # app already give. run-coverage.lisp's own report-vs-source
          # filtering (`project-source-p`) also has no mkCoverageReport
          # equivalent. Kept as the original hand-written script/app pair.
          coverage = pkgs.writeShellApplication {
            name = "cl-date-kit-coverage";
            runtimeInputs = [
              pkgs.sbcl
              pkgs.coreutils
            ];
            text = ''
              export CL_SOURCE_REGISTRY="${sourceRegistry}"
              export TZDIR="${tzdir}"
              ${isolatedLispCache}
              timeout --kill-after=${toString killAfterSeconds}s ${toString coverageTimeoutSeconds}s sbcl --script ${self}/run-coverage.lisp "$@"
            '';
          };

          # No cl-nix-forge equivalent: this is a bespoke inline benchmark
          # script, not a test or coverage run. `lispScript` was considered,
          # but it has no timeout wrapping and no hook for the
          # CL_DATE_KIT_BENCHMARK_* environment variables this script reads,
          # so a plain writeShellApplication stays the simpler fit.
          benchmark = pkgs.writeShellApplication {
            name = "cl-date-kit-benchmark";
            runtimeInputs = [
              pkgs.sbcl
              pkgs.coreutils
            ];
            text = ''
              # Keep source compilation out of the measured process.
              export CL_SOURCE_REGISTRY="${clDateKit}"
              export TZDIR="${tzdir}"
              ${isolatedLispEnvironment}
              printf '%s\n' 'Loading cl-date-kit benchmark...'
              timeout --kill-after=${toString killAfterSeconds}s ${toString benchmarkTimeoutSeconds}s sbcl --script ${benchmarkScript} "$@"
            '';
          };
        in
        {
          default = {
            type = "app";
            program = "${test}/bin/cl-date-kit-test";
            meta.description = "Run the cl-date-kit test suite";
          };
          test = {
            type = "app";
            program = "${test}/bin/cl-date-kit-test";
            meta.description = "Run the cl-date-kit test suite";
          };
          coverage = {
            type = "app";
            program = "${coverage}/bin/cl-date-kit-coverage";
            meta.description = "Run tests and write an SB-COVER HTML report";
          };
          benchmark = {
            type = "app";
            program = "${benchmark}/bin/cl-date-kit-benchmark";
            meta.description = "Measure cl-date-kit ISO and time-zone hot paths";
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          cl = cl-nix-forge.lib.${system};
          clDateKit = self.packages.${system}.cl-date-kit;
          tzdir = "${pkgs.tzdata}/share/zoneinfo";
        in
        {
          # `.enableCheck` (not the plain package) so cl-weave's
          # lispCheckDependencies are on CL_SOURCE_REGISTRY too, matching
          # the previous shell where cl-weave was always present.
          default =
            (cl.mkDevShell {
              drv = clDateKit.enableCheck;
              extraPackages = [ pkgs.coreutils ];
            }).overrideAttrs
              (old: {
                env = (old.env or { }) // {
                  TZDIR = tzdir;
                };
              });
        }
      );
    };
}
