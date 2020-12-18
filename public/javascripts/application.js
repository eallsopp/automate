$(function() {

  $("form.delete").submit(function(event) {
    event.preventDefault(); /* stops the default behavior (submitting form to post) */
    event.stopPropagation(); /* prevents outside page/browser interpretation*/

    var ok = confirm("Are you sure you want to delete?  This is irreversible!");
    if (ok) {
      this.submit();
    }
  });



});
