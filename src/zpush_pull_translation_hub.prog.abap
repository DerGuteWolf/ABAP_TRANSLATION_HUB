*&---------------------------------------------------------------------*
*& Report zpush_pull_translation_hub
*&---------------------------------------------------------------------*
*& Push Object List to Translation Hub and Pull Translations
*&---------------------------------------------------------------------*
REPORT zpush_pull_translation_hub.

  DATA p_lang TYPE lxeisolang.
  DATA target_languages TYPE lxe_tt_lxeisolang.

  PARAMETERS s_lang TYPE lxeisolang OBLIGATORY LOWER CASE.
  SELECT-OPTIONS t_langs FOR p_lang NO INTERVALS OBLIGATORY LOWER CASE.
  PARAMETERS s_liname TYPE lxestring OBLIGATORY LOWER CASE.
  PARAMETERS s_srvdir TYPE string OBLIGATORY LOWER CASE.
  PARAMETERS s_dest TYPE rfcdest OBLIGATORY MATCHCODE OBJECT wdhc_kw_http.
  PARAMETERS s_proj TYPE string OBLIGATORY LOWER CASE.

  AT SELECTION-SCREEN ON VALUE-REQUEST FOR s_lang.
    CALL FUNCTION 'LXE_T002_SELECT_LANGUAGE_F4'
      EXPORTING
        active_only = abap_true
        dynpfield   = 'S_LANG'
      IMPORTING
        sel_lang    = s_lang.

  AT SELECTION-SCREEN ON VALUE-REQUEST FOR t_langs-low.
    CALL FUNCTION 'LXE_T002_SELECT_LANGUAGE_F4'
      EXPORTING
        active_only = abap_true
        dynpfield   = 'T_LANGS'
      IMPORTING
        sel_lang    = t_langs-low.

  FORM output USING text TYPE string.
    WRITE / text.
    CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR' EXPORTING text = text.
  ENDFORM.

START-OF-SELECTION.
  DATA output_text TYPE string.

  LOOP AT t_langs ASSIGNING FIELD-SYMBOL(<language_range>).
    APPEND <language_range>-low TO target_languages.
  ENDLOOP.
  DATA(source_language) = s_lang.
  DATA(object_list_name) = s_liname.
  DATA(server_directory) = s_srvdir.
  DATA(destination) = s_dest.
  DATA(projectID) = s_proj.

* Step 0: Prechecks

  LOOP AT VALUE #( BASE target_languages ( source_language ) ) ASSIGNING FIELD-SYMBOL(<lang_to_check>).
    CALL FUNCTION 'LXE_T002_CHECK_LANGUAGE'
      EXPORTING
        language           = <lang_to_check>
      EXCEPTIONS
        language_not_in_cp = 1
        unknown            = 2.
    IF sy-subrc <> 0.
      MESSAGE 'Target or Source Language not in the System' TYPE 'E'.
    ENDIF.
  ENDLOOP.

  DATA(base_path) = |/translationhub/api/v2/fileProjects/{ projectID }|.
  DATA(fileNameInTransHub) = |{ source_language }_{ target_languages[ 1 ] }_S_000001-00001.xlf|.

  WRITE / |Source Language used: { source_language }|.
  WRITE / |Target Languages used: { REDUCE string( INIT langs = `` sep = `` FOR lang IN target_languages NEXT langs = |{ langs }{ sep }{ lang }| sep = `, ` ) }|.
  WRITE / |Object List Name used: { object_list_name }|.
  WRITE / |Server Directory used: { server_directory }|.
  WRITE / |RFC HTTP Destination used: { destination }|.
  WRITE / |Project ID used: { projectID }|.

* Step 1: Find last Object List Entry ( as generated per Report )

  SELECT objlist FROM lxe_objl WHERE type = 'N' AND text = @object_list_name AND stat = 'X' ORDER BY objlist DESCENDING INTO TABLE @DATA(object_list) UP TO 1 ROWS.

  IF sy-subrc <> 0.
    MESSAGE 'Could Not Find Object List' TYPE 'E'.
  ENDIF.

  output_text = |Using Object List Number: { object_list[ 1 ]-objlist }|. PERFORM output USING output_text.

* Step 2: Get new Text Externalization ID

  cl_lxe_textext_log=>get_new_id(
    EXPORTING
      i_xlf_short         = abap_true
      i_xlf_pdf           = abap_false
      i_excel             = abap_false
      i_description       = object_list_name
      i_exp_skip_trl_obj  = abap_false
      i_exp_skip_mod_obj  = abap_false
      i_exp_skip_trl_lin  = abap_false
      i_exp_skip_mod_lin  = abap_false
    IMPORTING
      e_id    = DATA(export_id)
    EXCEPTIONS
      error = 1
  ).
  IF sy-subrc <> 0 OR export_id IS INITIAL.
    MESSAGE 'Error getting new export ID' TYPE 'E'.
  ENDIF.

  output_text = |Using Externalization Number: { export_id }|. PERFORM output USING output_text.
* Step 3: Export to server file

  TRY.
      NEW cl_lxe_textext_export(
              i_expid            = export_id
              i_xlf_short        = abap_true
              i_xlf_pdf          = abap_false
              i_excel            = abap_false
              i_skip_trl_objects = abap_false
              i_skip_mod_objects = abap_false
              i_skip_trl_lines   = abap_false
              i_skip_mod_lines   = abap_false
              i_slang            = source_language
              i_tlangs           = target_languages
              i_objlist          = object_list[ 1 ]-objlist
              i_dir_backend      = abap_true
              i_directory        = server_directory
              i_exp_pp           = abap_false
              i_lines_per_file   = 0
              i_exp_ref_lang     = abap_false
              i_rlang            = ''
      )->export( ).
    CATCH cx_lxe_textext INTO DATA(textext_export_exception).
      MESSAGE 'Export Failure' TYPE 'E'.
  ENDTRY.

   cl_lxe_textext_log=>update_id_header_export( export_id ).

  DATA(file_name) = |{ server_directory }/{ source_language }_{ target_languages[ 1 ] }_S_{ export_id }-00001.xlf|.

  output_text = |Export Succesful|. PERFORM output USING output_text.
* Step 4: Read File to memory

  DATA mess TYPE string.

  OPEN DATASET file_name FOR INPUT IN BINARY MODE MESSAGE mess.
  IF sy-subrc = 8.
    MESSAGE mess TYPE 'E'.
  ENDIF.

  DATA content TYPE xstring.

  READ DATASET file_name INTO content.
  if sy-subrc <> 0.
     MESSAGE 'File too Big' TYPE 'E'.
  endif.

  CLOSE DATASET file_name.

  output_text = |Read File Succesful|. PERFORM output USING output_text.
* Step 5: Delete File

  DELETE DATASET file_name.
  if sy-subrc <> 0.
     MESSAGE 'Delete File Failed' TYPE 'E'.
  endif.

  output_text = |Delete File Succesful|. PERFORM output USING output_text.
* Step 6: Establish Communication with Translation Hub

  cl_http_client=>create_by_destination(
    EXPORTING
      destination = destination
    IMPORTING
      client             = DATA(http_client)
    EXCEPTIONS
      argument_not_found = 1 "#EC NUMBER_OK
      plugin_not_active  = 2 "#EC NUMBER_OK
      internal_error     = 3 "#EC NUMBER_OK
      destination_not_found = 10 "#EC NUMBER_OK
      destination_no_authority = 11 "#EC NUMBER_OK
      OTHERS             = 4 "#EC NUMBER_OK
  ).
  IF sy-subrc <> 0.
    MESSAGE 'Destination Error' TYPE 'E'.
  ENDIF.

  http_client->propertytype_logon_popup = 0.

  DATA(rest_client) = NEW cl_rest_http_client( http_client ).

  cl_http_utility=>set_request_uri( request = http_client->request uri = base_path ).

  rest_client->if_rest_client~set_request_header( iv_name = 'X-CSRF-Token' iv_value = 'Fetch' ).

  rest_client->if_rest_client~get( ).

  IF ( rest_client->if_rest_client~get_status( ) <> 200 ).
    MESSAGE |Fetch CSRF Token Error: { rest_client->if_rest_client~get_status( ) }| TYPE 'E'.
  ENDIF.

  DATA(csrf_token) = rest_client->if_rest_client~get_response_header( 'x-csrf-token' ).
  rest_client->if_rest_client~set_request_header( iv_name = 'X-CSRF-Token' iv_value = csrf_token ).

  output_text = |Translation Hub Contact Succesful|. PERFORM output USING output_text.
* Step 6: Upload to Translation Hub

  cl_http_utility=>set_request_uri( request = http_client->request uri = |{ base_path }/files| ).

  DATA(upload_request) = rest_client->if_rest_client~create_request_entity( ).

  DATA(form_data) = NEW cl_rest_multipart_form_data( ).
  form_data->set_file( iv_name = 'file' iv_filename = fileNameInTransHub iv_type = 'application/octet-stream' iv_data = content ).
  form_data->write_to( upload_request ).

  rest_client->if_rest_client~post( upload_request ).

  IF ( rest_client->if_rest_client~get_status( ) <> 201 ).
    MESSAGE |Upload Error: { rest_client->if_rest_client~get_status( ) }| TYPE 'E'.
  ENDIF.
  DATA(response_upload) = /ui2/cl_json=>generate( json = rest_client->if_rest_client~get_response_entity( )->get_string_data( ) ).
  " {"id":"su7bDJlESlFUa8sqjTEq8UFP0NLJsijfR54gcuTozJo","pathToFile":"enUS_frFR_S_000001-00001.xlf","uploadedAt":"2021-01-31T15:02:52.537Z","uploadedByUserId":"Wolfgang Röckelein"}
  DATA file_id TYPE string.
  /ui2/cl_data_access=>create( ir_data = response_upload iv_component = `id`)->value( IMPORTING ev_data = file_id ).

  output_text = |Translation Hub Upload Succesful|. PERFORM output USING output_text.
* Step 7: Start Translation and wait for finish

  " Clear data from previous request, otherwise the following request will always fail
  http_client->refresh_request( ).
  rest_client->if_rest_client~set_request_header( iv_name = 'X-CSRF-Token' iv_value = csrf_token ).

  cl_http_utility=>set_request_uri( request = http_client->request uri = |{ base_path }/files/{ file_id }/executions| ).
  DATA(start_request) = rest_client->if_rest_client~create_request_entity( ).
  start_request->set_content_type( 'application/json; charset=utf-8' ).
  start_request->set_string_data( '{"operation":"PULL_TRANSLATE"}' ).
  rest_client->if_rest_client~post( start_request ).
  IF ( rest_client->if_rest_client~get_status( ) <> 200 ).
    "DATA(error) = rest_client->if_rest_client~get_response_entity( )->get_string_data( ).
    MESSAGE |Start Execution Error: { rest_client->if_rest_client~get_status( ) }| TYPE 'E'.
  ENDIF.
  DATA(response_start) = /ui2/cl_json=>generate( json = rest_client->if_rest_client~get_response_entity( )->get_string_data( ) ).
  " {"id":"b58f5de0-b04e-46e7-abb6-d84c0308f282","projectId":7612,"operation":null,"status":"CREATED","percentDone":0,"createdBy":"Wolfgang Röckelein",
  "   "fileId":"EWi53QjOsvLTG8hUeI_ZKoQVJskGs3xi_9tFf8G9bbs","createdAt":"2021-01-31T16:20:15.788Z","finishedAt":null,"cancelled":false,"errors":false,"warnings":null,
  "   "log":[{"type":"INFO","createdAt":"2021-01-31T16:20:15.000Z","code":"execution-queued","message":"Execution queued"}],"childExecutions":null,"credentials":null}
  DATA execution_id TYPE string.
  /ui2/cl_data_access=>create( ir_data = response_start iv_component = `id`)->value( IMPORTING ev_data = execution_id ).

  output_text = |Translation Hub Execution Start Succesful|. PERFORM output USING output_text.
  cl_http_utility=>set_request_uri( request = http_client->request uri = |{ base_path }/executions/{ execution_id }| ).
  DATA execution_status TYPE string.
  DO.
    WAIT UP TO 1 SECONDS.
    rest_client->if_rest_client~get( ).
    IF ( rest_client->if_rest_client~get_status( ) <> 200 ).
      MESSAGE |Check Execution Error: { rest_client->if_rest_client~get_status( ) }| TYPE 'E'.
    ENDIF.
    DATA(response_check) = /ui2/cl_json=>generate( json = rest_client->if_rest_client~get_response_entity( )->get_string_data( ) ).
    /ui2/cl_data_access=>create( ir_data = response_check iv_component = `status`)->value( IMPORTING ev_data = execution_status ).
    IF execution_status = 'COMPLETED'.
      EXIT.
    ENDIF.
  ENDDO.

  output_text = |Translation Hub Execution Finish Succesful|. PERFORM output USING output_text.
* Step 8: Download zip from Translation Hub

  cl_http_utility=>set_request_uri( request = http_client->request uri = |{ base_path }/files/{ file_id }/content| ).
  rest_client->if_rest_client~get( ).
  IF ( rest_client->if_rest_client~get_status( ) <> 200 ).
    DATA(error) = rest_client->if_rest_client~get_response_entity( )->get_string_data( ).
    MESSAGE |Start Execution Error: { rest_client->if_rest_client~get_status( ) }| TYPE 'E'.
  ENDIF.
  DATA(zip_content) = rest_client->if_rest_client~get_response_entity( )->get_binary_data( ).

  rest_client->if_rest_client~close( ).

  output_text = |Translation Hub Download Succesful|. PERFORM output USING output_text.
* Step 9: Unzip

  DATA zip_file_names TYPE string_table.
  DATA zip_languages TYPE lxe_tt_lxeisolang.

  DATA(zip) = NEW cl_abap_zip( ).
  zip->load( zip_content ).
  LOOP AT zip->files ASSIGNING FIELD-SYMBOL(<file_entry>).
    zip->get( EXPORTING name = <file_entry>-name IMPORTING content = DATA(file_entry_content) ).
    DATA(language) = CONV lxeisolang( replace( val = replace( val = <file_entry>-name sub = |sth/{ source_language }_| with = '' ) sub = '_S_000001-00001.xlf' with = '' ) ).
    IF line_exists( target_languages[ table_line = language ] ).
      file_name = replace( val = replace( val = <file_entry>-name sub = 'sth' with = server_directory ) sub = '000001' with = |{ export_id }| ). " sth/enUS_deDE_S_000001-00001.xlf
      OPEN DATASET file_name FOR OUTPUT IN BINARY MODE MESSAGE mess.
      IF sy-subrc = 8.
        MESSAGE mess TYPE 'E'.
      ENDIF.
      TRANSFER file_entry_content TO file_name.
      CLOSE DATASET file_name.
      APPEND file_name TO zip_file_names.
      APPEND language TO zip_languages.
    ELSE.
      MESSAGE 'Language from Hub not in the Target Languages' TYPE 'W'.
    ENDIF.
  ENDLOOP.

  FREE zip.

  output_text = |Creating { LINES( zip_file_names ) } Translation Files Succesful|. PERFORM output USING output_text.
* Step 10: Import Files

  cl_lxe_textext_log=>update_id_header_import_param(
    i_id              = export_id
    i_imp_obj_new     = abap_true
    i_imp_obj_mod     = abap_true
    i_imp_obj_trl     = abap_true
    i_imp_lin_new     = abap_true
    i_imp_lin_mod     = abap_true
    i_imp_lin_trl     = abap_true
    i_imp_create_pp   = abap_false
    i_imp_create_fipr = abap_false
  ).

  TRY.
      NEW cl_lxe_textext_import(
        i_tgt_langs           = zip_languages
        i_expid               = export_id
        i_dir_backend         = abap_true
        i_directory           = server_directory
        i_mode_new            = abap_true
        i_mode_modified       = abap_true
        i_mode_translated     = abap_true
        i_obj_mode_new        = abap_false
        i_obj_mode_modified   = abap_false
        i_obj_mode_translated = abap_false
        i_create_pp           = abap_false
        i_pp_status           = 0
        i_create_fipr         = abap_false
        i_allow_partial       = abap_true
      )->import( ).
    CATCH cx_lxe_textext cx_root INTO DATA(textext_import_exception).
      LOOP AT zip_file_names INTO file_name.
        DELETE DATASET file_name.
        IF sy-subrc <> 0.
           " Nothing can be done here...
        ENDIF.
      ENDLOOP.
      MESSAGE 'Import Failure' TYPE 'E'.
  ENDTRY.

  output_text = |Import Succesful|. PERFORM output USING output_text.
* Step 11: Delete Files

  LOOP AT zip_file_names INTO file_name.
    DELETE DATASET file_name.
    IF sy-subrc <> 0.
       MESSAGE 'Delete File Failed' TYPE 'E'.
    ENDIF.
  ENDLOOP.

  output_text = |Delete Files Succesful|. PERFORM output USING output_text.

  WRITE / |Finished|.
