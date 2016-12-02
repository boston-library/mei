Blacklight.onLoad(function() {

    function mei_duplicate_field_click(event) {
        original_element = $(event.target).parent().parent().parent().children().children();
        original_id = original_element.attr("id");

        cloned_element = $(event.target).parent().parent().parent().clone(true, true);

        cloned_element.find("input").val("");
        cloned_element.find("textarea").val("");
        cloned_element.find("select").val("");

        $(event.target).parent().parent().parent().after(cloned_element);


        added_element = $(event.target).parent().parent().parent().next().children().children();
        added_add_button = $(event.target).parent().parent().parent().next().children().children('.mei_regular_duplicate_span').children('.mei_regular_duplicate_span');
        remove_add_button = $(event.target).parent().parent().parent().next().children().children('.mei_regular_duplicate_span').children('.mei_regular_duplicate_span');

        added_add_button.click(mei_duplicate_field_click);
        remove_add_button.click(mei_delete_field_click);
    }

    function mei_delete_field_click(event) {
        //parent().parent().children().length
        local_field_name = $(event.target).parent().prev().prev().attr('name');

        //Current hack for lookup fields... may need more when I add hidden fields...
        if(local_field_name == undefined) {
            local_field_name = $(event.target).parent().prev().prev().prev().attr('name');
        }
        if ($('input[name*="' + local_field_name + '"]').length == 1) {
            $(event.target).parent().parent().parent().find("input").val("");
        } else if($('select[name*="' + local_field_name + '"]').length == 1) {
            $(event.target).parent().parent().parent().find("select").val("");
        } else {
            $(event.target).parent().parent().parent().remove();
        }
    }

    $(".mei_regular_duplicate_field").click(mei_duplicate_field_click);

    $(".mei_regular_delete_field").click(mei_delete_field_click);

});

