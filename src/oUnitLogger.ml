(*
   Logger for information and various OUnit events.
 *)

open OUnitTypes
open OUnitUtils

type logger = 
    {
      fwrite: event_type -> unit;
      fpos:   unit -> position option;
      fclose: unit -> unit;
    }

let results_style_1_X =
  OUnitConf.make
    "results_style_1_X"
    (fun r -> Arg.Set r)
    ~printer:string_of_bool
    false
    "Use OUnit 1.X results printer."

let string_of_event ev =
  let spf fmt = Printf.sprintf fmt in
  let string_of_result = 
    function
      | RSuccess _      -> "RSuccess _"
      | RFailure (_, _) -> "RFailure _"
      | RError (_, _)   -> "RError _"
      | RSkip (_, _)    -> "RSkip _"
      | RTodo (_, _)    -> "RTodo _"
  in
  let string_of_log_severity =
    function
      | LError   -> "LError"
      | LWarning -> "LWarning"
      | LInfo    -> "LInfo"
  in
    match ev with 
      | GlobalEvent e ->
          begin
            match e with 
              | GConf str  -> spf "GConf %S" str
              | GStart     -> "GStart"
              | GEnd       -> "GEnd"
              | GResults _ -> "GResults"
          end
      | TestEvent e ->
          begin
            match e with 
              | EStart _ ->
                  "EStart _"
              | EEnd _ ->
                  "EEnd _"
              | EResult result ->
                  spf "EResult (%s)" (string_of_result result)
              | ELog (lvl, str) ->
                  spf "ELog (%s, %S)" (string_of_log_severity lvl) str
              | ELogRaw str ->
                  spf "ELogRaw %S" str
          end

let format_event verbose event_type =
  match event_type with
    | GlobalEvent e ->
        begin
          match e with 
            | GConf str ->
                if verbose then
                  str^"\n"
                else
                  ""
            | GStart ->
                if verbose then
                  "Start testing.\n"
                else
                  ""
            | GEnd ->
                if verbose then
                  "End testing.\n"
                else
                  ""
            | GResults (running_time, results, test_case_count) -> 
                let separator1 = String.make (Format.get_margin ()) '=' in
                let separator2 = String.make (Format.get_margin ()) '-' in
                let buf = Buffer.create 1024 in
                let bprintf fmt = Printf.bprintf buf fmt in
                let print_results = 
                  List.iter 
                    (fun (test_result, pos_opt) -> 
                       if results_style_1_X () then
                         begin
                           bprintf "%s\n%s: %s\n\n%s\n%s\n" 
                             separator1 
                             (result_flavour test_result) 
                             (string_of_path (result_path test_result)) 
                             (result_msg test_result) 
                             separator2
                         end
                       else
                         begin
                           bprintf "%s\n" separator1;
                           begin
                             match pos_opt with 
                               | Some pos ->
                                   bprintf "%s\n" (ocaml_position pos)
                               | None ->
                                   ()
                           end;
                           bprintf "Error: %s\n\n" 
                             (string_of_path (result_path test_result));
                           bprintf "%s\n" (result_msg test_result);
                           bprintf "%s\n" separator2;
                         end)
                in
                let filter f = 
                  List.filter (fun (test_result, _) -> f test_result)
                in
                let errors   = filter is_error results in
                let failures = filter is_failure results in
                let skips    = filter is_skip results in
                let todos    = filter is_todo results in

                  if not verbose then
                    bprintf "\n";

                  print_results errors;
                  print_results failures;
                  bprintf "Ran: %d tests in: %.2f seconds.\n" 
                    (List.length results) running_time;

                  (* Print final verdict *)
                  if was_successful (List.rev_map fst results) then 
                    begin
                      if skips = [] then
                        bprintf "OK"
                      else 
                        bprintf "OK: Cases: %d Skip: %d"
                          test_case_count (List.length skips)
                    end
                  else
                    begin
                      bprintf
                        "FAILED: Cases: %d Tried: %d Errors: %d \
                              Failures: %d Skip:%d Todo:%d" 
                        test_case_count (List.length results) 
                        (List.length errors) (List.length failures)
                        (List.length skips) (List.length todos);
                    end;
                  bprintf "\n";
                  Buffer.contents buf
        end

    | TestEvent e ->
        begin
          let string_of_result = 
            if verbose then
              function
                | RSuccess _      -> "ok\n"
                | RFailure (_, _) -> "FAIL\n"
                | RError (_, _)   -> "ERROR\n"
                | RSkip (_, _)    -> "SKIP\n"
                | RTodo (_, _)    -> "TODO\n"
            else
              function
                | RSuccess _      -> "."
                | RFailure (_, _) -> "F"
                | RError (_, _)   -> "E"
                | RSkip (_, _)    -> "S"
                | RTodo (_, _)    -> "T"
          in
            if verbose then
              match e with 
                | EStart p -> 
                    Printf.sprintf "%s start\n" (string_of_path p)
                | EEnd p -> 
                    Printf.sprintf "%s end\n" (string_of_path p)
                | EResult result -> 
                    string_of_result result
                | ELog (lvl, str) ->
                    let prefix = 
                      match lvl with 
                        | LError -> "E"
                        | LWarning -> "W"
                        | LInfo -> "I"
                    in
                      prefix^": "^str
                | ELogRaw str ->
                    str
            else 
              match e with 
                | EStart _ | EEnd _ | ELog _ | ELogRaw _ -> ""
                | EResult result -> string_of_result result
        end

let file_logger fn =
  let chn = open_out fn in
  let line = ref 1 in
  let fwrite ev =
    let str =  format_event true ev in
    String.iter (function '\n' -> incr line | _ -> ()) str;
    output_string chn str;
    flush chn
  in
  let fpos () =
    Some { filename = fn; line = !line }
  in
  let fclose ()= 
    close_out chn
  in
    {
      fwrite = fwrite;
      fpos   = fpos;
      fclose = fclose;
    }


let std_logger verbose =
  let fwrite ev = 
    print_string (format_event verbose ev);
    flush stdout
  in
    {
      fwrite = fwrite;
      fpos   = (fun () -> None);
      fclose = ignore;
    }

let fun_logger fwrite fclose =
  {
    fwrite = (fun ev -> fwrite ev);
    fpos   = (fun () -> None);
    fclose = fclose;
  }

let null_logger =
  {
    fwrite = ignore;
    fpos   = (fun () -> None);
    fclose = ignore;
  }

let report logger ev =
  logger.fwrite ev

let position logger =
  logger.fpos ()

let close logger =
  logger.fclose ()

let combine lst = 
  let rec fpos =
    function
      | logger :: tl ->
          begin
            match position logger with 
              | Some _ as pos ->
                  pos
              | None ->
                  fpos tl
          end
      | [] -> 
          None
  in
    {
      fwrite = 
        (fun ev -> 
           List.iter (fun logger -> report logger ev) lst);
      fpos   = (fun () -> fpos lst);
      fclose = 
        (fun () -> 
           List.iter (fun logger -> close logger) (List.rev lst));
    }

let create output_file_opt verbose logger =
  let std_logger= 
    std_logger verbose 
  in
  let file_logger = 
    match output_file_opt with 
      | Some fn ->
          file_logger fn
      | None ->
          null_logger
  in
    combine [std_logger; file_logger; logger]

let raw_printf logger fmt =
  Printf.ksprintf
    (fun s ->
       logger.fwrite (TestEvent (ELogRaw s)))
    fmt

