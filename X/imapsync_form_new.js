
// $Id: imapsync_form_new.js,v 1.12 2019/07/29 22:42:19 gilles Exp gilles $

/*jslint browser: true*/ /*global  $*/


$(document).ready(
    function ()
    {
    "use strict";
    // Bootstrap popover and tooltip
    $("[data-toggle='tooltip']").tooltip();

    var readyStateStr = {
    "0": "Request not initialized",
    "1": "Server connection established",
    "2": "Response headers received",
    "3": "Processing request",
    "4": "Finished and response is ready"
        } ;

        var refresh_interval_ms = 5000 ;
        var refresh_interval_s = refresh_interval_ms  / 1000 ;
        var test = {
            counter_all : 0 ,
            counter_ok  : 0 ,
            counter_nok : 0 ,
            failed_tests : ""
        } ;

    var is = function is( expected, given, comment )
    {
        test.counter_all += 1 ;
        var message = test.counter_all + " - ["
            + expected
            + "] === ["
            + given
            + "] "
            + comment
            + "\n" ;
        if ( expected === given )
        {
            test.counter_ok += 1 ;
            message = "ok " +  message ;
        }
        else
        {
            test.counter_nok += 1 ;
            test.failed_tests += "nb " + message + "\n" ;
            message = "not ok "  + message ;
        }
        $("#tests").append( message ) ;
    } ;

    function last_eta( string )
    {
        // return the last occurrence of the substring "ETA: ...\n"
        // or "ETA: unknown" or ""
        var eta ;
        var last_found ;

        if ( undefined === string )
        {
            return "" ;
        }

        var eta_re = /ETA:.*\n/g ;

        eta = string.match( eta_re ) ;
        if ( eta )
        {
            last_found = eta[eta.length -1 ] ;
            return last_found ;
        }
        else
        {
            return "ETA: unknown" ;
        }
    }

    function tests_last_eta()
    {
        is( "", last_eta(  ),  "last_eta: no args => empty string" ) ;

        is(
            "ETA: unknown",
            last_eta( "" ),
            "last_eta: empty => empty string" ) ;

        is( "ETA: unknown",
            last_eta( "ETA" ),
            "last_eta: ETA => empty string" ) ;

        is( "ETA: unknown", last_eta( "ETA: but no CR" ),
            "last_eta: ETA: but no CR => empty string" ) ;

        is(
            "ETA: with CR\n",
            last_eta( "Blabla ETA: with CR\n" ),
            "last_eta: ETA: with CR => ETA: with CR"
        ) ;

        is(
            "ETA: 2 with CR\n",
            last_eta( "Blabla ETA: 1 with CR\nBlabla ETA: 2 with CR\n" ),
            "last_eta: several ETA: with CR => ETA: 2 with CR"
        ) ;
    }

    var tests_decompose_eta_line = function tests_decompose_eta_line()
    {
        var eta_obj ;
        var eta_str = "ETA: Wed Jul  3 14:55:27 2019  1234 s  123/4567 msgs left\n" ;

        eta_obj = decompose_eta_line( "" ) ;
        is(
            "",
            eta_obj.str,
            "decompose_eta_line: no match => undefined"
        ) ;


        eta_obj = decompose_eta_line( eta_str ) ;
        is(
            eta_str,
            eta_str,
            "decompose_eta_line: str is str"
        ) ;

        is(
            eta_str,
            eta_obj.str,
            "decompose_eta_line: str back"
        ) ;

        is(
            "Wed Jul  3 14:55:27 2019",
            eta_obj.date,
            "decompose_eta_line: date"
        ) ;

        is(
            "1234",
            eta_obj.seconds_left,
            "decompose_eta_line: seconds_left"
        ) ;

        is(
            "123",
            eta_obj.msgs_left,
            "decompose_eta_line: msgs_left"
        ) ;

        is(
            "4567",
            eta_obj.msgs_total,
            "decompose_eta_line: msgs_total"
        ) ;

        is(
            "4444",
            eta_obj.msgs_done(),
            "decompose_eta_line: msgs_done"
        ) ;

        is(
            "97.31",
            eta_obj.percent_done(),
            "decompose_eta_line: percent_done"
        ) ;

        is(
            "2.69",
            eta_obj.percent_left(),
            "decompose_eta_line: percent_left"
        ) ;
    } ;

    var decompose_eta_line = function decompose_eta_line( eta_str )
    {
        var eta_obj ;
        var eta_array ;

        var regex_eta = /^ETA:\s+(.*?)\s+([0-9]+)\s+s\s+([0-9]+)\/([0-9]+)\s+msgs\s+left\n?$/ ;
        eta_array = regex_eta.exec( eta_str ) ;

        if ( null !== eta_array )
        {
            eta_obj = {
                str      : eta_str,
                date     : eta_array[1],
                seconds_left : eta_array[2],
                msgs_left    : eta_array[3],
                msgs_total   : eta_array[4],
                msgs_done    : function() {
                    var diff = eta_obj.msgs_total - eta_obj.msgs_left ;
                    return( diff.toString() ) ;
                },
                percent_done    : function() {
                    var percent ;
                    if ( 0 === eta_obj.msgs_total )
                    {
                        return "0" ;
                    }
                    else
                    {
                        percent = ( eta_obj.msgs_total - eta_obj.msgs_left ) / eta_obj.msgs_total * 100 ;
                        return( percent.toFixed(2) ) ;
                    }
                },
                percent_left    : function() {
                    var percent ;
                    if ( 0 === eta_obj.msgs_total )
                    {
                        return "0" ;
                    }
                    else
                    {
                        percent = ( eta_obj.msgs_left / eta_obj.msgs_total * 100 ) ;
                        return( percent.toFixed(2) ) ;
                    }
                }
            } ;
        }
        else
        {
            eta_obj = {
                str      : "",
                date     : "?",
                seconds_left : "?",
                msgs_left    : "?",
                msgs_total   : "?",
                msgs_done    : "?",
                percent_done : function() { return "" ; },
                percent_left : function() { return "" ; }
            } ;
        }

        return eta_obj ;
    } ;

    var extract_eta = function extract_eta( xhr )
    {
        var eta_obj ;
        var slice_length ;
        var slice_log ;
        var eta_str ;

        if ( xhr.readyState === 4 )
        {
            slice_length = -24000 ;
        }
        else
        {
            slice_length = -240 ;
        }
        slice_log = xhr.responseText.slice( slice_length ) ;
        eta_str   = last_eta( slice_log ) ;
        // $("#tests").append( "extract_eta eta_str: " + eta_str + "\n" ) ;
        eta_obj   = decompose_eta_line( eta_str ) ;
        return eta_obj ;
    } ;

    var progress_bar_update = function progress_bar_update( eta_obj )
    {
        if ( eta_obj.str.length )
        {
            $("#progress-bar-done").css( "width", eta_obj.percent_done() + "%" ).attr( "aria-valuenow", eta_obj.percent_done() ) ;
            $("#progress-bar-left").css( "width", eta_obj.percent_left() + "%" ).attr( "aria-valuenow", eta_obj.percent_left() ) ;
            $("#progress-bar-done").text( eta_obj.percent_done() + "% " + "done" ) ;
            $("#progress-bar-left").text( eta_obj.percent_left() + "% " + "left" ) ;
        }
        else
        {
            $("#progress-bar-done").text( "unknown % " + "done" ) ;
            $("#progress-bar-left").text( "unknown % " + "left" ) ;
        }
        return ;
    } ;

    function refreshLog( xhr )
    {
        var eta_obj ;
        var eta_str ;

        eta_obj = extract_eta( xhr ) ;

        progress_bar_update( eta_obj ) ;

        if ( xhr.readyState === 4 )
        {
            // end of sync
            $("#progress-txt").text(
                "Ended. It remains "
                + eta_obj.msgs_left + " messages to be synced" ) ;
        }
        else
        {
            eta_str = eta_obj.str + " (refresh every " + refresh_interval_s + " s)" ;
            eta_str = eta_str.replace(/(\r\n|\n|\r)/gm, "") ; // trim newline
            //$("#tests").append( "refreshLog  eta_str: " + eta_str + "\n" ) ;
            $("#progress-txt").text( eta_str ) ;

        }

        $( "#output" ).text( xhr.responseText ) ;
    }



    function handleRun(xhr, timerRefreshLog)
    {

        $("#console").text(
            "Status: " + xhr.status + " " + xhr.statusText + "\n"
            + "State: " + readyStateStr[xhr.readyState] + "\n" ) ;

        if ( xhr.readyState === 4 ) {
        // var headers = xhr.getAllResponseHeaders();
        // $("#console").append(headers);
        // $("#console").append("See the completed log\n");
        $("#link_to_bottom").show() ;
        clearInterval( timerRefreshLog ) ;
        refreshLog( xhr ) ; // a last time
        // back to enable state for next run
        $("#bt-sync").prop("disabled", false) ;
        }
    }

    function imapsync()
    {
        var querystring = $("#form").serialize() ;
        $("#abort").text("\n\n") ; // clean abort console
        $("#output").text("Here comes the log!\n\n") ;

        if ( "imap.gmail.com" === $("#host1").val() )
        {
            querystring = querystring + "&gmail1=on" ;
        }
        if ( "imap.gmail.com" === $("#host2").val() )
        {
            querystring = querystring + "&gmail2=on" ;
        }

        // Same for "outlook.office365.com"
        if ( "outlook.office365.com" === $("#host1").val() )
        {
            querystring = querystring + "&office1=on" ;
        }
        if ( "outlook.office365.com" === $("#host2").val() )
        {
            querystring = querystring + "&office2=on" ;
        }


        var xhr ;
        xhr = new XMLHttpRequest() ;
        var timerRefreshLog = setInterval(
            function ()
            {
                refreshLog( xhr ) ;
            }, refresh_interval_ms ) ;

        xhr.onreadystatechange = function ()
        {
            handleRun( xhr, timerRefreshLog ) ;
        } ;

        xhr.open( "POST", "/cgi-bin/imapsync", true ) ;
        xhr.setRequestHeader( "Content-type",
            "application/x-www-form-urlencoded" ) ;
        xhr.send( querystring ) ;
    }


    function handleAbort( xhr )
    {

        $( "#abort" ).text(
            "Status: " + xhr.status + " " + xhr.statusText + "\n"
            + "State: " + readyStateStr[xhr.readyState] + "\n\n" ) ;

        if ( xhr.readyState === 4 )
        {
            $("#abort").append(xhr.responseText);
            $("#bt-sync").prop("disabled", false);
            $("#bt-abort").prop("disabled", false); // back for next abort
        }
    }

    function abort()
    {
        var querystring = $("#form").serialize() + "&abort=on";
        var xhr;
        xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function ()
        {
            handleAbort(xhr);
        };
        xhr.open("POST", "/cgi-bin/imapsync", true);
        xhr.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
        xhr.send(querystring);
    }

    function store( id )
    {
        var stored ;
        //$( "#tests" ).append( "Eco: " + id + " type is " + $( id ).attr( "type" ) + "\n" ) ;
        if ( "text" === $( id ).attr( "type" ) || "password" === $( id ).attr( "type" ) )
        {
            localStorage.setItem( id, $(id).val() ) ;
            stored = $( id ).val() ;
        }
        else if ( "checkbox" === $( id ).attr( "type" ) )
        {
            //$( "#tests" ).append( "Eco: " + id + " checked is " + $( id )[0].checked + "\n" ) ;
            localStorage.setItem( id, $( id )[0].checked ) ;
            stored = $( id )[0].checked ;
        }
        return stored ;
    }

    function retrieve( id )
    {
        var retrieved ;
        //$( "#tests" ).append( "Eco: " + id + " type is " + $( id ).attr( "type" ) + " length is " + $( id ).length + "\n" ) ;
        if ( "text" === $( id ).attr( "type" ) || "password" === $( id ).attr( "type" ) )
        {
            $( id ).val( localStorage.getItem( id ) ) ;
            retrieved = $( id ).val() ;
        }
        else if ( "checkbox" === $( id ).attr( "type" ) )
        {
            //$( "#tests" ).append( "Eco: " + id + " getItem is " + localStorage.getItem( id ) + "\n" ) ;
            $( id )[0].checked = JSON.parse( localStorage.getItem( id ) ) ;
            retrieved = $( id )[0].checked ;
        }
        return retrieved ;
    }

    function tests_store_retrieve()
    {
        if ( $("#tests").length !== 0 )
        {
            is( 1, 1, "one equals one" ) ;
            // isnot( 0, 1, "zero differs one" ) ;

            // no exist
            is( undefined, store( "#test_noexists" ),
                "store: #test_noexists" ) ;
            is( undefined, retrieve( "#test_noexists" ),
                "retrieve: #test_noexists" ) ;
            is( undefined, retrieve( "#test_noexists2" ),
                "retrieve: #test_noexists2" ) ;

            // input text
            $("#test_text" ).val( "foo" ) ;
            is( "foo", $("#test_text" ).val(  ), "#test_text val = foo" ) ;
            is( "foo", store( "#test_text" ),    "store: #test_text" ) ;
            $("#test_text" ).val( "bar" ) ;
            is( "bar", $("#test_text" ).val(  ), "#test_text val = bar" ) ;
            is( "foo", retrieve( "#test_text" ), "retrieve: #test_text = foo" ) ;
            is( "foo", $("#test_text" ).val(  ), "#test_text val = foo" ) ;


            // input check button
            $( "#test_checkbox" ).prop( "checked", true );
            is( true, store( "#test_checkbox" ),    "store: #test_checkbox checked" ) ;

            $( "#test_checkbox" ).prop( "checked", false );
            is( true, retrieve( "#test_checkbox" ), "retrieve: #test_checkbox = true" ) ;

            $( "#test_checkbox" ).prop( "checked", false );
            is( false, store( "#test_checkbox" ),    "store: #test_checkbox not checked" ) ;
            $( "#test_checkbox" ).prop( "checked", true );
            is( false, retrieve( "#test_checkbox" ), "retrieve: #test_checkbox = false" ) ;

        }
    }


    function store_form()
    {
        if ( Storage !== "undefined")
        {
        // Code for localStorage.
            store("#user1") ;
            store("#password1") ;
            store("#host1") ;
            store("#subfolder1") ;
            store("#showpassword1") ;

            store("#user2") ;
            store("#password2") ;
            store("#host2") ;
            store("#subfolder2") ;
            store("#showpassword2") ;

            store("#dry") ;
            store("#justlogin") ;
            store("#justfolders") ;
            store("#justfoldersizes") ;

            localStorage.account1_background_color = $("#account1").css("background-color") ;
            localStorage.account2_background_color = $("#account2").css("background-color") ;
        }
    }

    function show_extra_if_needed()
    {
        if ( $("#subfolder1").length && $("#subfolder1").val().length > 0 )
        {
            $(".extra_param").show() ;
        }
        if ( $("#subfolder2").length && $("#subfolder2").val().length > 0 )
        {
            $(".extra_param").show() ;
        }
    }

    function retrieve_form()
    {
        if ( Storage !== "undefined" )
        {
        // Code for localStorage.
            retrieve( "#user1" ) ;
            retrieve( "#password1" ) ;
            // retrieve("#showpassword1") ;
            retrieve( "#host1" ) ;
            retrieve( "#subfolder1" ) ;

            retrieve( "#user2" ) ;
            retrieve( "#password2" ) ;
            // retrieve("#showpassword2") ;
            retrieve( "#host2" ) ;
            retrieve( "#subfolder2" ) ;

            retrieve( "#dry" ) ;
            retrieve( "#justlogin" ) ;
            retrieve( "#justfolders" ) ;
            retrieve( "#justfoldersizes" ) ;

            // In case, how to restore the original color from css file.
            // localStorage.removeItem( "account1_background_color" ) ;
            // localStorage.removeItem( "account2_background_color" ) ;

            if ( localStorage.account1_background_color )
            {
                $("#account1").css("background-color",
                    localStorage.account1_background_color ) ;
            }
            if ( localStorage.account2_background_color )
            {
                $("#account2").css("background-color",
                    localStorage.account2_background_color ) ;
            }

            // Show the extra parameters if they are not empty because it would be dangerous
            // to retrieve them without knowing
            show_extra_if_needed() ;
        }
    }


    function showpassword( id, button )
    {
        var x = document.getElementById( id );
        if ( button.checked )
        {
            x.type = "text";
        } else {
            x.type = "password";
        }
    }

    function init()
    {
    // in case of a manual refresh, start with
        $("#bt-sync").prop("disabled", false);
        $("#bt-abort").prop("disabled", false);
        $("#link_to_bottom").hide();
        $("#progress-bar-left").css( "width", 100 + "%" ).attr( "aria-valuenow", 100 ) ;

        retrieve_form();

        $("#showpassword1").click(
            function ( event )
            {
                var button = event.target ;
                showpassword( "password1", button ) ;
            }
        );


        $("#showpassword2").click(
            function ( event )
            {
                //$("#tests").append( "\nthat1=" + JSON.stringify( event.target, undefined, 4 ) ) ;
                var button = event.target ;
                showpassword( "password2", button ) ;
            }
        );


        $("#bt-sync").click(
            function ()
            {
                $("#bt-sync").prop("disabled", true) ;
                $("#bt-abort").prop("disabled", false) ;
                $("#link_to_bottom").hide() ;
                $("#progress-txt").text( "ETA: coming soon" ) ;
                store_form() ;
                imapsync() ;
            }
        );

        $("#bt-abort").click(
            function ()
            {
                $("#bt-sync").prop("disabled", true);
                $("#bt-abort").prop("disabled", true);
                abort();
            }
        );


        var swap = function swap( p1, p2 )
        {
            var temp = $( p2 ).val(  ) ;
            $( p2 ).val( $( p1 ).val(  ) ) ;
            $( p1 ).val( temp ) ;
        } ;


        $("#swap").click(
            function()
            {
                // swaping colors can't use swap()
                var temp1 = $("#account1").css("background-color") ;
                var temp2 = $("#account2").css("background-color") ;
                $("#account1").css("background-color", temp2 );
                $("#account2").css("background-color", temp1 );

                swap( $("#user1"),      $("#user2") ) ;
                swap( $("#password1"),  $("#password2") ) ;
                swap( $("#host1"),      $("#host2") ) ;
                swap( $("#subfolder1"), $("#subfolder2") ) ;

                var temp = $("#showpassword1")[0].checked ;
                $("#showpassword1")[0].checked = $("#showpassword2")[0].checked ;
                $("#showpassword2")[0].checked = temp ;
                showpassword( "password1", $("#showpassword1")[0] ) ;
                showpassword( "password2", $("#showpassword2")[0] ) ;
            }
        ) ;
    }

        var tests_bilan = function tests_bilan()
        {
            // attended number of tests
            var nb_attended_test = 29 ;
            $("#tests").append( "1.." + test.counter_all + "\n" ) ;
            if ( test.counter_nok > 0 )
            {
                $("#tests").append(
                    "\nFAILED tests \n"
                    + test.failed_tests
                ) ;
                $("#tests").collapse("show") ;
            }
            // Summary of tests: failed 0 tests, run xx tests,
            // expected to run yy tests.
            if ( test.counter_all !== nb_attended_test )
            {
                $("#tests").append( "# Looks like you planned "
                    + nb_attended_test
                    + " tests but ran "
                    + test.counter_all + ".\n"
                ) ;
                $("#tests").collapse("show") ;
            }
        } ;

        function tests()
        {
            if ( $("#tests").length !== 0 )
            {
                tests_store_retrieve(  ) ;
                tests_last_eta(  ) ;
                tests_decompose_eta_line(  ) ;
                //is( 0, 1, "this test always fails" ) ;
                tests_bilan(  ) ;
                //$("#tests").collapse("show") ;

            }
        }

        init(  ) ;
        tests(  ) ;

    }

);

