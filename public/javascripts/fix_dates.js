$(function(){
  $('.fix_date').each(function(){
    if($(this).val() != ''){
      $(this).val( $(this).val().split('/').reverse().join('-') );
    }
  });
  $('.fix_datetime').each(function(){
    if($(this).val() != ''){
      d = new Date( $(this).val() );
      d = d.toLocaleDateString().split('/');
      for(var i = 0; i < d.length; i++){
        if(parseInt(d[i]) < 9){
          d[i] = "0" + d[i];
        }
      }
      $(this).val(d.reverse().join('-') );
    }
  });
  $('.add_end_of_day_before_submit').each(function(){
    var e = $(this);
    $(this).parents('form').submit(function(){
      if(e.val() != ''){
        e.val(e.val() + " 23:59:59");
      }
    });
  });
});
