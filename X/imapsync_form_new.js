
// $Id: imapsync_form_new.js,v 1.4 2019/06/25 16:34:19 gilles Exp gilles $

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
                };

        function is( expected, given, comment )
        {
                var message = ": ["
                        + expected
                        + "] === ["
                        + given
                        + "] "
                        + comment
                        + "\n" ;
                if ( expected === given )
                {
                        message = "ok " +  message ;
                }
                else
                {
                        message = "Nok"  + message ;
                }
                $("#tests").append( message ) ;
        }

        function last_eta( string )
        {
                // return the last occurrence of the substring "ETA: ...\n"
                // or ""
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
                        return "" ;
                }
        }

        function tests_last_eta()
        {
                is( "", last_eta(  ),  "last_eta: no args => empty string" ) ;
                is( "", last_eta( "" ),  "last_eta: empty => empty string" ) ;
                is( "", last_eta( "ETA" ), "last_eta: ETA => empty string" ) ;
                is( "", last_eta( "ETA: but no CR" ),
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

        function refreshLog(xhr)
        {
                var slice_length ;
                $("#output").text(xhr.responseText) ;
                if (xhr.readyState === 4) {
                        slice_length = -2400 ;
                }
                else
                {
                        slice_length = -240 ;
                }
                $("#progress").text( last_eta( xhr.responseText.slice( slice_length ) ) ) ;
        }



        function handleRun(xhr, timerRefreshLog)
        {

                $("#console").text("Status: " + xhr.status + " " + xhr.statusText + "\n" + "State: " + readyStateStr[xhr.readyState] + "\n") ;

                if (xhr.readyState === 4) {
                // var headers = xhr.getAllResponseHeaders();
                // $("#console").append(headers);
                // $("#console").append("See the completed log\n");
                $("#link_to_bottom").show();
                clearInterval(timerRefreshLog);
                refreshLog(xhr); // a last time
                $("#bt-sync").prop("disabled", false); // back to enable state for next run
                }
        }

        function imapsync()
        {
                var querystring = $("#form").serialize();
                $("#abort").text("\n\n"); // clean abort console
                $("#output").text("Here comes the log!\n\n");

                if ( "imap.gmail.com" === $("#host1").val() )
                {
                        querystring = querystring + "&gmail1=on";
                }
                if ( "imap.gmail.com" === $("#host2").val() )
                {
                        querystring = querystring + "&gmail2=on";
                }

                var xhr;
                xhr = new XMLHttpRequest();
                var timerRefreshLog = setInterval(
                        function ()
                        {
                                refreshLog(xhr);
                        }, 5000 ) ;
                xhr.onreadystatechange = function ()
                {
                        handleRun(xhr, timerRefreshLog);
                };
                xhr.open("POST", "/cgi-bin/imapsync", true);
                xhr.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
                xhr.send(querystring);
        }


        function handleAbort(xhr)
        {

                $("#abort").text("Status: " + xhr.status + " " + xhr.statusText + "\n" + "State: " + readyStateStr[xhr.readyState] + "\n\n");

                if (xhr.readyState === 4)
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
                $( "#tests" ).append( "Eco: " + id + " type is " + $( id ).attr( "type" ) + "\n" ) ;
                if ( "text" === $( id ).attr( "type" ) || "password" === $( id ).attr( "type" ) )
                {
                        localStorage.setItem( id, $(id).val() ) ;
                        stored = $(id).val() ;
                }
                else if ( "checkbox" === $( id ).attr( "type" ) )
                {
                        $( "#tests" ).append( "Eco: " + id + " checked is " + $( id )[0].checked + "\n" ) ;
                        localStorage.setItem( id, $( id )[0].checked ) ;
                        stored = $( id )[0].checked ;
                }
                return stored ;
        }

        function retrieve( id )
        {
                var retrieved ;
                $( "#tests" ).append( "Eco: " + id + " type is " + $( id ).attr( "type" ) + " length is " + $( id ).length + "\n" ) ;
                if ( "text" === $( id ).attr( "type" ) || "password" === $( id ).attr( "type" ) )
                {
                        $( id ).val( localStorage.getItem( id ) ) ;
                        retrieved = $( id ).val() ;
                }
                else if ( "checkbox" === $( id ).attr( "type" ) )
                {
                        $( "#tests" ).append( "Eco: " + id + " getItem is " + localStorage.getItem( id ) + "\n" ) ;
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
                        is( undefined, store( "#test_noexists" ),    "store: #test_noexists" ) ;
                        is( undefined, retrieve( "#test_noexists" ),    "retrieve: #test_noexists" ) ;
                        is( undefined, retrieve( "#test_noexists2" ),    "retrieve: #test_noexists2" ) ;

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

                        // In case
                        // localStorage.removeItem( "account1_background_color" ) ;
                        // localStorage.removeItem( "account2_background_color" ) ;

                        if ( localStorage.account1_background_color )
                        {
                                $("#account1").css("background-color", localStorage.account1_background_color ) ;
                        }
                        if ( localStorage.account2_background_color )
                        {
                                $("#account2").css("background-color", localStorage.account2_background_color ) ;
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
                retrieve_form();

                $("#showpassword1").click(
                        function ()
                        {
                                // does not change jslint report...
                                /*jshint validthis: true */
                                var button = this ;
                                showpassword( "password1", button ) ;
                        }
                );


                $("#showpassword2").click(
                        function ()
                        {
                                var button = this ;
                                showpassword( "password2", button ) ;
                        }
                );


                $("#bt-sync").click(
                        function ()
                        {
                                $("#bt-sync").prop("disabled", true);
                                $("#bt-abort").prop("disabled", false);
                                $("#link_to_bottom").hide();
                                store_form();
                                imapsync();
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


                $.fn.swapWith = function(to)
                {
                        var temp = $(to).val();
                        $(to).val($(this).val());
                        $(this).val(temp);
                };


                $("#swap").click(
                        function()
                        {
                        // swaping colors can't use swapWith()
                                var temp1 = $("#account1").css("background-color") ;
                                var temp2 = $("#account2").css("background-color") ;
                                $("#account1").css("background-color", temp2 );
                                $("#account2").css("background-color", temp1 );

                                $("#user1").swapWith("#user2");
                                $("#password1").swapWith("#password2");
                                $("#host1").swapWith("#host2");
                                $("#subfolder1").swapWith("#subfolder2");

                                var temp = $("#showpassword1")[0].checked ;
                                $("#showpassword1")[0].checked = $("#showpassword2")[0].checked ;
                                $("#showpassword2")[0].checked = temp ;
                                showpassword( "password1", $("#showpassword1")[0] ) ;
                                showpassword( "password2", $("#showpassword2")[0] ) ;
                        }
                );

        }




                function progress_bar_update( string )
                {
                        //
                        return ;
                }



                function tests()
                {
                        if ( $("#tests").length !== 0 )
                        {
                                tests_store_retrieve() ;
                                tests_last_eta() ;
                        }
                }

                init(  ) ;
                tests(  ) ;

        }

);

