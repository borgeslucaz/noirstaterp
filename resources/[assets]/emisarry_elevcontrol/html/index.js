$(function () {
    function display(bool) {
        if (bool) {
            $("#container").show();
        } else {
            $("#container").hide();
        }
    }

    display(false)

    window.addEventListener('message', function(event) {
        var item = event.data;
        if (item.type === "ui") {
            if (item.status == true) {
                display(true)
            } else {
                display(false)
            }
        }
    })
    // if the person uses the escape key, it will exit the resource
    document.onkeyup = function (data) {
        if (data.which == 27) {
            $.post(`https://${GetParentResourceName()}/exit`, JSON.stringify({}));
            return
        }
    };
    $("#close").click(function () {
        $.post(`https://${GetParentResourceName()}/exit`, JSON.stringify({}));
        return
    })
    $("#floor1").click(function () {
        $.post(`https://${GetParentResourceName()}/floor1`);
        return
    })
    $("#floor2").click(function(){
        $.post(`https://${GetParentResourceName()}/floor2`);
        return
    })
    $("#floor3").click(function(){
        $.post(`https://${GetParentResourceName()}/floor3`);
        return
    })
    $("#floor4").click(function(){
        $.post(`https://${GetParentResourceName()}/floor4`);
        return
    })
    $("#floor5").click(function(){
        $.post(`https://${GetParentResourceName()}/floor5`);
        return
    })
    $("#floor6").click(function(){
        $.post(`https://${GetParentResourceName()}/floor6`);
        return
    })
})