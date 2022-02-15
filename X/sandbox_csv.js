
$(document).ready(
    function ()
    {

var readyStateStr = {
	0: "Request not initialized",
	1: "Server connection established",
	2: "Response headers received",
	3: "Processing request",
	4: "Finished and response is ready"
} ;

function imapsync( cFunction ) {
	var xhr ;
	xhr = new XMLHttpRequest(  ) ;
	var timerRefreshLog = setInterval( function() { refreshLog( xhr ) }, 6000 ) ;
	xhr.onreadystatechange = function(  ) {
		cFunction( this, timerRefreshLog ) ;
	} ;

        var form_querystring = $("#form").serialize() ;

        $("#form_querystring").text( form_querystring ) ;


        xhr.open( "POST", "/cgi-bin/imapsync_csv_wrapper", true ) ;
        xhr.setRequestHeader( "Content-type",
            "application/x-www-form-urlencoded" ) ;
        xhr.send( form_querystring ) ;

        $("#output").text("Here comes the log!\n\n") ;
}

function handleRun( xhr, timerRefreshLog ) {

	$( "#console" ).text( "Status: " + xhr.status + " " + xhr.statusText + ".\n" 
	+ "State: " + readyStateStr[ xhr.readyState ] + "\n" ) ;

	if ( xhr.status == 200 && xhr.readyState == 4 ) {
	        var headers =  xhr.getAllResponseHeaders(  ) ;

		clearInterval( timerRefreshLog ) ;
		refreshLog( xhr ) ; // a last time
                $("#bt-sync").prop("disabled", false) ;
                $("#csv_data").prop('readonly', false);
	}
}

function refreshLog( xhr ) {
	$( "#output" ).text( xhr.responseText ) ;
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
        xhr.open("POST", "/cgi-bin/imapsync_csv_wrapper", true);
        xhr.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
        xhr.send(querystring);
}


function handleAbort( xhr ) {

	$( "#abort" ).text( "Status: " + xhr.status + " " + xhr.statusText + ".\n" 
	+ "State: " + readyStateStr[ xhr.readyState ] + "\n" ) ;

	if ( xhr.status == 200 && xhr.readyState == 4 ) {
	        var headers =  xhr.getAllResponseHeaders(  ) ;
		// $( "#abort" ).append( "\n" + headers + "\n" ) ;
		$( "#abort" ).append( xhr.responseText ) ;
                $("#csv_data").prop('readonly', false);
		$( "#bt-sync" ).prop("disabled", false);
                $( "#bt-abort" ).prop("disabled", false);
	}
}

        $("#bt-sync").click(
            function ()
            {
                $("#bt-sync").prop("disabled", true) ;
                $("#csv_data").prop('readonly', true);
                $("#bt-abort").prop("disabled", false) ;
                $("#abort").text("") ;
                imapsync( handleRun ) ;
            }
        );

        $("#bt-abort").click(
            function ()
            {
                $("#bt-sync").prop("disabled", true);
                $("#csv_data").prop('readonly', true);
                $("#bt-abort").prop("disabled", true);
                abort();
            }
        );

        // in case of a manual refresh, start with
        $("#csv_data").prop('readonly', false);
        $("#bt-sync").prop("disabled", false);
        $("#bt-abort").prop("disabled", false);

    }
    ) ;