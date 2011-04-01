// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults
if (!window.console || !console.firebug)
{
    var names = ["log", "debug", "info", "warn", "error", "assert", "dir", "dirxml",
    "group", "groupEnd", "time", "timeEnd", "count", "trace", "profile", "profileEnd"];

    window.console = {};
    for (var i = 0; i < names.length; ++i)
        window.console[names[i]] = function() {}
}
$(function(){ 
  SimplyButtons.init(); 
  $(".reset").click(function() {
    $("input[type='text']").val('');
    $("select").val('');
  });
  $("p.notification").fadeOut().fadeIn().delay(2000).fadeOut(1000);

});
function remove_fields(link) {
  $(link).prev("input[type=hidden]").val("1");
  $(link).closest(".fields").hide();
}

function add_fields(link, association, content) {
  var new_id = new Date().getTime();
  var regexp = new RegExp("new_" + association, "g")
  $(link).parent().before(content.replace(regexp, new_id));
}

/* Plugins Menu Callback */
$(function() {
    initMoreToggle("#plugins_button","#plugins_menu", "plugins_menu");
});
/* More toggle button implementation */
function initMoreToggle(clickElement, toogleElement, cookieName) {
  //console.log("initial: "+ $.cookie(cookieName));
  $(clickElement).attr('href', 'javascript:void(null);'); 
  if ($.cookie(cookieName) != "show")
    $(toogleElement).hide();
  else
    $(toogleElement).show();
  $(clickElement).click(function(){
    $(toogleElement).toggle();
    //console.log("before: "+ $.cookie(cookieName));
    if ($(toogleElement).css('display') == "none") {
      //console.log("try to hide");
      $.cookie(cookieName, "hide");
    }
    else {
      //console.log("try to show");
      $.cookie(cookieName, "show");
    }
    //console.log("after: "+ $.cookie(cookieName));
  })
}

