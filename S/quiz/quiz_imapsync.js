
// Taken from https://code-boxx.com/simple-javascript-quiz

var quiz = {
  // (A) PROPERTIES
  // (A1) QUESTIONS & ANSWERS
  // Q = QUESTION, O = OPTIONS, A = CORRECT ANSWER

  data: [
  {
    a : 1,
    o : [
      "Facebook",
      "POP, IMAP, HTTP",
      "SMTP, ICQ",
      "Twitter",
      "FTP, GOPHER",
      "Instagram"
    ],
    q : "What are the main protocols usually used to access a mailbox?"
  },
  {
    a : 2,
    o : [
      "I'M A Passager",
      "Instant Mailbox Access Possibility",
      "Internet Message Access Protocol",
      "In My Ambiguous Posture",
      "In My Ambience Place",
      "Izorc Muggle Ark Prout"
    ],
    q : "What means the acronym IMAP?"
   },
  {
    a : 2,
    o : [
      "No parameter is needed",
      "Harry Potter's magic wang",
      "1) The IMAP server name + 2) the user login + 3) the password",
      "1) the user login + 2) the password"
    ],
    q : "What are the parameters needed to access an IMAP mailbox?"
  },
  {
    a : 4,
    o : [
      "0",
      "2",
      "3",
      "4",
      "6",
      "8"
    ],
    q : "How many parameters are mandatory to synchronize two IMAP mailboxes with imapsync?"
  },
  {
    a : 0,
    o : [
      "No",
      "Yes"
    ],
    q : "Can Imapsync synchronize POP accounts?"
  },
  {
    a : 1,
    o : [
      "No",
      "Yes"
    ],
    q : "Can Imapsync synchronize Gmail accounts?"
  },
  {
    a : 1,
    o : [
      "No",
      "Yes"
    ],
    q : "Can Imapsync synchronize Office365 accounts?"
  },
  {
    a : 0,
    o : [
      "No",
      "Yes"
    ],
    q : "Can Imapsync synchronize Contacts, Calendars, Chats, or Notes?"
  },
  {
    a : 0,
    o : [
      "NO LIMIT",
      "GPL",
      "WTFPL",
      "MIT",
      "CC0",
      "Proprietary"
    ],
    q : "What is the Imapsync License name?"
  },
  {
    a : 0,
    o : [
      "No limits to do anything with this work and this license.",
      "All permissions restricted.",
      "Use it for good or evil.",
      "Too long to fit here."
    ],
    q : "What is the Imapsync License main text?"
 },
  {
    a : 0,
    o : [
      "Yes, sometimes with delay, he's a human",
      "No, never, email is dead",
      "Yes, immediately and 24h/24, he's a robot",
      "What is email?"
    ],
    q : "Does the imapsync author Gilles LAMIRAL reply to every email?"
 }
  ],
  dataDev: [
  {
    a : 1,
    o : [
      "Facebook",
      "POP, IMAP, HTTP",
      "SMTP, ICQ",
      "Twitter",
      "FTP, GOPHER",
      "Instagram"
    ],
    q : "What are the main protocols usually used to access a mailbox?"
  }
  ],

  // (B) INIT QUIZ HTML
  init: function(){
    // (B1) WRAPPER
    quiz.hWrap = null;
    quiz.hScore = null;
    quiz.hRestart = null;
    quiz.hQn = null;
    quiz.hAns = null;
    quiz.now = 0;
    quiz.score = 0;
    
    quiz.hWrap = document.getElementById("quizWrap");
    quiz.hWrap.innerHTML = "";
    
    // NUMBER SECTION
    quiz.hNumber = document.createElement("div");
    quiz.hNumber.id = "quizNumber";
    quiz.hWrap.appendChild(quiz.hNumber);

    // (B2) QUESTIONS SECTION
    quiz.hQn = document.createElement("div");
    quiz.hQn.id = "quizQn";
    quiz.hWrap.appendChild(quiz.hQn);

    // (B3) ANSWERS SECTION
    quiz.hAns = document.createElement("div");
    quiz.hAns.id = "quizAns";
    quiz.hWrap.appendChild(quiz.hAns);

    // SCORE SECTION
    quiz.hScore = document.createElement("div");
    quiz.hScore.id = "quizScore";
    quiz.hWrap.appendChild(quiz.hScore);

    // RESTART SECTION
    quiz.hRestart = document.createElement("div");
    quiz.hRestart.id = "quizRestart";
    quiz.hWrap.appendChild(quiz.hRestart);
    quiz.hRestart.innerHTML = "Restart Quiz";
    document.getElementById("quizRestart").addEventListener("click", quiz.restart);
    // (B4) GO!
    quiz.draw();
  },

  // (C) DRAW QUESTION
  draw: function(){
    // SCORE
    var QnNumber = `${quiz.now + 1}/${quiz.data.length}`;
    var ScoreNb = `${quiz.score}/${quiz.now}`;
    
    quiz.hNumber.innerHTML = `Question ${QnNumber}`;
    quiz.hScore.innerHTML  = `Score ${ScoreNb}`;

    // (C1) QUESTION
    quiz.hQn.innerHTML = quiz.data[quiz.now].q;

    // (C2) OPTIONS
    quiz.hAns.innerHTML = "";
    for (let i in quiz.data[quiz.now].o) {
      let radio = document.createElement("input");
      radio.type = "radio";
      radio.name = "quiz";
      radio.id = "quizo" + i;
      quiz.hAns.appendChild(radio);
      let label = document.createElement("label");
      label.innerHTML = quiz.data[quiz.now].o[i];
      label.setAttribute("for", "quizo" + i);
      label.dataset.idx = i;
      label.addEventListener("click", quiz.select);
      quiz.hAns.appendChild(label);
    }
  },

  // (D) OPTION SELECTED
  select: function(){
    // (D1) DETACH ALL ONCLICK
    let all = quiz.hAns.getElementsByTagName("label");
    for (let label of all) {
      label.removeEventListener("click", quiz.select);
    }

    // (D2) CHECK IF CORRECT
    let correct = this.dataset.idx == quiz.data[quiz.now].a;
    if (correct) {
      quiz.score++;
      this.classList.add("correct");
    } else {
      this.classList.add("wrong");
    }

    // (D3) NEXT QUESTION OR END GAME
    quiz.now++;
    setTimeout(function(){
      if (quiz.now < quiz.data.length) { quiz.draw(); }
      else {
        // quiz.hNumber.innerHTML = "";
        ScoreNb = `${quiz.score}/${quiz.now}`;
        quiz.hScore.innerHTML  = `Score ${ScoreNb}`;        
        quiz.hQn.innerHTML = "Finished!";
        quiz.hAns.innerHTML = "";
      }
    }, 800);
  },
  
  restart:function(){
     quiz.init() ;
  }
};

window.addEventListener("load", quiz.init);