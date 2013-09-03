(***********************************************************************)
(* The OUnit library                                                   *)
(*                                                                     *)
(* Copyright (C) 2002-2008 Maas-Maarten Zeeman.                        *)
(* Copyright (C) 2010 OCamlCore SARL                                   *)
(*                                                                     *)
(* See LICENSE for details.                                            *)
(***********************************************************************)

open OUnitUtils
open OUnitTypes

(* Plugin initialisation. *)
open OUnitRunnerProcesses

(*
 * Types and global states.
 *)

(* Run all tests, report starts, errors, failures, and return the results *)
let perform_test conf runner chooser logger test =
  let rec flatten_test path acc =
    function
      | TestCase(f) ->
          (path, f) :: acc

      | TestList (tests) ->
          fold_lefti
            (fun acc t cnt ->
               flatten_test
                 ((ListItem cnt)::path)
                 acc t)
            acc tests
      | TestLabel (label, t) ->
          flatten_test ((Label label)::path) acc t
  in
  let test_cases =
    List.rev (flatten_test [] [] test)
  in
    runner conf logger chooser test_cases

(* A simple (currently too simple) text based test runner *)
let run_test_tt conf runner chooser test =
  let () =
    Printexc.record_backtrace true
  in

  let logger =
    OUnitLogger.combine
      [
        OUnitLogger.create conf;
        OUnitLoggerHTML.create conf;
        OUnitLoggerJUnit.create conf;
      ]
  in

  let () =
    (* TODO: move into perform test. *)
    List.iter
      (fun (k, v) ->
         OUnitLogger.report logger
           (OUnitTypes.GlobalEvent
              (OUnitTypes.GConf (k, v))))
      (OUnitConf.dump conf)
  in

  (* Now start the test *)
  let running_time, test_results =
    time_fun
      (perform_test conf runner chooser logger)
      test
  in

    (* TODO: move into perform test. *)
    (* Print test report *)
    OUnitLogger.report logger
      (GlobalEvent
         (GResults (running_time,
                    test_results,
                    OUnitTest.test_case_count test)));

    (* Reset logger. *)
    OUnitLogger.close logger;

    (* Return the results possibly for further processing *)
    test_results

(* Test-only override. *)
let run_test_tt_main_conf = ref OUnitConf.load

(* Call this one to act as your main() function. *)
let run_test_tt_main ?(exit=Pervasives.exit) suite =
  let only_test = ref [] in
  let list_test = ref false in
  let extra_specs =
    [
      "-only-test",
      Arg.String (fun str -> only_test := str :: !only_test),
      "path Run only the selected tests.";

      "-list-test",
      Arg.Set list_test,
      " List tests";
    ]
  in
  let conf = !run_test_tt_main_conf extra_specs in
    if !list_test then
      begin
        List.iter
          (fun pth -> print_endline (OUnitTest.string_of_path pth))
          (OUnitTest.test_case_paths suite)
      end
    else
      begin
        let nsuite =
          if !only_test = [] then
            suite
          else
            begin
              match OUnitTest.test_filter ~skip:true !only_test suite with
                | Some test ->
                    test
                | None ->
                    failwith
                      (Printf.sprintf
                         "Filtering test %s lead to no tests."
                         (String.concat ", " !only_test))
            end
        in

        let test_results =
          run_test_tt
            conf
            (OUnitRunner.choice conf)
            (OUnitChooser.choice conf)
            nsuite
        in
          if not (OUnitResultSummary.was_successful test_results) then
            exit 1
      end

let conf_make name ?arg_string ?alternates ~printer fspec default help =
  let f =
    OUnitConf.make name ?arg_string ?alternates ~printer fspec default help
  in
    (fun ctxt -> f ctxt.conf)
