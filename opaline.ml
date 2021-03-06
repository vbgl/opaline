open OpamParserTypes

exception No_install_file
exception No_package_name
exception File_nonexistent of string
exception Install_error of int * string

let files = ref [];;
let pkg_name = ref "";;
let destdir = ref "";;
let prefix = ref "";;
let libdir = ref "";;
let bindir = ref "";;
let sbindir = ref "";;
let topleveldir = ref "";;
let sharedir = ref "";;
let share_rootdir = ref "";;
let etcdir = ref "";;
let docdir = ref "";;
let stublibsdir = ref "";;
let mandir = ref "";;
let install_cmd = ref "install -m 0644";;
let exec_install_cmd = ref "install -m 0755";;

let arg_list =
  [
    "-name", Arg.String (fun s -> pkg_name := s), "Package name";
    "-destdir", Arg.String (fun s -> destdir := s), "Prepend this to all installation paths";
    "-prefix", Arg.String (fun s -> prefix := s), "Directory prefix";
    "-libdir", Arg.String (fun s -> libdir := s), "Directory to install files from the lib and libexec sections";
    "-bindir", Arg.String (fun s -> bindir := s), "Directory to install files from the bin section";
    "-sbindir", Arg.String (fun s -> sbindir := s), "Directory to install files from the sbin section";
    "-topleveldir", Arg.String (fun s -> topleveldir := s), "Directory to install files from the toplevel section";
    "-sharedir", Arg.String (fun s -> sharedir := s), "Directory to install files from the share section";
    "-share_rootdir", Arg.String (fun s -> share_rootdir := s), "Directory to install files from the share_root section";
    "-etcdir", Arg.String (fun s -> etcdir := s), "Directory to install files from the etc section";
    "-docdir", Arg.String (fun s -> docdir := s), "Directory to install files from the doc section";
    "-stublibsdir", Arg.String (fun s -> stublibsdir := s), "Directory to install files from the stublibs section";
    "-mandir", Arg.String (fun s -> mandir := s), "Directory to install files from the man section";
    "-install-cmd", Arg.String (fun s -> install_cmd := s), "Install command";
    "-exec-install-cmd", Arg.String (fun s -> exec_install_cmd := s), "Install command";
  ]
;; 

let filename_concat l =
  let rec fc_aux res = function
  | [] -> res
  | h::t -> fc_aux (Filename.concat res h) t
  in
    fc_aux "" l
;;

let install_file ?(exec=false) ?(man=false) dir src dst =
	let (src, optional) =
		if src.[0] = '?' then
			(String.sub src 1 (String.length src - 1), true)
		else
			(src, false) in
  let path =
    match dst with
    | None ->
        let fname = Filename.basename src in
          if man then
            let ext = Filename.extension fname in
            filename_concat [!destdir; dir; Printf.sprintf "man%s" (String.sub ext 1 (String.length ext - 1)); fname]
          else
            filename_concat [!destdir; dir; fname]
    | Some d -> filename_concat [!destdir; dir; d]
  in
  ignore (Sys.command (Printf.sprintf "mkdir -p %s" (Filename.dirname path)));
	(try
		Unix.access src [R_OK; F_OK]
	with
		Unix.Unix_error _ -> raise (File_nonexistent src));
  let ret = if exec then
   	 Sys.command (Printf.sprintf "%s %s %s" !exec_install_cmd src path)
  else
   	 Sys.command (Printf.sprintf "%s %s %s" !install_cmd src path) in
	if ret = 0 then
		()
	else
		raise (Install_error (ret, src))
;;

let do_install ~section ~src ?dst () =
  if section = "lib" then
    install_file !libdir src dst
  else if section = "libexec" then
    install_file ~exec:true !libdir src dst
  else if section = "bin" then
    install_file ~exec:true !bindir src dst
  else if section = "sbin" then
    install_file ~exec:true !sbindir src dst
  else if section = "toplevel" then
    install_file !topleveldir src dst
  else if section = "share" then
    install_file !sharedir src dst
  else if section = "share_root" then
    install_file !share_rootdir src dst
  else if section = "etc" then
    install_file !etcdir src dst
  else if section = "doc" then
    install_file !docdir src dst
  else if section = "stublibs" then
    install_file ~exec:true !stublibsdir src dst
  else if section = "man" then
    install_file ~man:true !mandir src dst
  else if section = "misc" then
    install_file "/" src dst 
  else
    raise No_install_file
;;

let install_section name files =
  match files with
  | List (_, l) -> List.iter (function
    | Option (_, String (_, src), [String (_, dst)]) -> do_install ~section:name ~src ~dst ()
    | String (_, src) -> do_install ~section:name ~src ()
    | _ -> raise No_install_file
    ) l 
  | _ -> raise No_install_file
;;

let _ =
  Arg.parse arg_list (fun s -> files := s::!files) "Usage: opaline [arguments] <install-file>";
  files := List.rev !files;
  if !pkg_name = "" then
    raise No_package_name;
  if !libdir = "" then
    libdir := filename_concat [!prefix; "lib"; !pkg_name];
  if !bindir = "" then
    bindir := Filename.concat !prefix "bin";
  if !sbindir = "" then
    sbindir := Filename.concat !prefix "sbin";
  if !topleveldir = "" then
    topleveldir := Filename.concat !prefix "lib/toplevel";
  if !sharedir = "" then
    sharedir := filename_concat [!prefix; "share"; !pkg_name];
  if !share_rootdir = "" then
    share_rootdir := Filename.concat !prefix "share";
  if !etcdir = "" then
    etcdir := filename_concat [!prefix; "etc"; !pkg_name];
  if !docdir = "" then
    docdir := filename_concat [!prefix; "doc"; !pkg_name];
  if !stublibsdir = "" then
    stublibsdir := Filename.concat !prefix "lib/stublibs";
  if !mandir = "" then
    mandir := Filename.concat !prefix "man";
  List.iter (fun f ->
    let opam_file = OpamParser.file f in
    List.iter (function
     | Variable (_, n, v) -> install_section n v
     | _ -> raise No_install_file
    ) opam_file.file_contents
  ) !files
;;
