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
            $.post('http://elevatorcontrol/exit', JSON.stringify({}));
            return
        }
    };
    $("#close").click(function () {
        $.post('http://elevatorcontrol/exit', JSON.stringify({}));
        return
    })
    $("#floor1").click(function () {
        $.post('http://elevatorcontrol/floor1');
        return
    })
    $("#floor2").click(function(){
        $.post('http://elevatorcontrol/floor2');
        return
    })
    $("#floor3").click(function(){
        $.post('http://elevatorcontrol/floor3');
        return
    })
    $("#floor4").click(function(){
        $.post('http://elevatorcontrol/floor4');
        return
    })
    $("#floor5").click(function(){
        $.post('http://elevatorcontrol/floor5');
        return
    })
    $("#floor6").click(function(){
        $.post('http://elevatorcontrol/floor6');
        return
    })
})