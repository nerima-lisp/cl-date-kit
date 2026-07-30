{
  description = "Dependency-free, SBCL-only date/time library with IANA time zone support, inspired by java.time, chrono, and Temporal";

  inputs = {
    # nixos-unstable, not nixpkgs-unstable: it advances only after the NixOS
    # release tests pass, so it is less likely to land a broken build.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # cl-weave is a test-only dependency (see cl-date-kit.asd), so only its
    # source tree is needed here, not its flake outputs.
    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.1.0";
      flake = false;
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
      treefmt-nix,
      ...
    }:
    let
      # The CI matrix verifies each advertised platform.
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # CL_SOURCE_REGISTRY for environments that need cl-weave.  Callers pass
      # its packaged output so ASDF can reuse its compiled FASLs rather than
      # rebuilding the test framework for every isolated test run.
      sourceRegistry = clWeave: "${clWeave}//:${self}//";

      # Keep the process-level deadlines consistent across checks and apps.
      testTimeoutSeconds = 120;
      # SB-COVER recompiles the whole project with instrumentation before tests.
      coverageTimeoutSeconds = 900;
      benchmarkTimeoutSeconds = 120;

      # Single source of truth for the package version: the `:version` form
      # in cl-date-kit.asd. Nix regexes are whole-string anchored and `.`
      # never spans newlines, so the version is extracted from its containing
      # line without imposing a particular ASDF formatting layout.
      version =
        let
          lines = nixpkgs.lib.splitString "\n" (builtins.readFile ./cl-date-kit.asd);
          versionLine = builtins.head (
            builtins.filter (line: builtins.match ".*:version \"[^\"]*\".*" line != null) lines
          );
        in
        builtins.head (builtins.match ".*:version \"([^\"]*)\".*" versionLine);

      # treefmt drives `nix fmt` and the `checks.<system>.formatting` gate.
      # Scope is Nix only: YAML formatters mangle the GitHub Actions `on:` key
      # and Markdown reformatting would churn the whole docs tree.
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
        in
        rec {
          cl-weave = pkgs.sbcl.buildASDFSystem {
            pname = "cl-weave";
          version = "1.1.0";
            src = inputs.cl-weave;
            systems = [ "cl-weave" ];
          };

          cl-date-kit = pkgs.sbcl.buildASDFSystem {
            pname = "cl-date-kit";
            inherit version;
            src = self;
            systems = [ "cl-date-kit" ];
          };
          default = cl-date-kit;

          # Rendered documentation site (Material for MkDocs). Built fully
          # offline: Material for MkDocs bundles all of its assets, so no
          # network access is required inside the Nix sandbox. --strict
          # promotes broken links and unlisted pages to build failures.
          docs = pkgs.stdenvNoCC.mkDerivation {
            pname = "cl-date-kit-docs";
            inherit version;
            src = pkgs.lib.fileset.toSource {
              root = ./docs;
              fileset = pkgs.lib.fileset.unions [
                ./docs/mkdocs.yml
                ./docs/src
              ];
            };
            nativeBuildInputs = [ pkgs.python3Packages.mkdocs-material ];
            buildPhase = ''
              runHook preBuild
              mkdocs build --strict --config-file mkdocs.yml --site-dir "$out"
              runHook postBuild
            '';
            dontInstall = true;
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
          clWeave = self.packages.${system}.cl-weave;
        in
        {
          default =
            pkgs.runCommand "cl-date-kit-tests"
              {
                nativeBuildInputs = [
                  pkgs.sbcl
                  pkgs.coreutils
                  clWeave
                ];
                CL_SOURCE_REGISTRY = sourceRegistry clWeave;
                # The time-zone tests read real IANA data through TZDIR
                # rather than a bundled copy (see docs/src/compatibility.md),
                # so the Nix sandbox needs its own zoneinfo tree: nixpkgs'
                # `tzdata` package, not whatever the host happens to have at
                # /usr/share/zoneinfo (which is not visible inside the
                # sandbox anyway).
                TZDIR = "${pkgs.tzdata}/share/zoneinfo";
              }
              ''
                export HOME="$TMPDIR/home"
                mkdir -p "$HOME" "$out"
                timeout --kill-after=10s ${toString testTimeoutSeconds}s sbcl --script ${self}/run-tests.lisp
                touch "$out/passed"
              '';

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
          clWeave = self.packages.${system}.cl-weave;
          clDateKit = self.packages.${system}.cl-date-kit;
          isolatedLispEnvironment = ''
            temporary_home="$(mktemp -d "$TMPDIR/cl-date-kit.XXXXXX")"
            trap 'rm -rf "$temporary_home"' EXIT
            export HOME="$temporary_home/home"
            export XDG_CACHE_HOME="$temporary_home/cache"
            mkdir -p "$HOME" "$XDG_CACHE_HOME"
          '';
          isolatedLispCache = ''
            ${isolatedLispEnvironment}
            export ASDF_OUTPUT_TRANSLATIONS="(:output-translations (t \"$temporary_home/fasl/\" :implementation) :inherit-configuration)"
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
          test = pkgs.writeShellApplication {
            name = "cl-date-kit-test";
            runtimeInputs = [
              pkgs.sbcl
              pkgs.coreutils
              clWeave
            ];
            text = ''
              export CL_SOURCE_REGISTRY="${sourceRegistry clWeave}"
              export TZDIR="${pkgs.tzdata}/share/zoneinfo"
              ${isolatedLispCache}
              timeout --kill-after=10s ${toString testTimeoutSeconds}s sbcl --script ${self}/run-tests.lisp
            '';
          };
          coverage = pkgs.writeShellApplication {
            name = "cl-date-kit-coverage";
            runtimeInputs = [
              pkgs.sbcl
              pkgs.coreutils
              clWeave
            ];
            text = ''
              export CL_SOURCE_REGISTRY="${sourceRegistry clWeave}"
              export TZDIR="${pkgs.tzdata}/share/zoneinfo"
              ${isolatedLispCache}
              timeout --kill-after=10s ${toString coverageTimeoutSeconds}s sbcl --script ${self}/run-coverage.lisp "$@"
            '';
          };
          benchmark = pkgs.writeShellApplication {
            name = "cl-date-kit-benchmark";
            runtimeInputs = [
              pkgs.sbcl
              pkgs.coreutils
            ];
            text = ''
              # Keep source compilation out of the measured process.
              export CL_SOURCE_REGISTRY="${clDateKit}//"
              export TZDIR="${pkgs.tzdata}/share/zoneinfo"
              ${isolatedLispEnvironment}
              printf '%s\n' 'Loading cl-date-kit benchmark...'
              timeout --kill-after=10s ${toString benchmarkTimeoutSeconds}s sbcl --script ${benchmarkScript} "$@"
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
          clWeave = self.packages.${system}.cl-weave;
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.sbcl
              pkgs.coreutils
              clWeave
            ];
            CL_SOURCE_REGISTRY = sourceRegistry clWeave;
            TZDIR = "${pkgs.tzdata}/share/zoneinfo";
          };
        }
      );
    };
}
