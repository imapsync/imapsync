
// $Id: imapsync_form.js,v 1.3 2019/03/18 19:21:16 gilles Exp gilles $

/*jslint browser: true*/ /*global  $*/
$(document).ready(function () {
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

    function refreshLog(xhr) {
        $("#output").html(xhr.responseText);
    }

    function handleRun(xhr, timerRefreshLog) {

        $("#console").text("Status: " + xhr.status + " " + xhr.statusText + "\n" + "State: " + readyStateStr[xhr.readyState] + "\n");

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

    function imapsync() {
        var querystring = $("#form").serialize();
        $("#abort").text("\n\n"); // clean abort console
        $("#output").text("Here comes the log!\n\n");
        if ("imap.gmail.com" === $("#host1").val()) {
            querystring = querystring + "&gmail1=on";
        }
        if ("imap.gmail.com" === $("#host2").val()) {
            querystring = querystring + "&gmail2=on";
        }
        var xhr;
        xhr = new XMLHttpRequest();
        var timerRefreshLog = setInterval(function () {
            refreshLog(xhr);
        }, 5000);
        xhr.onreadystatechange = function () {
            handleRun(xhr, timerRefreshLog);
        };
        xhr.open("POST", "/cgi-bin/imapsync", true);
        xhr.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
        xhr.send(querystring);
    }


    function handleAbort(xhr) {

        $("#abort").text("Status: " + xhr.status + " " + xhr.statusText + "\n" + "State: " + readyStateStr[xhr.readyState] + "\n\n");

        if (xhr.readyState === 4) {
            $("#abort").append(xhr.responseText);
            $("#bt-sync").prop("disabled", false);
            $("#bt-abort").prop("disabled", false); // back for next abort
        }
    }

    function abort() {
        var querystring = $("#form").serialize() + "&abort=on";
        var xhr;
        xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            handleAbort(xhr);
        };
        xhr.open("POST", "/cgi-bin/imapsync", true);
        xhr.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
        xhr.send(querystring);
    }
    
    function store_form() {
        if (typeof(Storage) !== "undefined") {
        // Code for localStorage.
            localStorage.user1 = $("#user1").val();
            localStorage.password1 = $("#password1").val();
            localStorage.host1 = $("#host1").val();
            
            localStorage.user2 = $("#user2").val();
            localStorage.password2 = $("#password2").val();
            localStorage.host2 = $("#host2").val();
        } else {
        // Sorry! No Web Storage support...
        }
    }

    function retrieve_form() {
        if (typeof(Storage) !== "undefined") {
        // Code for localStorage.
            $("#user1").val(localStorage.user1);
            $("#password1").val(localStorage.password1);
            $("#host1").val(localStorage.host1);
            $("#user2").val(localStorage.user2);
            $("#password2").val(localStorage.password2);
            $("#host2").val(localStorage.host2);
        } else {
        // Sorry! No Web Storage support...
        }
    }

    function showpassword() {
    }
    
    // in case of a manual refresh, start with
    $("#bt-sync").prop("disabled", false);
    $("#bt-abort").prop("disabled", false);
    $("#link_to_bottom").hide();
    retrieve_form();
    
    // Well I should write function showpassword() body and use it
    // I'm just dumb in js and jQuery
    $("#showpassword1").click(function () {
        var x = document.getElementById("password1");
        if (x.type === "password") {
            x.type = "text";
        } else {
            x.type = "password";
        }
    });

    $("#showpassword2").click(function () {
        var x = document.getElementById("password2");
        if (x.type === "password") {
            x.type = "text";
        } else {
            x.type = "password";
        }
    });

    
    
    $("#bt-sync").click(function () {
        $("#bt-sync").prop("disabled", true);
        $("#bt-abort").prop("disabled", false);
        $("#link_to_bottom").hide();
        store_form();
        imapsync();
    });

    $("#bt-abort").click(function () {
        $("#bt-sync").prop("disabled", true);
        $("#bt-abort").prop("disabled", true);
        abort();
    });

});

