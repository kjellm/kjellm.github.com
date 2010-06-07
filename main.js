window.onload = function() {

  /* Emulate CSS generated content h1:before and h1:after */
  h1 = document.getElementsByTagName('h1')[0];
h1.innerHTML =
      "<span style=\"font-weight: normal\">-------+=<([</span>"
    + h1.innerHTML
    + "<span style=\"font-weight: normal\">])>=+-------</span>";
};


